# Growth Reference Architecture (Phase 1.5)

> Design only. Not implemented. Defines the "Growth Reference Layer" so the chart and prediction engines can **select** a reference instead of hard-coding CDC.

## 1. Reference comparison

| Reference | Ages | Measures | Population / data | Method | Licensing (as researched) | Fit for us |
|---|---|---|---|---|---|---|
| **CDC 2000 Growth Charts** | 2–20 y (also 0–36 mo, but CDC itself recommends WHO for <2 y) | Stature-for-age, weight-for-age, BMI-for-age (+ others) | US national cross-sectional surveys 1963–1994 | LMS. Files `statage.csv`, `wtage.csv`, `bmiagerev.csv` give L, M, S + smoothed percentiles by sex and age in months | **Public domain** (CDC: "may be reproduced without permission. Citation appreciated") | ✅ **Launch reference (US)** |
| CDC 2022 Extended BMI-for-age | 2–20 y | BMI above the 95th percentile | US NHANES-based extension | **Not plain LMS above P95** (a different method for high percentiles) | Public domain | ❌ Not needed (no BMI shown to minors) |
| **WHO Child Growth Standards (2006)** | 0–5 y | Length/height, weight, BMI, etc. | MGRS: healthy breastfed children in Brazil, Ghana, India, Norway, Oman, USA | LMS (with BCPE) | WHO materials are under **CC BY-NC-SA 3.0 IGO**. **Commercial use needs WHO permission** (verify for the data tables specifically) | ⚠️ Only for ages 2–5 in non-US markets, after permission |
| **WHO Growth Reference (2007)** | 5–19 y (61–228 mo) | Height-for-age (5–19), weight-for-age (5–10), BMI-for-age (5–19) | **Reconstruction of the 1977 NCHS (US) data**, merged with MGRS under-5 data. Its adolescent data is US-derived from the 1960s–70s, so it is not a multi-country adolescent sample | LMS, monthly tables | Same WHO licence → **permission needed for commercial use** | ⚠️ Default for non-US markets **after permission**. Its "international" status is institutional, not empirical, for adolescents |
| IAP 2015 (India) | 5–18 y | Height, weight, BMI | 33,148 children from 14 Indian cities (affluent, urban) | LMS (Cole) | Published in *Indian Pediatrics*. **Reuse terms unknown, permission required** | Candidate for a future India launch |
| UK90 / UK-WHO | 0–23 y (UK90) | Many | British 1990 data (+ WHO under 4 in UK-WHO) | LMS | **MRC licence required** (via RCPCH) | Candidate only if launching in the UK |
| Other national (e.g., Korea 2017, China 2009, Japan) | Varies | Varies | National samples | Mostly LMS | Individual licensing | Future plug-ins |

**Velocity references** (Tanner–Whitehouse. Kelly et al. 2014 US): not in MVP. Licensing and verification are pending.

## 2. Calculations (shared by all LMS references)

- **Age:** exact age in months = days between birth date and measurement date / 30.4375 (CDC convention. Document per reference).
- **Interpolation:** linear interpolation of L, M and S between the two tabulated ages that bracket the exact age. CDC tabulates at half-month midpoints (24.0, 24.5, 25.5 … 240.0 mo). WHO 2007 is tabulated monthly. Never interpolate percentile values directly. Interpolate LMS and then compute.
- **z-score:** `z = ((X/M)^L − 1)/(L·S)` if L ≠ 0, else `ln(X/M)/S`.
- **Percentile:** `Φ(z)` (standard normal CDF) × 100. Display bounds: show "<0.1" / ">99.9" beyond these.
- **Inverse (height for a z):** `X = M·(1 + L·S·z)^(1/L)` (or `M·exp(S·z)`).
- **Extreme values:** WHO recommends a restricted SD adjustment for |z| > 3 on **weight-based** indicators only. Height uses the plain LMS formulas. Heights with |z| > 4 trigger "please re-measure" before saving.
- **Validation tests:** recompute the tabulated P3/P5/P10/P25/P50/P75/P90/P95/P97 from LMS for every age row and compare (tolerance ≤0.1 cm).
- **Sex:** references are binary by sex. The app asks "which growth chart should we use?" (female/male) with a neutral explanation. It does not collect gender identity. Users on puberty-affecting treatment are told that charts may not apply and to follow their clinician.

## 3. Growth Reference Layer (conceptual design)

```
protocol GrowthReference
  id: String                 // "CDC2000", "WHO2007", "IAP2015" …
  version: String            // data file version + checksum
  displayName, citation, licenceNote
  coverage(measure, sex) -> ClosedRange<AgeMonths>
  lms(measure, sex, ageMonths) -> LMS?        // interpolated, nil if out of range
  adultAgeMonths(sex) -> AgeMonths            // 240 for CDC, 228 for WHO2007
  applicableRegions: [RegionCode]             // informational, not enforced

ReferenceRegistry
  available: [GrowthReference]                // only those we are licensed to ship
  defaultFor(region: RegionCode) -> GrowthReference
  resolve(profile) -> GrowthReference         // user override > region default > CDC

Consumers: PercentileChart, PercentileService, PredictionEngine (scenario/conditional)
```

**Rules**
1. Every computed value records `referenceId` + `version`, so results are reproducible and changes are explainable ("Estimate updated: reference changed to WHO 2007").
2. References ship **bundled and checksummed** (no runtime download in MVP).
3. A reference is added to `available` only after a **licence check** and the **validation tests** pass.
4. **Selection is by region/country (user-chosen, default from storefront), never by ethnicity.**
5. Gaps: if the reference doesn't cover an age (e.g., WHO 2007 ends at 19 y), the engine reports `chartOnly`/`nearAdult` rather than borrowing another reference silently.
6. The adult age for projections is the reference's terminal age (CDC 20 y, WHO 19 y). The difference is disclosed.

## 4. Recommended reference strategy

| User | Reference | Notes |
|---|---|---|
| **US users (launch)** | **CDC 2000**, 2–20 y | Matches US clinical practice for ≥2 y (CDC recommendation), public domain |
| **Non-US users** | **Not supported at launch** (US storefront only). When expanding: **WHO 2007** (5–19) + WHO 2006 (2–5) **after WHO grants commercial permission**, or a licensed national reference where one exists and is clinically preferred (e.g., IAP 2015 for India, UK-WHO/UK90 for the UK) | Request WHO permission early (Open Decision) |
| **Where no better validated reference is available** | WHO 2007 (if permitted), otherwise CDC 2000 **with an explicit "US reference" label** and a note that percentiles may be systematically shifted for the user's population. Signpost thresholds are softened (reviewer decision) to avoid false alarms | Prefer accurate labelling over pretending to be universal |
| Under 2 y | Not supported (needs WHO 0–2 standards + infant workflows) | Out of scope |

**Why not WHO everywhere from day one:** (1) the licence needs permission for commercial apps, (2) for adolescents WHO 2007 is itself based on historical US data, so it gives no empirical advantage over CDC for US users, (3) US clinicians use CDC for ≥2 y, and parents will compare our chart to their pediatrician's.

## 5. Measures in scope

| Measure | MVP? | Reason |
|---|---|---|
| Stature-for-age | ✅ | Core |
| Weight-for-age | ❌ | Not needed without Khamis–Roche. Data minimization |
| BMI-for-age | ❌ | Body-image risk for minors. Not part of the product's promise |

## Sources
- CDC data files: https://cdc.gov/growthcharts/cdc-data-files.htm ; public-domain notice: https://stacks.cdc.gov/view/cdc/255920
- CDC recommendations (WHO <2 y, CDC ≥2 y): https://www.cdc.gov/growth-chart-training/hcp/overview/recommended.html
- CDC extended BMI: https://cdc.gov/growth-chart-training/hcp/overview/bmi-for-age-growth-charts.html
- WHO 5–19 reference: https://www.who.int/toolkits/growth-reference-data-for-5to19-years ; WHO licensing: https://www.who.int/copyright
- WHO 2007 construction (ENN summary): https://ennonline.net/fex/32/who
- IAP 2015 charts: https://pmc.ncbi.nlm.nih.gov/articles/PMC4481652 ; https://indianpediatrics.net/jan2015/jan-47-55.htm
- UK90 / RCPCH licensing: https://growth.rcpch.ac.uk/clinician/growth-references/
- CDC applicability abroad (Korean charts paper): https://pubmed.ncbi.nlm.nih.gov/29853938/
