# Technical Architecture

> Phase 1 deliverable. Design only. No dependencies are added in Phase 1. Library and vendor names below are **proposals** to confirm in Phase 3, after checking current pricing and terms.
> **Phase 1.5 update (supersedes conflicting parts below):** the MVP is **local-first** (SwiftData + optional iCloud/CloudKit private-database sync) with **no Supabase or RevenueCat** (both move to P1 with the AI coach). StoreKit 2 handles entitlements on the device. **Engine B (Khamis–Roche) is not planned** (`scientific-prediction-review.md` §3). Weight is not collected. Velocity needs measurements ≥6 months apart. Combining rules are in `scientific-prediction-review.md` §6 (no union of ranges). References go through the Growth Reference Layer (`growth-reference-architecture.md`). WHO data needs permission for commercial use.

## 1. Overview

```
┌──────────────────────── iOS app (SwiftUI) ─────────────────────────┐
│  Features: Onboarding · Results · Log · Charts · Habits · Family   │
│            Coach (P2) · Settings/Privacy · Paywall                  │
│  Core:     PredictionKit (pure Swift, offline, deterministic)       │
│            ReferenceData (CDC/WHO LMS tables bundled, versioned)    │
│            Persistence (SwiftData, local-first) · SyncEngine        │
│            Entitlements (StoreKit 2 via RevenueCat SDK)             │
└───────────────┬─────────────────────────────────┬──────────────────┘
                │ HTTPS (user JWT)                │ StoreKit
┌───────────────▼──────────────┐       ┌──────────▼─────────┐
│ Supabase                      │◄──────┤ RevenueCat         │
│  Auth (Sign in with Apple)    │webhook│ (receipt validation│
│  Postgres + Row Level Security│       │  & entitlements)   │
│  Edge Functions:              │       └────────────────────┘
│   coach · account-delete ·    │──────► LLM provider API (key server-side only)
│   export · rc-webhook         │
└───────────────────────────────┘
```

**Key decisions**
- **Predictions run on the device** in a pure, tested Swift package. They work offline and are reproducible. No secrets are needed.
- **The backend exists for sync, accounts, entitlements, deletion/export and the LLM proxy.** The app is fully usable without it.
- **No secrets in the app.** The app ships only public identifiers (Supabase URL + anon key, which are public by design and protected by RLS, and the RevenueCat public SDK key). The LLM key, service-role key and webhook secrets live only in server-side secrets.

## 2. Client stack comparison (solo developer, iOS-first)

| Criterion | **SwiftUI (native)** | Flutter | React Native (Expo) |
|---|---|---|---|
| iOS look/feel & accessibility | Best. Native Dynamic Type, VoiceOver, Swift Charts audio graphs | Good, custom-rendered. Accessibility needs extra work | Good with native components |
| HealthKit, WidgetKit, Live Activities, App Intents | First-class | Plugins + native Swift for widgets anyway | Native modules + Swift for widgets anyway |
| Charts | Swift Charts built in | Third-party packages | Third-party packages |
| StoreKit 2 | Native (+ RevenueCat SDK) | RevenueCat plugin | RevenueCat SDK |
| Android later | Separate app needed | Same codebase | Same codebase |
| Solo-dev velocity on iOS-only | High (one language, Xcode previews) | High, but there is a second toolchain for native bits | High. JS/TS ecosystem, native bits still needed |
| Long-term risk | Low (Apple-backed) | Low–medium | Medium (dependency churn) |
| App size / performance | Smallest / best | Larger | Larger |
| AI-assisted coding support | Strong | Strong | Strong |

**Recommendation: SwiftUI (Swift 6, iOS 17+ minimum).** The product is iOS-only. It depends heavily on Apple-native features (HealthKit, widgets, charts with accessibility, StoreKit, Sign in with Apple), and trust and polish are part of the brand. Widgets require native Swift in every option anyway. If Android is validated later (P3), build a separate client that shares the backend, and port PredictionKit (pure logic, about 1K lines) with the same test vectors.

*Why iOS 17+:* SwiftData, `@Observable`, the modern Swift Charts APIs and interactive widgets. The tradeoff (dropping iOS 15–16 users) is acceptable for a new app. Re-check against Apple's adoption figures at Phase 3.

## 3. App architecture

- **Pattern:** feature modules + `@Observable` view models + dependency-injected services (protocols for testability). No heavy framework (no TCA) to keep the solo dev's cognitive load low.
- **Swift Package layout (local packages):**
  - `PredictionKit`: pure functions, zero dependencies, 100% unit-tested.
  - `ReferenceData`: bundled CDC (and WHO for P2) LMS CSVs + loader + checksum + version.
  - `DesignSystem`: tokens, components, chart styles.
  - `Persistence`: SwiftData models, migrations, repository protocols.
  - `SyncKit`: Supabase client wrapper, outbox, conflict policy.
  - `CoachKit` (P2): API client, streaming, safety UI states.
- **App targets:** main app, widget extension (P2).
- **Navigation:** `NavigationStack` per tab. Tabs: Home, Log, Habits, Learn, Profile (Coach appears in Home in P2).
- **Concurrency:** Swift 6 strict concurrency, actors for sync/outbox.

## 4. Data model

Local (SwiftData) mirrors the server (Postgres). All IDs are UUIDv4 generated on the client. Every row has `created_at`, `updated_at` and `deleted_at` (soft delete for sync, hard-purged later).

| Table | Key fields | Notes |
|---|---|---|
| `accounts` | `id` (= auth uid), `role` (teen/parent/adult), `country`, `created_at` | No name required |
| `profiles` | `id`, `owner_account_id`, `nickname`, `birth_date`, `sex_for_charts` (female/male), `mother_height_cm?`, `father_height_cm?`, `parent_heights_source` (measured/reported/unknown), `units`, `is_managed_child`, `coach_enabled` | `sex_for_charts` is explained as "which reference chart to use" |
| `measurements` | `id`, `profile_id`, `measured_at`, `height_cm` (decimal 1 dp), `weight_kg?`, `time_of_day`, `method` (wall/stadiometer/clinic/other), `source` (manual/health), `note?` | Repeated same-day entries are averaged in the UI |
| `habit_logs` | `id`, `profile_id`, `date`, `category` (sleep/activity/nutrition/posture), `value` (json) | **Never read by PredictionKit** |
| `consents` | `id`, `account_id`, `type` (privacy, coach, health, parental), `version`, `granted_at`, `revoked_at?` | Audit trail |
| `coach_messages` (P2) | `id`, `profile_id`, `role`, `content`, `created_at`, `flags` | 30-day TTL (proposal) |
| `coach_memory` (P2) | `profile_id`, `summary`, `updated_at` | User-visible and deletable |
| `entitlements` | `account_id`, `product_id`, `active_until`, `source` | Written only by the webhook |

Predictions are **not stored on the server**. They are recomputed locally from inputs and the bundled reference version, so a reference update changes results consistently and visibly ("Estimate updated: reference data v2").

## 5. Prediction engine (PredictionKit)

### 5.1 Principles
- Four **separate** engines with typed outputs. They are never mixed in hidden ways.
- Every output carries `method`, `inputsUsed`, `eligibility`, `range`, `confidence` and a `limitations[]` string key.
- **The LLM never computes or changes predictions.**
- All formulas come from primary sources, are cited in code comments and the in-app Methods page, and are verified against published worked examples in tests.

### 5.2 Engine A: Reference-based (CDC 2–20 stature-for-age, LMS)
- Inputs: sex, exact age (months), height. Eligible from 2.0 to 20.0 years.
- Compute the current z-score with the LMS method: `z = ((X/M)^L − 1) / (L·S)` (with L≠0), using interpolated L, M, S for the exact age.
- **Percentile-tracking projection:** adult estimate = height at age 20 with the same z: `H = M₂₀ · (1 + L₂₀·S₂₀·z)^(1/L₂₀)`.
- If ≥2 trustworthy measurements exist, use a recency-weighted mean z (from Engine C) to reduce noise.
- **Uncertainty:** percentiles shift around puberty (early/late maturers), so the range widens with distance from adulthood. The width schedule is a parameter to calibrate in Phase 5 from published literature, with a medical reviewer. **No invented numbers ship.** Until it is calibrated, the app shows a qualitative band ("wide / moderate / narrow") instead of numeric widths for this engine.
- Data: CDC `statage.csv` (public domain, U.S. government work), bundled with a SHA-256 checksum. Optional WHO 2007 5–19 reference as a user-selectable alternative (P2).

### 5.3 Mid-parental target height (input to A/B, own card)
- Tanner method: boys `(father + mother + 13 cm) / 2`, girls `(father + mother − 13 cm) / 2`.
- Show it with the commonly cited clinical target range of about ±8.5 cm, and note that it is a population heuristic. Lower the confidence if parent heights are "reported" rather than "measured" (self-reported heights tend to be overestimated).
- Missing parent heights → card shows "not available". The engine still runs without it.

### 5.4 Engine B: Statistical (regression-based)
- Candidate: **Khamis–Roche (1994, *Pediatrics* 94:504–507)**. Inputs: age 4–17.5, sex, height, weight, mid-parental height. No bone age. Published accuracy is reported in secondary sources as roughly ±5 cm at 90% for its study population. **Verify against the primary paper before using it.**
- Caveats to show: derived from a historical, largely white US cohort (Fels Longitudinal Study). Less valid for other populations and for children with growth disorders.
- **Gate:** implement only after (1) coefficients are transcribed from the primary source with two-person verification, (2) licensing/usage terms are confirmed, and (3) test vectors from the paper reproduce. If any of these fail, ship without Engine B (A + mid-parental only).
- Bone-age methods (Bayley–Pinneau, TW3) are **out of scope** (they need an X-ray reading).

### 5.5 Engine C: Personal trend
- Inputs: the measurement series.
- Outputs: velocity (cm/yr) from a robust slope over measurements ≥6 months apart (Phase 1.5), percentile trajectory (z over time), "growth likely complete" detection (no meaningful gain over ≥12 months at a late adolescent age; thresholds set with the reviewer), and a noise score.
- Effect on the prediction: **only** through better z estimates for Engine A (averaging) and the completion detection. It never extrapolates velocity linearly to adulthood.

### 5.6 Engine D: Lifestyle (habits). Never adds cm
- Inputs: sleep, activity, nutrition, posture habits.
- Output: a **habit score and suggestions only**. Its type has no height field, so the type system blocks it from producing cm (`LifestyleReport` has no `cm` property).
- Copy frame: "Healthy habits help you reach your genetic potential. They don't add height beyond it."
- Test: property-based test that predictions are identical for any habit input.

### 5.7 Combining for display
- **Primary card:** ~~Engine B if eligible and enabled, else Engine A.~~ Phase 1.5: Engine A scenario, or the Gate G1 conditional model (see `scientific-prediction-review.md` §6).
- **Overall range:** union of the eligible engine ranges, clamped to plausible adult bounds, plus the mid-parental range shown separately for context.
- **Confidence (low/medium/high):** rules based on age (closer to adult → higher), measurement count/consistency, parent heights known/measured, and engine agreement. No percentage "accuracy" claims.
- Always display: "Estimates can be off by several centimeters. Puberty timing, health and genetics vary."

### 5.8 Safety signposting rules (to be finalized with the medical reviewer)
Candidate triggers, each showing a calm "consider talking to a pediatrician" card with no diagnosis:
1. Current height below the 3rd or above the 97th percentile.
2. Downward crossing of ≥2 major percentile lines over ≥12 months.
3. *(Phase 1.5: not in MVP. Needs a licensed velocity reference.)* Very low velocity for age over ≥12 months (threshold from published pediatric referral guidance, e.g., NICE/AAP; **not invented here**).
4. A large gap between the current percentile and the mid-parental target percentile.
5. Implausible entries → first prompt "re-measure", not a red flag.

### 5.9 Validation plan
- Unit tests for LMS z ↔ height round-trips against the CDC percentile columns in the same file (P3/P50/P97 within 0.1 cm).
- Golden test vectors for mid-parental and Khamis–Roche from primary sources.
- Synthetic longitudinal series for Engine C (noise, spurts, plateaus).
- Invariant tests: lifestyle independence, monotonicity (taller now → not shorter prediction, all else equal), unit conversion round-trips.
- Medical reviewer sign-off on copy and thresholds.

## 6. Backend design (Supabase, proposed)

**Why Supabase:** Postgres + Row Level Security, Auth with Sign in with Apple, Edge Functions for server-only logic, data export with standard SQL, a free tier for early stages and a path to self-hosting. *Alternatives considered:* Firebase (strong, but NoSQL rules are harder to audit for relational family data), CloudKit (free and private, but weak for server logic, the LLM proxy and future web/Android). Re-check pricing and region (EU option for GDPR) in Phase 8.

- **Auth:** Sign in with Apple (required if other social logins exist; we offer it as primary) + optional email magic link. Anonymous local use with no account.
- **RLS:** every table restricted with `owner_account_id = auth.uid()` (profiles joined for child tables). Tests in CI for RLS policies.
- **Edge Functions (TypeScript/Deno):**
  - `coach` (P2): checks JWT, entitlement, age ≥13 and coach consent, applies rate limits, runs the safety pipeline, calls the LLM provider, streams the response, stores minimal logs.
  - `account-delete`: deletes the auth user + cascades all rows + RevenueCat customer alias deletion request. Logs a non-identifying deletion receipt.
  - `account-export`: JSON of all the user's rows.
  - `rc-webhook`: verifies the RevenueCat auth header, upserts `entitlements`.
- **Secrets:** stored in Supabase function secrets. Never in the repo or app. `.env.example` lists names only.
- **Sync:** outbox on the client. `updated_at` last-write-wins per row (single-user data, conflicts are rare). Soft deletes propagate, then are hard-purged after 30 days.
- **Backups:** provider daily backups. The retention policy documents that deleted data persists in backups for up to the provider's backup window.

## 7. API surface

| Endpoint | Method | Auth | Purpose |
|---|---|---|---|
| PostgREST `/rest/v1/profiles`, `/measurements`, `/habit_logs`, `/consents` | CRUD | JWT + RLS | Sync |
| `/functions/v1/coach` (P2) | POST (SSE stream) | JWT + entitlement | Coach message |
| `/functions/v1/coach-memory` (P2) | GET / DELETE | JWT | View/delete memory |
| `/functions/v1/account-export` | GET | JWT | Data export |
| `/functions/v1/account-delete` | POST | JWT + re-auth | Deletion |
| `/functions/v1/rc-webhook` | POST | Shared secret | Entitlements |
| Static content manifest (CDN/Storage) | GET | Public | Article updates without app release (P2) |

## 8. AI architecture (P2)

**Where AI adds value (and where it does not)**

| Use | Value | Guardrail |
|---|---|---|
| Coach Q&A about growth, sleep, nutrition basics, measuring | High | Grounded on our reviewed articles. Scoped topics. Refuses diagnosis/supplements/HGH |
| Plain-language weekly summary of *already computed* stats | Medium | Numbers injected from the engine. The output is checked so that every number matches the input set |
| Reading-level adaptation of articles for teens | Medium | Done offline at content-authoring time, then human-reviewed |
| Habit plan phrasing (rule engine chooses, LLM phrases) | Medium | Rules decide content, the LLM only writes the wording |
| Support triage | Low–medium | No account actions by the AI |
| ❌ Height prediction, diagnosis, body-image analysis, meal-calorie estimation for minors | n/a | **Not built** |

**Safety pipeline (server):**
1. Pre-checks: age ≥13, consent, entitlement, rate limit (per day and per minute).
2. Input classification: crisis/self-harm, eating-disorder signals, medical emergency, sexual content → fixed safe responses with resources (no LLM free text). Uses the provider's safety tooling + our keyword rules.
3. System prompt: role and limits ("not a doctor, never estimates height, never recommends supplements/hormones/procedures, encourages talking to a parent/doctor"), grounding excerpts retrieved from our article set.
4. Output checks: block height numbers that differ from the engine's values, banned-claims regex (HGH, "grow X cm", supplements, specific dosages), length limits.
5. Logging: store messages for at most the TTL. Flagged items kept for safety review with no identifiers beyond the profile UUID.
- **Provider:** Anthropic Claude API is the default proposal. The model ID is held in server config (not hardcoded in the app), with a small, fast model for chat and a larger one only for offline content work. Confirm the provider's data-retention and commercial terms (no training on API data, retention controls) before launch, and name the provider in the privacy policy.
- **Cost control:** per-user daily message caps by tier, prompt caching for the static system prompt + grounding, short context windows, memory summaries instead of full history.

## 9. Design system (our own, "Upward DS")

Original. No competitor colors, layouts, illustrations or copy.

- **Tone:** calm, encouraging, factual. Second person. No hype, no shame. Never "short/tall is bad".
- **Color tokens (semantic, light/dark):** `surface`, `surfaceRaised`, `textPrimary`, `textSecondary`, `accent` (a fresh teal-green "sprout" hue), `accentSoft`, `rangeBand` (translucent accent for prediction ranges), `chartPercentile` (neutral greys P3–P97 with P50 emphasized), `info`, `caution` (amber, used for signposting, **never red** for growth data), `success`. All pairs meet a 4.5:1 contrast ratio.
- **Typography:** SF Pro / SF Rounded for numbers in result cards. Dynamic Type scales up to AX5 tested.
- **Spacing/radius:** 4-pt grid. Radius 12/20. Generous whitespace.
- **Core components:** `RangeCard` (low–high bar with most-likely band), `MethodCard`, `ConfidenceBadge`, `PercentileChart` (Swift Charts with audio graph + data-table alternative), `MeasurementRow`, `HabitChip`, `SignpostCard`, `PrivacyRow`, `PaywallPlanRow`, `EmptyState`.
- **Illustration:** simple, abstract, inclusive (diverse body types). Commissioned or self-made. No stock assets with unclear licenses.
- **Motion:** subtle. Respects Reduce Motion.
- **Icon/brand:** commissioned in Phase 2 after the name search.

## 10. Privacy, security and compliance

| Area | Approach |
|---|---|
| Data minimization | Nickname only, birth date (needed for exact age), heights, optional weight. No location, contacts or photos |
| Tracking | No ATT-requiring SDKs. No ad networks. Privacy label targets "Data Not Linked to You: Diagnostics" + linked data only for sync |
| Analytics | Privacy-first, anonymous event analytics (e.g., TelemetryDeck) or self-hosted. No IDFA. Events have no health values |
| Crash reporting | Xcode Organizer/MetricKit at MVP. A third-party tool only with PII scrubbing |
| Encryption | TLS 1.2+. Encryption at rest (provider). iOS Data Protection `complete` for local store |
| Account deletion | In-app (Guideline 5.1.1(v)). Server purge. Subscription-cancel guidance shown (Apple manages billing) |
| Export | JSON/CSV in-app |
| Children | Under-13 only via parent account (COPPA VPC via the parent's adult account + consent record). Kids Category **not** targeted (it restricts analytics/links). Age rating chosen honestly in App Store Connect |
| GDPR/UK | Lawful basis: consent for health data (special category). DPA with processors. EU region if launching in the EU. UK AADC defaults |
| HealthKit | Read/write only the types we use. Never used for ads. Disclosed in the privacy policy (Guideline 5.1.3) |
| Medical claims | Guideline 1.4.1: methods disclosed in-app, "consult a doctor" reminders, no diagnostic claims |
| Payments | StoreKit only. Clear terms. Restore button. Ask to Buy handled by Apple |
| Secrets | None in the client. Secret scanning in CI. `.env` gitignored |
| Security testing | RLS tests, dependency audit, OWASP MASVS-lite checklist before launch |

## 11. Testing and CI (planned for Phase 3)

- GitHub Actions on macOS runners (or Xcode Cloud free hours): build, SwiftLint/SwiftFormat, unit tests (PredictionKit ≥95% coverage), snapshot tests for DesignSystem, UI tests for onboarding → result.
- Backend: Supabase CLI local stack. pgTAP/SQL tests for RLS. Deno tests for edge functions.
- Release: TestFlight internal → external beta.

## 12. Cost profile (qualitative. Verify current pricing in Phase 8)

| Service | Early stage | Scales with |
|---|---|---|
| Apple Developer Program | Annual fee | — |
| Supabase | Free tier → paid tier at launch for backups/no pausing | DB size, MAU |
| RevenueCat | Free below a revenue threshold, then % of revenue | Revenue |
| LLM API | Pay per token | Coach messages (capped per user) |
| Analytics | Free tier | Events |
| Medical + legal review | One-off consulting | — |

No specific dollar figures are given here because vendor prices change. Phase 8 records current quotes.
