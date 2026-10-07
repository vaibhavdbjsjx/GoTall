# CDC 2000 stature-for-age reference (2–20 years)

`statage.csv` contains the CDC 2000 Growth Charts stature-for-age LMS parameters and smoothed percentiles
(P3–P97), by sex (1 = male, 2 = female) and age in months (24.0, 24.5, 25.5 … 239.5, 240.0). 436 rows.

- **Publisher:** U.S. Centers for Disease Control and Prevention, National Center for Health Statistics.
- **Official source:** https://www.cdc.gov/growthcharts/cdc-data-files.htm ("Stature-for-age charts, 2 to 20 years", `statage.csv`). Unchanged since the 2000 release.
- **Licence:** public domain (U.S. government work; CDC states the material "may be reproduced or copied without permission").
- **SHA-256 of this file:** `45130d2a9d7c50c54a47e7ba626b66c61d4554bc2d901198cedd9419a53f7251`

## How this copy was obtained and verified (2026-10-07)

The build environment's network policy blocks cdc.gov, so the file could not be downloaded from CDC directly.
It was obtained from two independent redistributions and cross-checked:

1. `growthcharts` 0.2.1 on PyPI (MIT licence), which ships the file in CDC's original column layout.
2. `rcpchgrowth` 4.6.5 on PyPI (Royal College of Paediatrics and Child Health), whose `cdc2-20.json` holds the same LMS values. Only the numbers were compared; nothing from this AGPL package is included.

Results:
- All 436 rows of L, M and S agree between the two sources to better than 1e-9.
- Percentiles recomputed from L, M and S reproduce the CDC-published P3, P5, P10, P25, P50, P75, P90, P95 and P97 columns to within 3e-7 cm for every row. This check is repeated by the unit tests.
- Age-20 medians are 176.85 cm (male) and 163.34 cm (female), matching CDC's published adult medians.

**Still to do (owner):** on a machine with cdc.gov access, run `python3 scripts/verify_cdc_reference.py`. It downloads the official file and compares every value to this copy.

`Sources/GrowthEngine/Reference/CDC2000StatureData.swift` is generated from this file by `scripts/generate_cdc_reference.py`. Do not edit it by hand.
