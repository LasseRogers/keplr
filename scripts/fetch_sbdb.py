# /// script
# requires-python = ">=3.12"
# ///
"""Download asteroid orbital elements from JPL's Small-Body Database."""

import csv
import json
import sys
import urllib.parse
import urllib.request
from pathlib import Path

API = "https://ssd-api.jpl.nasa.gov/sbdb_query.api"
# Keplerian elements at a reference epoch: everything needed to propagate an orbit.
FIELDS = ["spkid", "epoch", "e", "a", "i", "om", "w", "ma"]


def main() -> None:
    out = Path(sys.argv[1] if len(sys.argv) > 1 else "data/neo.csv")
    params = {
        "fields": ",".join(FIELDS),
        "sb-kind": "a",
        "sb-group": "neo",
        "full-prec": "true",
    }
    url = f"{API}?{urllib.parse.urlencode(params)}"
    with urllib.request.urlopen(url, timeout=120) as resp:
        body = json.load(resp)

    assert body["fields"] == FIELDS, body["fields"]
    # Rows with missing elements can't be propagated.
    rows = [r for r in body["data"] if None not in r]

    out.parent.mkdir(parents=True, exist_ok=True)
    with out.open("w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(FIELDS)
        writer.writerows(rows)
    print(f"{len(rows)} of {body['count']} asteroids -> {out}")


if __name__ == "__main__":
    main()
