#!/usr/bin/env python3
"""Compare Reference/cdc2000/statage.csv against the official file downloaded from cdc.gov.

Usage: python3 scripts/verify_cdc_reference.py
Exits non-zero if any value differs by more than 1e-9.
"""
import csv
import io
import pathlib
import sys
import urllib.request

URL = "https://www.cdc.gov/growthcharts/data/zscore/statage.csv"
LOCAL = pathlib.Path(__file__).resolve().parent.parent / "Reference" / "cdc2000" / "statage.csv"
COLUMNS = ["Agemos", "L", "M", "S", "P3", "P5", "P10", "P25", "P50", "P75", "P90", "P95", "P97"]


def load(text: str):
    return [r for r in csv.DictReader(io.StringIO(text)) if r.get("Sex") in ("1", "2")]


def main() -> int:
    official = load(urllib.request.urlopen(URL, timeout=30).read().decode("latin-1"))
    local = load(LOCAL.read_text())
    if len(official) != len(local):
        print(f"Row count differs: official {len(official)}, local {len(local)}")
        return 1
    problems = 0
    for a, b in zip(official, local):
        for column in ["Sex"] + COLUMNS:
            if column == "Sex":
                same = a[column] == b[column]
            else:
                same = abs(float(a[column]) - float(b[column])) <= 1e-9
            if not same:
                problems += 1
                print(f"Mismatch at Sex={a['Sex']} Agemos={a['Agemos']} {column}: official {a[column]} local {b[column]}")
    print("OK: local copy matches cdc.gov" if problems == 0 else f"{problems} mismatches")
    return 0 if problems == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
