# Growth Engine

> Phase 3 deliverable. How the app turns measurements into percentiles, growth speed, a family-height range and an adult-height scenario.
> Code: `Sources/GrowthEngine` (pure science, no UI, profile or AI code) and `Sources/GrowthCore/Growth` (adapters, insights, wording).
> **Status: draft for medical-reviewer inspection.** Rules marked *(reviewer)* are product assumptions that need sign-off before release.

## 1. Data source

| Item | Value |
|---|---|
| Reference | CDC 2000 Growth Charts, stature-for-age, 2–20 years |
| File | `Reference/cdc2000/statage.csv` (CDC layout: Sex, Agemos, L, M, S, P3…P97), 436 rows |
| Sexes | 1 = male, 2 = female; 218 rows each |
| Ages | 24.0, 24.5, 25.5 … 239.5, 240.0 months |
| Units | centimetres |
| Licence | Public domain (U.S. government work) |
| SHA-256 | `45130d2a9d7c50c54a47e7ba626b66c61d4554bc2d901198cedd9419a53f7251` (checked by a unit test) |
| Verification | Two independent redistributions agree on every L, M and S value to 1e-9. LMS-derived percentiles reproduce CDC's published P3–P97 columns to < 1e-6 cm for every row (unit test). cdc.gov itself was unreachable from the build environment; `scripts/verify_cdc_reference.py` compares against the official download. See `Reference/cdc2000/PROVENANCE.md` |

`GrowthReference` is a protocol. `ReferenceRegistry.reference(forRegion:)` returns CDC 2000 for every region at launch (US-only). WHO 2007, IAP 2015 and other references plug in later as new implementations, after licence checks.

## 2. Age

- **Exact age (months)** = completed days between birth date and measurement date ÷ 30.4375 (CDC convention). Days are counted between calendar start-of-days, so the time of day doesn't matter.
- **Age bands and eligibility** use **completed years** (birthday-based), so boundaries fall exactly on birthdays. *(Found by a test: months ÷ 12 put an 18th birthday at 17.998 years.)*

## 3. Percentile and z-score (LMS method, Cole 1990)

For age *t*, interpolate L, M and S **linearly** between the two tabulated ages that bracket *t* (exact tabulated ages use the row as-is). Rows are 0.5–1 month apart, so linear and cubic interpolation differ negligibly for stature.

```
z = ((X / M)^L − 1) / (L · S)        (L ≠ 0)
z = ln(X / M) / S                    (L = 0)
percentile = Φ(z) × 100               Φ = standard normal CDF, computed as ½·erfc(−z/√2)
height at z: X = M · (1 + L·S·z)^(1/L)
```

- Supported: 24.0–240.0 months inclusive. Outside that range the engine returns an explicit error, never an extrapolated value.
- **Display:** whole ordinal numbers only ("63rd percentile"). Below 0.5 shows "below the 1st"; above 99.5 shows "above the 99th". The precise value stays internal.
- **Major lines:** 3rd, 10th, 25th, 50th, 75th, 90th, 97th, with exact z-scores Φ⁻¹(p).

## 4. Measurement series

- Measurements before the birth date or with invalid heights are ignored.
- **Same calendar day → one point**, height averaged (repeat-and-average). The point takes the **lowest** quality of its parts (estimate < home < professional). Two entries on one day can therefore never create a growth speed.
- Points are always sorted by date, whatever order they were entered in.

## 5. Growth velocity (growth speed)

1. Needs at least two measurement days.
2. Candidates: earlier points **at least 182 days (≈6 months)** before the latest. Home-measurement error and seasonal variation make shorter intervals misleading when annualised.
3. Of the candidates, use the one whose interval is **closest to 365 days**.
4. velocity = Δheight ÷ (Δdays ÷ 365.25) cm/year.
5. Direction: increase > +0.5 cm; "little change" within ±0.5 cm; decrease < −0.5 cm, described as "usually a measuring difference" and never as shrinking.
6. If no candidate exists: "Not enough measurements yet", or the exact date after which a measurement will make speed available (first point + 182 days).
7. Flags when either endpoint is an estimate. There are **no velocity percentiles or velocity-based red flags** (no licensed velocity reference yet).

## 6. Family-height range (context only)

- Tanner, Goldstein & Whitehouse (1970): **boys (father + mother + 13 cm) ÷ 2; girls (father + mother − 13 cm) ÷ 2. Range = midpoint ± 8.5 cm.**
- Requires **both** biological parents' heights, each within 120–230 cm. Missing or "don't know" → no range. **Values are never inferred.**
- Also shown: where the midpoint sits among adult heights (percentile at 240 months).
- Flags when a parent's height was an estimate (remembered heights tend to be high).
- Shown only for ages 2–17 (parent heights aren't collected after that).
- **Never averaged** with the adult-height scenario and never called a prediction ("Context, not a prediction").
- Stated limitations: regression to the mean at the extremes, the fixed 13 cm adjustment, the theoretical ±8.5 cm range (later work suggests ±9–10 cm).

## 7. Adult-height scenario ("current growth-percentile scenario")

### 7.1 Eligibility (completed years at today's date)

| Age | Outcome |
|---|---|
| < 2 | Unsupported |
| 2–3 | Chart and percentile only |
| 4–17 | Scenario, if a measurement inside the reference age range exists |
| 18–20 | "Near adult height". If velocity is available: < 1 cm/year → "growth mostly complete", otherwise "still growing at X cm/year"; else "unknown" |
| 21+ | "Measured height is adult height". No estimate |

### 7.2 Method

1. **Basis:** up to the 3 most recent measurement days within 12 months of the latest, using measured points if any exist (otherwise estimates). Basis z = mean of their z-scores.
2. If the basis z is **below the 3rd or above the 97th line**, no range is shown ("estimates are least reliable at the edges of the chart"), with a gentle suggestion that a pediatrician can look at growth in context.
3. Otherwise find the **percentile channel**: the major lines immediately below and above the basis z.
4. If uncertainty is **wider**, widen the channel by one major line on each side (capped at 3rd/97th).
5. **Range** = heights of the channel's lines at the reference's terminal age (240 months for CDC).
6. **No central estimate** is shown. The scenario method has no derived interval, and showing one number would imply false precision (Phase 1.5 rule 3).

Wording: "If growth stays between the 50th and 75th percentile lines, adult height would be in this range." "This is a growth-trajectory estimate, not a guarantee." No AI is involved.

### 7.3 Uncertainty (qualitative; no percentages)

| # | Rule | Effect |
|---|---|---|
| 1 | Age at latest measurement. Girls: < 10 *far from adult age*; 10–13 *puberty age window*; 14–15 moderate; ≥ 16 *late adolescence*. Boys: < 11; 11–14; 15–16; ≥ 17 | Wider / wider / moderate / narrower. Floor: moderate for the two "wider" bands *(reviewer: age cut-offs reflect typical puberty timing, about two years earlier in girls)* |
| 2 | Basis includes an estimated height | One level wider |
| 3 | Latest measurement > 183 days before today | One level wider |
| 4 | Over the last 24 months (span ≥ 12 months), the z-score moved > 0.5 between the first and latest point | One level wider (*percentile shifting*) |
| 5 | ≥ 3 measured points over ≥ 12 months with max − min z ≤ 0.25, and no estimate or stale data | One level narrower, never below the age floor (*consistent history*) |
| — | Only one recent measurement | Listed as a driver; no level change |

Every applied rule is listed to the user in plain words ("Why this estimate?").

### 7.4 What does NOT affect the estimate

Sleep, activity, eating, goals, intent and "recent growth change" are **not inputs**: the engine has no parameter for them. A unit test changes all of them and asserts identical outputs. The explanation sheet lists them under "What did not affect it".

### 7.5 Change from Phase 1.5 (needs reviewer approval)

Phase 1.5 said no numeric width would ship until Gate G1 (the conditional model with sourced correlations), and suggested qualitative bands only. Phase 3 shows a **numeric range defined by published CDC percentile lines (the "channel")**. No number is invented: the bounds are reference values, and the widening rule is explicit. The range is labelled as a scenario, not a confidence interval, and is not claimed to contain the true adult height with any probability. **Gate G1 is still open:** once peer-reviewed age-specific correlations are sourced, the conditional model should replace or be validated against this channel.

## 8. Insights (deterministic)

Generated in priority order from stored data only. Kinds:
- concern / record-keeping
- estimated height
- stale measurement (> 6 months)
- one measurement so far, with the suggested date
- needs more time, with the exact months and the date speed becomes available
- recent growth, with the real change and speed
- little change
- worth re-measuring (decrease)
- steady path (≥ 3 measured points over ≥ 12 months within 0.25 SD)
- percentile shift (> 0.5 SD), with the from/to percentiles
- family-height context (close if within 0.5 SD)
- sleep consistency (from goals)
- a default "consistency beats frequency"

There is no praise or judgement ("growing perfectly", "too short").

**Next measurement** (product convention, not clinical): every 3 months at ages 2–17, every 6 months at 18–20, none for adults.

## 9. Safety signposts (DRAFT, reviewer)

Only measured (non-estimated) heights can trigger them:
1. Latest height below the 3rd percentile.
2. Latest height above the 97th percentile.
3. Downward crossing of ≥ 2 major lines between the latest point and the most recent measured point ≥ 12 months earlier.

Copy is calm and non-diagnostic ("worth mentioning at the next check-up"). Anyone who chose "worried about growth" sees the concern text: growth varies considerably, one measurement isn't enough to judge anything, and a pediatrician can review measurements in context.

## 10. Measurement validation (add/edit)

- **Blocking:** height outside 60–250 cm, date in the future, date before birth.
- **Warnings** (can save):
  - same day as another measurement (they'll be averaged)
  - |z| > 4 for age (probably a typo or unit mix-up)
  - > 1 cm lower than the previous measurement
  - > 1 cm taller than a later one
- A profile always keeps at least one measurement.

## 11. Profile editing rules

- Birth-date edits are validated: not in the future, ≤ 100 years, ≥ 2 years old, under-13 self profiles need a guardian, and no measurement may predate it.
- If an edited birth date makes answers irrelevant (parent heights after 17, growth change and growth-only goals at 21+), the user is shown exactly what will be removed and must confirm.
- Pruning happens **only on an explicit birth-date edit**: natural ageing never deletes data.
- Changing the chart recalculates everything, and the editor says so.

## 12. Terminology

| Use | Don't use |
|---|---|
| Estimated adult height, growth-trajectory estimate, scenario | Prediction (for the scenario), "your adult height", "you will be" |
| Family-height range, context | Target height as a promise, "predicted height" |
| Percentile, position on the CDC growth chart | Normal/abnormal, short/tall labels |
| Growth speed | Growth rate percentiles (not available) |
| Narrower / moderate / wider range | Confidence %, accuracy % |

Banned phrases are enforced in tests (`CopyGuard`): "guarantee" (except "not a guarantee"), "unlock your", "become taller", "maximum height", "add cm", "grow taller", "% accurate", "AI knows", "you will reach", "boost growth hormone", "HGH", "increase your height", "true height".

## 13. Known limitations

1. Puberty timing, the largest source of error, is not measured, by design (no invasive questions).
2. CDC 2000 is based on US surveys from 1963–1994; it isn't validated for non-US populations (US-only launch).
3. Percentile tracking is a heuristic. Children at the extremes tend to regress toward the mean, which the channel doesn't model (Gate G1 would).
4. Home measurements vary by several millimetres or more, so short-interval changes aren't interpreted.
5. The family-height formula is a population heuristic with known biases at the extremes.
6. Signpost and uncertainty thresholds are product assumptions pending medical review.
7. The app does not detect or diagnose any condition.
