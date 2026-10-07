#!/usr/bin/env python3
"""Generate Sources/GrowthEngine/Reference/CDC2000StatureData.swift from Reference/cdc2000/statage.csv.

Usage: python3 scripts/generate_cdc_reference.py
The CSV is the CDC 2000 stature-for-age file (see Reference/cdc2000/PROVENANCE.md).
"""
import csv
import hashlib
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
SOURCE = ROOT / "Reference" / "cdc2000" / "statage.csv"
OUTPUT = ROOT / "Sources" / "GrowthEngine" / "Reference" / "CDC2000StatureData.swift"
PERCENTILES = ["P3", "P5", "P10", "P25", "P50", "P75", "P90", "P95", "P97"]


def main() -> None:
    raw = SOURCE.read_bytes()
    digest = hashlib.sha256(raw).hexdigest()
    rows = list(csv.DictReader(raw.decode("ascii").splitlines()))
    assert len(rows) == 436, len(rows)

    def block(sex_code: str) -> str:
        lines = []
        for r in rows:
            if r["Sex"] != sex_code:
                continue
            pct = ", ".join(r[p] for p in PERCENTILES)
            lines.append(f"        .init(ageMonths: {r['Agemos']}, l: {r['L']}, m: {r['M']}, s: {r['S']}, publishedPercentiles: [{pct}]),")
        return "\n".join(lines)

    swift = f"""// GENERATED FILE. Do not edit by hand.
// Source: Reference/cdc2000/statage.csv (CDC 2000 stature-for-age, 2–20 y), SHA-256 {digest}
// Regenerate with: python3 scripts/generate_cdc_reference.py

enum CDC2000StatureData {{
    static let sourceSHA256 = "{digest}"

    /// Sex = 1 in the CDC file.
    static let male: [CDCStatureRow] = [
{block("1")}
    ]

    /// Sex = 2 in the CDC file.
    static let female: [CDCStatureRow] = [
{block("2")}
    ]
}}
"""
    OUTPUT.write_text(swift)
    print(f"Wrote {OUTPUT.relative_to(ROOT)} ({len(rows)} rows, sha256 {digest})")


if __name__ == "__main__":
    main()
