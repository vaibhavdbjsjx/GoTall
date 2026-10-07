# Scientific Prediction Review (Phase 1.5)

> Purpose: lock a scientifically defensible prediction design before any code is written.
> Status: architecture validation only. **No formulas are implemented in this phase.**
> Research date: 2026-10-07.
> **Phase 3 update:** the scenario range is now the CDC *percentile channel* (widened one line each side when uncertainty is wider). This deviates from §1/§5's "no numeric width until Gate G1" and needs medical-reviewer approval; see `growth-engine.md` §7.5. Gate G1 remains open. Research limits: the cloud environment blocks direct page fetches for many sites, so sources were read through search-engine extracts. Every figure below gives its source and a verification status. **Figures marked "verify" must be checked against the primary paper by a human before they are used in code or copy.**

## 0. Summary of decisions

| Topic | Decision |
|---|---|
| Primary estimate | **Reference-percentile scenario** (CDC 2000 LMS) at launch. Upgrade to a **conditional (regression-to-the-mean) model** only after its parameters are sourced and verified (Gate G1) |
| Khamis–Roche | **Not implemented.** Moved to "do not build unless validated" (see §3) |
| Parent-height target | **Context only**, shown as a separate "family-height range". Never merged into the primary estimate |
| Growth trajectory / velocity | **Context + data-quality signal.** Velocity needs measurements ≥6 months apart. Never extrapolated to adult height |
| Lifestyle | **No centimetre contribution, ever.** A separate recommendation engine |
| Ethnicity | **Not collected** (§7) |
| Weight | **Not collected in MVP** (only Khamis–Roche needed it. BMI is not shown to minors) |
| Combining models | **No automatic averaging.** Presented side by side, with explicit decision rules (§6) |
| Confidence | **Qualitative only** (wider / moderate / narrower) with listed drivers. No percentages |
| Ages | Charts 2–20 y. Adult-height estimate 4.0–17.9 y. 18–20 y: "near or at adult height" trend messaging. 21+: no prediction |

## 1. Method A: Current-height percentile projection ("percentile tracking")

| Aspect | Assessment |
|---|---|
| Basis | The LMS method (Cole 1990) gives a z-score for the current height: `z = ((X/M)^L − 1)/(L·S)` (or `ln(X/M)/S` when L = 0). The projection assumes the child keeps the same z to the reference's adult age: `H = M_adult·(1 + L·S·z)^(1/L)` |
| Inputs | Sex for the chart, exact age, measured height |
| Age range | Mathematically 2–20 y (CDC). Weak before about 4 y and during puberty (see limitations) |
| Sex | Sex-specific references (female/male) |
| Reference population | CDC 2000: US national survey data collected 1963–1994 (NHES/NHANES), cross-sectional |
| Known limitations | (1) **Puberty timing:** early maturers temporarily rise in percentile and late maturers fall, so projections during puberty are biased by maturation timing, which we do not measure. (2) **Regression to the mean:** extreme-percentile children tend to end up less extreme. Pure tracking ignores this and over-projects extremes. (3) **Cross-sectional reference:** it describes the population at each age, not individual trajectories. (4) **Population:** US-based. Mean heights differ across countries. (5) **Measurement error** of a single home measurement |
| Published validation | The percentile-tracking projection itself is a heuristic. **Its accuracy as a predictor is not established by a single validation study.** Longitudinal studies (for example, the Aberdeen Growth Study, Tanner et al. 1956) report how strongly child height correlates with adult height by age. **Age-specific correlation values must be retrieved from the primary sources (verify)** before any numeric range is shown |
| Expected uncertainty | Several centimetres, larger in early childhood and puberty. **No numeric width ships until Gate G1** (§5) |
| Consumer app? | **Yes, if framed as a scenario:** "If you keep growing along your current percentile, you'd reach about X–Y cm." Not as "your adult height" |
| International users? | Only with a reference that suits the user's population (see `growth-reference-architecture.md`). CDC for US users |
| Use for | **Prediction (scenario-framed)** at launch. Prediction proper after the Gate G1 upgrade |

## 2. Method D: Parent-height (mid-parental) target

| Aspect | Assessment |
|---|---|
| Basis | Tanner et al. (1970): boys `(father + mother + 13 cm)/2`, girls `(father + mother − 13 cm)/2` |
| Inputs | Both biological parents' heights (measured is better than reported), sex |
| Age range | Any age (it is a target, not age-dependent) |
| Sex | The ±13 cm constant is a sex adjustment. Its validity at height extremes is questioned |
| Population | The constant and range come from British data of that era |
| Known limitations (from secondary literature: medRxiv 2022 "Accurate prediction of children's target height from their mid-parental height" and the references in it; **verify**) | (1) **Regression to the mean:** the target over-predicts for very tall parents and under-predicts for very short parents (one source reports errors of about 6 cm when mid-parental height is below −2 SDS). (2) The constant 13 cm ignores height level. (3) Parents' heights are often **self-reported** (tend to be overestimated) and not age-corrected. (4) Secular trends: children of each generation may be taller. (5) Unknown/non-biological parents |
| Published validation | Tanner derived ±8.5 cm (about the 3rd–97th percentile) **theoretically**. A secondary source states later revisions to about ±9 cm (girls) / ±10 cm (boys) (**verify primary**) |
| Expected uncertainty | Large: a range of roughly ±8.5–10 cm around the target |
| Consumer app? | **Yes as context.** It is what users intuitively expect ("my parents are tall") |
| International users? | Yes as context (the formula has no population reference table), with caveats |
| Use for | **Context only:** "Family-height range". Never the primary prediction. Never averaged with Method A |

*Future upgrade (P2, Gate G1):* a regression-corrected target height (e.g., Hermanussen & Cole 2003, "The calculation of target height reconsidered", *Horm Res* — **verify**), which shrinks the target toward the population mean based on the parent–child correlation. It requires a population-specific correlation and SD.

## 3. Method B: Khamis–Roche (1994)

| Aspect | Assessment |
|---|---|
| Source | Khamis HJ, Roche AF. *Predicting adult stature without using skeletal age: the Khamis–Roche method.* Pediatrics 1994;94(4 Pt 1):504–507. PMID 7936860. **Erratum: Pediatrics 1995;95:457** (any coefficient transcription must include the erratum) |
| Basis | Linear regression: predicted adult stature = β₀ + β₁·height + β₂·weight + β₃·mid-parental height, with **separate coefficient sets for each sex and each half-year of age** (4.0–17.5 y). A modification of the Roche–Wainer–Thissen method without skeletal age |
| Inputs | Age, sex, current height, current weight, mid-parental height |
| Age range | 4.0–17.5 y |
| Sex | Separate male/female coefficients |
| Reference population | **223 white males and 210 white females from southwest Ohio (Fels Longitudinal Study)**, healthy children. Historical cohort |
| Published accuracy | Secondary sources report a 90% prediction-error bound of about 5.3 cm (boys) and about 4.3–4.4 cm (girls) in the derivation sample (**verify in the primary paper**). Errors are only slightly larger than Roche–Wainer–Thissen with skeletal age |
| External validation | Limited. Studies in Portuguese children (Jornal de Pediatria) assessed validity relative to bone age. Secondary sources note that no large prospective independent validation exists, particularly for non-white populations. Some reports describe over-estimation in some East Asian groups (**weak, secondary evidence**) |
| Known limitations | Population specificity. Historical secular trend. Derivation-sample accuracy is optimistic. It needs weight (adds data collection and body-image sensitivity). Coefficients would have to be copied from a copyrighted journal table (legal check needed) |
| Consumer app? | **Not at launch.** We cannot restrict it to "white American children" without collecting ethnicity, which we decided not to do (§7), so we would be applying it to populations where it is unvalidated |
| International? | **No** |
| Use for | **Do not build unless validated.** Possible future use only as a clearly labelled secondary comparison if **all** of these hold: (1) primary paper + erratum obtained and coefficients double-entered and verified, (2) legal clearance to embed the coefficients, (3) the medical reviewer agrees that a caveated comparison helps users more than it misleads, (4) an independent validation in a relevant population is identified |

**Phase 1 is corrected:** Phase 1 listed Engine B as "gated". Phase 1.5 moves it to **not planned** and removes weight collection from the MVP.

## 4. Method C: Individual growth trajectory / velocity

| Aspect | Assessment |
|---|---|
| Basis | Annualised height velocity = Δheight / Δtime (years), using a robust slope across ≥2 averaged measurements. Percentile trajectory = z-scores over time |
| Inputs | Dated measurement series |
| Age range | 2–20 y (charts). Most informative in childhood and puberty |
| Sex | Interpretation is sex-specific (girls' pubertal spurt is earlier) |
| Reference | **No CDC velocity reference exists.** Candidates: Tanner–Whitehouse velocity charts (UK, historical), Kelly et al. 2014 US height-velocity reference ranges (*J Clin Endocrinol Metab*, **verify** availability and licensing). None is integrated at launch |
| Known limitations | Home measurement error dominates over short intervals. There is seasonal variation in growth rate. Clinical practice usually assesses velocity over **≥6–12 months**. Phase 1's "≥3 months" is **corrected to ≥6 months** |
| Validation | Velocity is a measurement, not a model. Its interpretation needs a velocity reference |
| Consumer app? | **Yes**, as a descriptive number + trend |
| International? | Yes (descriptive). Interpretive thresholds are not used until a velocity reference is licensed |
| Use for | **Context + data quality:** (a) shows growth rate, (b) detects percentile drift that makes the Method A scenario less stable (lowers confidence), (c) "growth has likely slowed/stopped" messaging at late-adolescent ages (thresholds set with the medical reviewer). **Never extrapolated linearly to an adult height** |

## 5. Gate G1: the conditional model (the principled upgrade to Method A)

A defensible way to combine current height and parents' heights *without arbitrary averaging* is the **conditional expectation under a multivariate normal model** (standard in growth statistics; see Cole's work on conditional references and target height). For adult height SDS `Y`, current height SDS `Xc` and mid-parental SDS `Xp`:

`E[Y | Xc, Xp]` and `SD[Y | Xc, Xp]` follow from the **age- and sex-specific correlation matrix** between `Y`, `Xc` and `Xp`.

- It naturally includes regression to the mean and gives a **derived** (not invented) prediction interval.
- **Gate G1 requirements:** (1) correlation values from peer-reviewed longitudinal data by age and sex, in a population comparable to the reference, (2) a written "parameter dossier" with citations, (3) medical reviewer sign-off, (4) back-tests against published examples.
- **If G1 fails:** launch with the Method A **scenario** + qualitative uncertainty, and show the family-height range separately. This is honest and still useful.

## 6. Prediction output contract and decision layer

### 6.1 Output (conceptual, not code)
```
PredictionResult
  status: estimateAvailable | chartOnly | nearAdult | adult | insufficientData
  primaryEstimate?: { kind: scenario | conditional, lowCm, highCm, centralCm? }
       // centralCm only if kind == conditional (derived), otherwise omitted
  uncertainty: wider | moderate | narrower
  uncertaintyDrivers: [ageFarFromAdult, pubertyUnknown, fewMeasurements,
                       percentileDrifting, parentHeightsReported, parentHeightsMissing]
  currentPercentile: { reference: "CDC2000", z, percentile }
  familyHeightRange?: { lowCm, highCm, targetCm, source: measured|reported }
  velocity?: { cmPerYear, intervalMonths, quality }
  inputsUsed: [...], inputsMissing: [...]
  limitations: [stringKeys], signposts: [ruleIds]
  referenceVersion, engineVersion
```

### 6.2 Decision rules
1. **Never average** the scenario/conditional estimate with the family-height range.
2. **Primary estimate:** the conditional model if G1 passed, else the scenario. Scenario copy always says "if you keep growing along your current percentile".
3. **Central estimate:** only when derived from a model with an interval (conditional). Otherwise show the range only.
4. **Uncertainty level:** rule-based from the drivers (for example, age < 10 or puberty-age band → at most "moderate". Percentile drift > 0.5 SD over 12 months → "wider". ≥3 consistent measurements → may narrow by one level). Final thresholds go to the medical reviewer. **No percentages.**
5. **Disagreement:** if the primary range and the family-height range don't overlap, show both, explain the common reasons (puberty timing, measurement error, parents' heights reported), and if the gap is large, add the "worth discussing with a doctor" signpost (threshold set by the reviewer).
6. **Age gating:** <4 y → chart + percentile only. 4–17.9 y → estimate. 18–20 y → "you're likely at or near adult height" (trend-based). ≥21 y → no prediction; current measured height is shown.
7. **Language bans (enforced by a copy lint list):** "accurate to X%", "AI predicts", "you will reach", "guaranteed", "increase your height", "boost growth hormone".

## 7. Ethnicity decision

| Option | Assessment |
|---|---|
| A. Use mathematically | ❌ No validated model in our stack takes ethnicity as an input. Inventing ethnic adjustments would be pseudo-science |
| B. Use to select a reference | ❌ References are defined by **country/population of measurement**, not race. WHO's position for under-5s is a single standard regardless of ethnicity (MGRS. Most groups within about 0.5 SD). Selecting by self-identified ethnicity also mishandles mixed heritage and diaspora (secular trend follows environment) |
| C. Collect but not use | ❌ Violates data minimization. Special-category data under GDPR (racial/ethnic origin). Sensitive data for minors |
| **D. Do not collect** | ✅ **Chosen** |

If regional references are added later, selection uses the user's **chosen country/region** (default from storefront), with a manual override. Never ethnicity.
*Note:* the Phase 1 research did not record the competitor asking ethnicity. This is **unverified** and is on the manual checklist.

## 8. Lifestyle engine (separate, no cm)

- **Principle kept:** lifestyle inputs never change any predicted value. The engines share no code path. A property test proves invariance.
- **Legitimate uses:** compare the user's habits to **public guidance** and to **targets the user chooses**:
  - Sleep duration/consistency vs age-appropriate recommendations (AASM consensus endorsed by AAP: e.g., 9–12 h for 6–12 y, 8–10 h for 13–18 y. **Verify wording before copy**).
  - Physical activity vs guidance (e.g., about 60 min/day moderate-to-vigorous for 6–17 y per US Physical Activity Guidelines / WHO. **Verify**).
  - Nutrition **adequacy as food groups** (e.g., calcium/vitamin-D sources, protein, fruit/veg per Dietary Guidelines/MyPlate). **No calories, no weight goals for minors.**
  - Recovery/rest days for active teens (education only).
  - Posture: education ("posture can change how tall you measure standing, not bone length").
- **Allowed output:** "Your sleep consistency is below your chosen target this week."
- **Forbidden output:** "Poor sleep will reduce your predicted height by 3 cm." / "Do this to grow taller."
- Copy states that good habits support healthy development and help a child **reach their genetic potential**, and that they do not add height beyond it. Severe deprivation can impair growth, which is a medical matter → signpost.

## 9. Age policy (product)

| Group | Policy |
|---|---|
| Under 13 | **Parent-managed profile only.** The parent is the app user. The child never self-onboards. No coach, sharing, referrals or notifications aimed at the child. Parent-facing language |
| 13–17 | Self-use allowed. Teen-safe defaults. Optional parent link (P1). Age signals from Apple's Declared Age Range API where required by law (Texas/Utah/Louisiana-style app store acts. **Legal status is changing, confirm with counsel**). AI coach (P1) only with additional safety review |
| 18–20 | Trend tracking. "Near/at adult height" messaging. No adult-height prediction beyond the trend |
| 21+ | No prediction. Measurement log, posture/health content only. Not a target segment |
| Store age rating | Answer Apple's questionnaire truthfully. **Product policy: target the 13+ rating** (the app's direct users are teens and parents). Do not join the Kids Category. **Do not copy the competitor's rating** |

## 10. Unsupported or weak claims found in Phase 1 (now corrected)

| Phase 1 statement | Problem | Fix |
|---|---|---|
| Khamis–Roche "gated" in Engine B | Can't be population-gated without ethnicity | Not planned (§3) |
| Velocity from measurements ≥3 months apart | Too short given home measurement error/seasonality | ≥6 months |
| Optional weight in onboarding | Only needed for Khamis–Roche. Body-image risk | Removed from MVP |
| "Overall range = union of engine ranges" | A union is an arbitrary combination | Replaced by the §6 rules |
| WHO 2007 as an easy P2 option | WHO data is CC BY-NC-SA. **Commercial use needs WHO permission** | See reference architecture |
| ±8.5 cm treated as an established range | It is a theoretical Tanner range. Later revisions exist | Cited as theoretical, revisions noted |

## 11. Scientific limitations we will state publicly (Methods page)

1. Nobody can know an individual's exact adult height. All estimates are ranges.
2. Puberty timing is the largest unknown and we do not measure it.
3. References describe populations, not individuals, and come from specific countries and eras.
4. Home measurements vary. Repeat and average.
5. The app does not detect or diagnose growth disorders. It only suggests talking to a doctor when patterns are unusual.

## Sources
- Khamis & Roche 1994, PubMed: https://pubmed.ncbi.nlm.nih.gov/7936860/ (erratum Pediatrics 1995;95:457); Wright State repository: https://corescholar.libraries.wright.edu/math/247 ; Semantic Scholar: https://www.semanticscholar.org/paper/a1e423534abf08c63972c396a6db0fbd6691560b
- Khamis–Roche validity in Portuguese youth (J Pediatr Rio): https://www.jped.com.br/en-validity-khamis-roche-method-relative-bone-articulo-S002175572600080X ; ResearchGate: https://www.researchgate.net/publication/265166776
- Mid-parental height limitations (medRxiv 2022): https://www.medrxiv.org/content/10.1101/2022.10.31.22281712.full.pdf
- Puberty timing and adult height (PMC): https://pmc.ncbi.nlm.nih.gov/articles/PMC3579950
- WHO MGRS ethnicity findings: https://pmc.ncbi.nlm.nih.gov/articles/PMC4014086
- CDC growth chart recommendations: https://www.cdc.gov/growth-chart-training/hcp/overview/recommended.html
- Secondary summary of methods (not authoritative): https://hylyght.com/en/academy/e-learning/growth-tracker/adult-height-prediction-reliability-and-dis-advantages-of-the-most-common-methods
