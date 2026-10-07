# MVP Scope Lock (Phase 1.5)

> This document **overrides the scope tables** in `product-requirements.md` §4 and `implementation-roadmap.md` where they differ. Goal: a commercially viable first release a solo developer can ship.

## 1. The paying reason in one sentence
**Parents pay to keep an organised, multi-child growth record with real percentile analytics and a doctor-ready report. The honest estimate is the free hook.**

## 2. Feature buckets

### LAUNCH MVP
| Area | Included | Explicitly excluded |
|---|---|---|
| Onboarding | Role (parent / teen 13–17 / adult), birth date, chart sex, height + measuring guide, optional parents' heights (measured/reported/unknown), units. ≤10 required steps. Apple Declared Age Range signal where available | Weight, ethnicity, puberty quiz, relatives' heights |
| Age policy | Under-13 = parent-managed profile only. 18–20 near-adult messaging. 21+ no prediction | Child self-accounts |
| Prediction | CDC percentile **scenario** range (or the **conditional model** if Gate G1 passes), family-height range (Tanner) as context, qualitative uncertainty + drivers, Methods page | Khamis–Roche, any averaging, numeric confidence |
| Tracking | Measurement log, repeat-and-average, plausibility checks, CDC 2–20 stature chart, current percentile, velocity (≥6-month interval) | Weight/BMI charts, velocity percentiles |
| Safety | Signpost rules approved by the medical reviewer, disclaimers, copy lint list | Diagnosis, velocity-based red flags (no licensed velocity reference) |
| Habits | 4 simple daily check-ins (sleep, activity, food groups, posture) vs user-chosen targets. Gentle streak | Plans, XP/badges, exercise library, nutrition analysis |
| Learn | 6–8 short, cited, reviewed articles (bundled) | Remote CMS |
| Premium | Multiple profiles, PDF report, advanced analytics (percentile/velocity history) | AI coach |
| Payments | StoreKit 2 monthly + yearly, Family Sharing on, restore, honest paywall | RevenueCat, lifetime, trial (decided in Stage 2 tests) |
| Data | **Local-first** (Phase 2: JSON file store behind a `ProfileStore` protocol instead of SwiftData, see `phase-2-foundation.md` §7) **+ optional iCloud sync (CloudKit private DB)**, JSON/CSV export, "delete all data" (local + iCloud) | Our own server, accounts, Supabase |
| Notifications | Local monthly measuring reminder, optional habit reminder | Push server |
| Analytics | Privacy-first anonymous aggregate events (no health values, no identifiers for child profiles) **or none at launch** (Open Decision) | Ad/attribution SDKs |
| Platform | iPhone, iOS 17+, English, US storefront | iPad-optimised layouts, widgets, Watch |

### POST-LAUNCH P1 (first 1–3 updates, driven by data)
- AI coach (13+, server proxy, safety pipeline, caps) → introduces the **first backend** (minimal edge function + entitlement check through RevenueCat/App Store Server API)
- Habit plans + weekly review
- Paywall experiments (trial vs no trial, price points)
- Apple Health height read/write
- Parent–teen shared profile (CloudKit sharing)
- Gate G1 conditional model if not ready at launch

### POST-LAUNCH P2
- WHO references for non-US storefronts (after permission) + first expansion market
- One home-screen widget (next measurement / last percentile)
- Localization (Spanish first for the US Hispanic market. Then expansion-market languages)
- Lifetime "Core" plan test (AI excluded)
- Puberty-timing education (non-intimate, reviewer-approved). No input into predictions unless a validated model exists

### DO NOT BUILD UNLESS VALIDATED
| Feature | Validation required |
|---|---|
| Khamis–Roche | Primary paper + erratum verified, legal clearance, independent validation in a relevant population, reviewer approval |
| Bone-age / X-ray / photo-based estimation | Never as a consumer feature (regulatory: diagnostic) |
| AR/camera height measuring | Published accuracy within the error we already accept for home measuring, plus App Review acceptance |
| AI meal/nutrition photo analysis | Evidence that it helps without harm to minors. Not for under-18s |
| Exercise library / "growth exercises" | Only posture/mobility, and only if retention data shows demand. Never height claims |
| Community / social / UGC | Moderation capacity + legal review for minors |
| Referral program | Proof that organic sharing works. Abuse controls. Not for under-13 |
| Web app / web payments | Store-rules review and demand outside iOS |
| Velocity-based red flags | A licensed velocity reference + reviewer thresholds |
| Ethnicity input | No; a validated model needing it would be the only reason |

## 3. Revised phase plan (replaces the ordering in `implementation-roadmap.md`)

| # | Phase | Change vs Phase 1 |
|---|---|---|
| 1 | Research ✅ | — |
| 1.5 | Architecture validation ✅ (this) | New |
| 2 | Brand, UX, design system | + name clearance on the shortlist |
| 3 | Project foundation & CI | No Supabase project |
| 4 | Local data model (SwiftData + CloudKit) | Replaces server-mirrored model |
| 5 | PredictionKit + Growth Reference Layer (CDC) | Engine B removed. Gate G1 decision recorded |
| 6 | Onboarding, age policy, logging | Weight removed. Declared Age Range |
| 7 | Results, charts, signposting, Methods | — |
| 8 | **iCloud sync, export, delete-all** | Replaces "Backend, auth & sync" |
| 9 | Habits (simple) & Learn | Plans moved to P1 |
| 10 | StoreKit 2 paywall + Premium (profiles, PDF, analytics) | PDF export moved from Phase 13 into MVP |
| 11 | Privacy/compliance hardening, medical + legal review | Was Phase 14 |
| 12 | Beta, ASO, US launch | Was Phase 15 |
| P1 | AI coach + minimal backend, experiments, Health | Was Phases 11–12 |
| P2 | WHO/expansion, widget, localization, lifetime test | Was parts of 12–13 |

## 4. Cross-check of all documents (Phase 1 + 1.5)

### 4.1 Contradictions found and how they are resolved
| # | Contradiction | Resolution |
|---|---|---|
| 1 | Phase 1 Engine B "gated" vs Phase 1.5 "not planned" | Phase 1.5 wins. A note was added in `technical-architecture.md` / `product-requirements.md` |
| 2 | Supabase + RevenueCat in the MVP (TA §1, §6. Roadmap Phase 8) vs local-first MVP | Local-first wins. A note was added in TA and the roadmap |
| 3 | Velocity ≥3 months (TA §5.5, PRD) vs ≥6 months | ≥6 months. Notes added |
| 4 | Optional weight (PRD §4.1, TA §4) vs not collected | Not collected. Notes added |
| 5 | Clinician PDF = P2 (PRD, CR matrix, monetization.md) vs MVP Premium | MVP. Notes added |
| 6 | `monetization.md` free/premium table vs `monetization-strategy.md` | The strategy doc supersedes it. A note was added |
| 7 | Account deletion via a server function (TA, PRD FR-8) vs no accounts in MVP | MVP offers "delete all data" (local + iCloud). Server deletion arrives with P1 accounts |
| 8 | WHO 2007 as an easy option vs the licence | Permission required. Notes added |
| 9 | Roadmap "MVP = Phases 1–10 + …" vs the revised plan | §3 above supersedes it. Note added |
| 10 | CR matrix row 3 (relatives) "P3" and row 4 (puberty) "P2 input" | Relatives: do not collect. Puberty: education only (P2), no prediction input |

### 4.2 Unsupported claims (to verify before use in code or copy)
- Khamis–Roche error bounds (≈5.3 / 4.3–4.4 cm): from secondary sources.
- Tanner range revisions (±9 / ±10 cm): from a secondary source.
- Age-specific child↔adult height correlations (Gate G1): not yet retrieved.
- Sleep/activity guideline wording: from memory of AASM/AAP and US/WHO guidance, needs citation check.
- Competitor facts: third-party extracts. On-device check pending.
- India spend figure and DPDP timelines: press/legal-blog sources.
- US state app-store act status: changing litigation. Needs counsel.

### 4.3 Assumptions
- Parents are the primary payers. Multi-profile + PDF report are worth paying for (unvalidated → beta interviews).
- iOS 17+ minimum is acceptable.
- A local-first app that never receives personal data reduces COPPA/DPDP/GDPR exposure (legal confirmation needed).
- Organic short-form video with educational content can acquire users (the competitor's channel, a different tone).

### 4.4 Missing research
- Primary papers: Khamis–Roche + erratum, Tanner 1970, Hermanussen & Cole 2003, Aberdeen/other longitudinal correlation data, Kelly 2014 velocity reference.
- WHO permission process and timelines. IAP 2015 reuse terms.
- Medical-reviewer recruitment (pediatric endocrinology ideal).
- Real competitor flow (manual checklist).
- US parent willingness-to-pay data (stage 0 survey).

### 4.5 Legal / safety risks
- Health claims (App Store 1.4.1. FTC deceptive claims).
- Children's privacy: COPPA, state app-store age-assurance acts, CCPA/CPRA and state minors' privacy laws.
- False reassurance or false alarm from signposting.
- Body-image harm (percentile language, comparisons).
- Copyright/licensing of reference data and published coefficients.
- Subscription law (Guideline 3.1.2, state auto-renewal laws).

### 4.6 Scientific limitations
- No measure of puberty timing → the largest error source is unaddressed at launch.
- CDC is a 1963–1994 US cross-sectional reference.
- Percentile scenario is not an individually validated predictor.
- Mid-parental target has regression-to-the-mean bias and is only context.
- Home measurement error limits velocity over short intervals.

## 5. OPEN DECISIONS BEFORE PHASE 2

Only items that need the owner's approval:

1. **Approve US-only launch** (US storefront) and the expansion order.
2. **Approve the MVP scope lock** in §2, including **no AI coach at launch** and **local-first with no backend**.
3. **Approve dropping Khamis–Roche and weight collection.**
4. **Budget and recruit a medical reviewer** (pediatrician / pediatric endocrinologist) to (a) approve signpost thresholds and copy and (b) review the Gate G1 parameter dossier. Without this, launch is not recommended.
5. **Budget for a legal review** (COPPA, state app-store acts, privacy policy, subscription terms) before beta.
6. **Gate G1 ownership:** obtain the primary papers (library access or purchase) for the conditional-model parameters. Decide: launch with the scenario only if G1 isn't ready, or delay launch for it. *Recommendation: launch with the scenario. Do not delay.*
7. **Analytics at launch:** none vs a privacy-first anonymous tool. *Recommendation: privacy-first anonymous aggregate events, excluding child profiles.*
8. **Store age-rating target 13+** (recommended) after completing Apple's questionnaire truthfully.
9. **Start the WHO commercial-permission request now** (no cost, long lead time), yes or no.
10. **Shortlist 3–5 names** from `launch-strategy.md` §3 for clearance in Phase 2.
11. **Perform the manual competitor checklist** (`manual-competitor-checklist.md`) on a real iPhone.
