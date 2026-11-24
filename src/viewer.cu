/* Copyright (c) 2022, NVIDIA CORPORATION. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *  * Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 *  * Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *  * Neither the name of NVIDIA CORPORATION nor the names of its
 *    contributors may be used to endorse or promote products derived
 *    from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS ``AS IS'' AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT OWNER OR
 * CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
 * OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

// keplr viewer, derived from NVIDIA's simpleGL sample (third_party/cuda-samples): the sine-wave
// kernel is replaced by asteroid propagation and the offline regression mode is removed.
// CUDA writes positions straight into the OpenGL vertex buffer, so frames never leave the GPU.

#include <algorithm>
#include <cstdio>
#include <cstdlib>
#include <fstream>
#include <optional>
#include <stdexcept>
#include <string>
#include <vector>

#include <helper_gl.h>
#include <GL/freeglut.h>

#include <cuda_gl_interop.h>
#include <cuda_runtime.h>

#include <helper_cuda.h>
#include <helper_functions.h>

#include "date.hpp"
#include "earth.cuh"
#include "gpu.cuh"
#include "orbit.hpp"
#include "script.hpp"
#include "propagate.cuh"

namespace {

constexpr int kWindowWidth = 1024, kWindowHeight = 768;
constexpr int kRefreshMs = 10;
constexpr int kSearchDays = 3653;

GLuint vbo = 0, color_vbo = 0;
cudaGraphicsResource* vbo_resource = nullptr;

Orbit* d_orbits = nullptr;
int n_orbits = 0;
double t_jd = 0.0;
double days_per_frame = 1.0;
bool paused = false;

std::vector<Vec3> earth_orbit;
std::optional<Script> script;
long frame = 0;

struct Visible {
    Orbit orbit;
    Color color;
    double dist;
};

int mouse_old_x = 0, mouse_old_y = 0, mouse_buttons = 0;
float rotate_x = 0.0f, rotate_y = 0.0f, translate_z = -6.0f;

StopWatchInterface* timer = nullptr;
int fps_count = 0, fps_limit = 1;
float fps = 0.0f;

// Heliocentric ecliptic positions in AU. Float is plenty for pixels; the orbit math stays double.
__global__ void positions_kernel(const Orbit* orbits, float4* out, int n, double t) {
    const int k = blockIdx.x * blockDim.x + threadIdx.x;
    if (k >= n) return;
    const Vec3 p = position(orbits[k], t);
    out[k] = make_float4(float(p.x), float(p.y), float(p.z), 1.0f);
}

std::vector<Approach> search_approaches(double t0, int days) {
    const auto table = earth_table(t0, 1.0, days);
    Vec3* d_earth;
    Approach* d_out;
    checkCudaErrors(cudaMalloc(&d_earth, days * sizeof(Vec3)));
    checkCudaErrors(cudaMalloc(&d_out, n_orbits * sizeof(Approach)));
    checkCudaErrors(cudaMemcpy(d_earth, table.data(), days * sizeof(Vec3), cudaMemcpyHostToDevice));
    approach_gpu(d_orbits, d_earth, d_out, n_orbits, t0, 1.0, days);
    std::vector<Approach> out(n_orbits);
    checkCudaErrors(cudaMemcpy(out.data(), d_out, n_orbits * sizeof(Approach), cudaMemcpyDeviceToHost));
    checkCudaErrors(cudaFree(d_earth));
    checkCudaErrors(cudaFree(d_out));
    return out;
}

void run_cuda() {
    float4* dptr;
    size_t bytes;
    checkCudaErrors(cudaGraphicsMapResources(1, &vbo_resource, 0));
    checkCudaErrors(
        cudaGraphicsResourceGetMappedPointer(reinterpret_cast<void**>(&dptr), &bytes, vbo_resource));
    constexpr int block = 256;
    positions_kernel<<<(n_orbits + block - 1) / block, block>>>(d_orbits, dptr, n_orbits, t_jd);
    getLastCudaError("positions_kernel");
    checkCudaErrors(cudaGraphicsUnmapResources(1, &vbo_resource, 0));
}

void compute_fps() {
    if (++fps_count < fps_limit) return;
    fps = 1.0f / (sdkGetAverageTimerValue(&timer) / 1000.0f);
    fps_count = 0;
    fps_limit = std::max(static_cast<int>(fps), 1);
    sdkResetTimer(&timer);
}

void update_title() {
    const Date d = jd_to_date(t_jd);
    char title[160];
    std::snprintf(title, sizeof title, "keplr: %04d-%02d-%02d  %g days/frame%s  %d asteroids  %.0f fps",
                  d.year, d.month, d.day, days_per_frame, paused ? " (paused)" : "", n_orbits, fps);
    glutSetWindowTitle(title);
}

void display() {
    sdkStartTimer(&timer);
    run_cuda();

    // A scripted camera overrides the mouse, so tours and recordings are repeatable.
    if (script->has_camera()) {
        try {
            const Camera c = script->camera(frame);
            rotate_x = c.rotate_x;
            rotate_y = c.rotate_y;
            translate_z = -c.distance;
        } catch (const std::runtime_error& e) {
            std::fprintf(stderr, "%s\n", e.what());
            std::exit(EXIT_FAILURE);
        }
    }

    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    glMatrixMode(GL_MODELVIEW);
    glLoadIdentity();
    glTranslatef(0.0f, 0.0f, translate_z);
    glRotatef(rotate_x, 1.0f, 0.0f, 0.0f);
    glRotatef(rotate_y, 0.0f, 1.0f, 0.0f);

    glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glVertexPointer(4, GL_FLOAT, 0, nullptr);
    glBindBuffer(GL_ARRAY_BUFFER, color_vbo);
    glColorPointer(3, GL_FLOAT, 0, nullptr);
    glEnableClientState(GL_VERTEX_ARRAY);
    glEnableClientState(GL_COLOR_ARRAY);
    glDrawArrays(GL_POINTS, 0, n_orbits);
    glDisableClientState(GL_COLOR_ARRAY);
    glDisableClientState(GL_VERTEX_ARRAY);
    glBindBuffer(GL_ARRAY_BUFFER, 0);

    // A handful of vertices: immediate mode is simplest, only the asteroids need the VBO.
    glColor3f(0.2f, 0.3f, 0.6f);
    glBegin(GL_LINE_LOOP);
    for (const Vec3& q : earth_orbit) glVertex3d(q.x, q.y, q.z);
    glEnd();

    const Vec3 e = earth_position(t_jd);
    glPointSize(8.0f);
    glBegin(GL_POINTS);
    glColor3f(1.0f, 0.85f, 0.2f);
    glVertex3d(0.0, 0.0, 0.0);
    glColor3f(0.3f, 0.6f, 1.0f);
    glVertex3d(e.x, e.y, e.z);
    glEnd();
    glPointSize(1.0f);

    glutSwapBuffers();
    sdkStopTimer(&timer);
    compute_fps();

    if (!paused) {
        t_jd += days_per_frame;
        ++frame;
    }
    update_title();
}

void timer_event(int) {
    if (glutGetWindow()) {
        glutPostRedisplay();
        glutTimerFunc(kRefreshMs, timer_event, 0);
    }
}

// Esc quits, space pauses, +/- double or halve the speed of time.
void keyboard(unsigned char key, int, int) {
    switch (key) {
        case 27: glutDestroyWindow(glutGetWindow()); break;
        case ' ': paused = !paused; break;
        case '+':
        case '=': days_per_frame *= 2.0; break;
        case '-': days_per_frame /= 2.0; break;
    }
}

void mouse(int button, int state, int x, int y) {
    if (state == GLUT_DOWN)
        mouse_buttons |= 1 << button;
    else if (state == GLUT_UP)
        mouse_buttons = 0;
    mouse_old_x = x;
    mouse_old_y = y;
}

// Left drag rotates, right drag zooms.
void motion(int x, int y) {
    const float dx = float(x - mouse_old_x), dy = float(y - mouse_old_y);
    if (mouse_buttons & 1) {
        rotate_x += dy * 0.2f;
        rotate_y += dx * 0.2f;
    } else if (mouse_buttons & 4) {
        translate_z += dy * 0.02f;
    }
    mouse_old_x = x;
    mouse_old_y = y;
}

void cleanup() {
    sdkDeleteTimer(&timer);
    if (vbo) {
        checkCudaErrors(cudaGraphicsUnregisterResource(vbo_resource));
        glDeleteBuffers(1, &vbo);
        vbo = 0;
    }
    glDeleteBuffers(1, &color_vbo);
    checkCudaErrors(cudaFree(d_orbits));
}

bool init_gl(int* argc, char** argv) {
    glutInit(argc, argv);
    glutInitDisplayMode(GLUT_RGBA | GLUT_DOUBLE);
    glutInitWindowSize(kWindowWidth, kWindowHeight);
    glutCreateWindow("keplr");
    if (!isGLVersionSupported(2, 0)) {
        std::fprintf(stderr, "OpenGL 2.0 not supported\n");
        return false;
    }

    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glDisable(GL_DEPTH_TEST);
    glViewport(0, 0, kWindowWidth, kWindowHeight);
    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    // Far plane well past the most distant aphelia, so zooming out never clips the cloud.
    gluPerspective(60.0, double(kWindowWidth) / kWindowHeight, 0.01, 1000.0);
    SDK_CHECK_ERROR_GL();
    return true;
}

}  // namespace

// Usage: viewer [orbits.csv] [script.lua]
int main(int argc, char** argv) {
    const std::string path = argc > 1 ? argv[1] : "data/neo.csv";
    const std::string script_path = argc > 2 ? argv[2] : "lua/hazard.lua";

    // Load the script before opening a window, so a typo fails fast.
    try {
        script.emplace(Script::from_file(script_path));
    } catch (const std::runtime_error& e) {
        std::fprintf(stderr, "%s\n", e.what());
        return EXIT_FAILURE;
    }

    std::ifstream in(path);
    if (!in) {
        std::fprintf(stderr, "cannot open %s (run scripts/fetch_sbdb.py)\n", path.c_str());
        return EXIT_FAILURE;
    }
    std::vector<Orbit> orbits = load_orbits(in);
    n_orbits = static_cast<int>(orbits.size());
    // A still snapshot at the elements' epoch for now.
    t_jd = orbits.front().epoch;

    // One sidereal year from the start; the orbit barely changes over the decades shown.
    constexpr int kOrbitPoints = 365;
    for (int k = 0; k < kOrbitPoints; ++k)
        earth_orbit.push_back(earth_position(t_jd + k * 365.25636 / kOrbitPoints));

    // The GL context must exist before CUDA touches the device, so the two can share buffers.
    if (!init_gl(&argc, argv)) return EXIT_FAILURE;
    findCudaDevice(argc, const_cast<const char**>(argv));

    checkCudaErrors(cudaMalloc(&d_orbits, n_orbits * sizeof(Orbit)));
    checkCudaErrors(
        cudaMemcpy(d_orbits, orbits.data(), n_orbits * sizeof(Orbit), cudaMemcpyHostToDevice));

    // Search once at startup, then let the script colour or hide each asteroid.
    const std::vector<Approach> approaches = search_approaches(t_jd, kSearchDays);
    std::vector<Visible> visible;
    try {
        for (int k = 0; k < n_orbits; ++k)
            if (const auto c = script->color(orbits[k], approaches[k]))
                visible.push_back({orbits[k], *c, approaches[k].dist});
    } catch (const std::runtime_error& e) {
        std::fprintf(stderr, "%s\n", e.what());
        return EXIT_FAILURE;
    }
    if (visible.empty()) {
        std::fprintf(stderr, "%s hides every asteroid\n", script_path.c_str());
        return EXIT_FAILURE;
    }
    // Closest passers last, so distant points never cover them.
    std::sort(visible.begin(), visible.end(),
              [](const Visible& a, const Visible& b) { return a.dist > b.dist; });
    std::printf("%s shows %zu of %d asteroids\n", script_path.c_str(), visible.size(), n_orbits);

    // Only visible asteroids stay on the GPU, so hidden ones cost nothing per frame.
    n_orbits = static_cast<int>(visible.size());
    std::vector<Orbit> shown(n_orbits);
    std::vector<float> colors(3 * n_orbits);
    for (int i = 0; i < n_orbits; ++i) {
        shown[i] = visible[i].orbit;
        colors[3 * i + 0] = visible[i].color.r;
        colors[3 * i + 1] = visible[i].color.g;
        colors[3 * i + 2] = visible[i].color.b;
    }
    checkCudaErrors(
        cudaMemcpy(d_orbits, shown.data(), n_orbits * sizeof(Orbit), cudaMemcpyHostToDevice));

    glGenBuffers(1, &vbo);
    glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glBufferData(GL_ARRAY_BUFFER, n_orbits * sizeof(float4), nullptr, GL_DYNAMIC_DRAW);
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    // WriteDiscard: CUDA rewrites the whole buffer each frame, so GL never preserves old contents.
    checkCudaErrors(
        cudaGraphicsGLRegisterBuffer(&vbo_resource, vbo, cudaGraphicsMapFlagsWriteDiscard));

    // Colours never change, so they live in a static buffer uploaded once.
    glGenBuffers(1, &color_vbo);
    glBindBuffer(GL_ARRAY_BUFFER, color_vbo);
    glBufferData(GL_ARRAY_BUFFER, colors.size() * sizeof(float), colors.data(), GL_STATIC_DRAW);
    glBindBuffer(GL_ARRAY_BUFFER, 0);

    sdkCreateTimer(&timer);
    glutDisplayFunc(display);
    glutKeyboardFunc(keyboard);
    glutMouseFunc(mouse);
    glutMotionFunc(motion);
    glutTimerFunc(kRefreshMs, timer_event, 0);
    glutCloseFunc(cleanup);
    glutMainLoop();
}
