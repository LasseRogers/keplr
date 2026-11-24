# /// script
# requires-python = ">=3.12"
# ///
"""Download asteroid orbital elements from JPL's Small-Body Database."""

import argparse
import csv
import json
import urllib.parse
import urllib.request
from pathlib import Path

API = "https://ssd-api.jpl.nasa.gov/sbdb_query.api"
# Keplerian elements at a reference epoch: everything needed to propagate an orbit.
FIELDS = ["spkid", "epoch", "e", "a", "i", "om", "w", "ma"]
# Paged so ~1.4M asteroids never arrive as one huge response that times out or eats memory.
PAGE = 200_000


def query(params: dict) -> dict:
    url = f"{API}?{urllib.parse.urlencode(params)}"
    with urllib.request.urlopen(url, timeout=300) as resp:
        return json.load(resp)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--all", action="store_true", help="every asteroid, not just NEOs")
    parser.add_argument("out", nargs="?", type=Path, help="default: data/neo.csv or data/all.csv")
    args = parser.parse_args()
    out = args.out or Path("data/all.csv" if args.all else "data/neo.csv")

    params = {
        "fields": ",".join(FIELDS),
        "sb-kind": "a",
        "full-prec": "true",
        # A stable order keeps pages consistent with each other.
        "sort": "spkid",
        "limit": PAGE,
    }
    if not args.all:
        params["sb-group"] = "neo"

    rows = []
    while True:
        body = query({**params, "limit-from": len(rows)})
        assert body["fields"] == FIELDS, body["fields"]
        page = body["data"]
        rows += page
        print(f"{len(rows)} rows", flush=True)
        if len(page) < PAGE:
            break

    # Rows with missing elements can't be propagated.
    complete = [r for r in rows if None not in r]

    out.parent.mkdir(parents=True, exist_ok=True)
    with out.open("w", newline="") as f:
        writer = csv.writer(f, lineterminator="\n")
        writer.writerow(FIELDS)
        writer.writerows(complete)
    print(f"{len(complete)} of {len(rows)} asteroids -> {out}")


if __name__ == "__main__":
    main()
