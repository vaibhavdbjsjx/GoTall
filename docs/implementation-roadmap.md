# Implementation Roadmap (15 Phases)

> Phase 1 deliverable. Each phase ends with a **stop-and-review gate**: the owner approves before the next phase starts. Durations are not estimated here because they depend on the owner's availability. Dependencies define order.
> References: PRD = `product-requirements.md`, TA = `technical-architecture.md`, MON = `monetization.md`, CR = `competitor-research.md`.

## Phase map

| # | Phase | Depends on | Output |
|---|---|---|---|
| 1 | Research & architecture | — | 5 docs (this set) ✅ |
| 2 | Brand, UX & design system | 1 | Name, wireframes, DS spec, prototype |
| 3 | Project foundation & CI | 2 | Xcode project, packages, CI, lint |
| 4 | Data model & local persistence | 3 | SwiftData models, repositories, profiles |
| 5 | Prediction engine (PredictionKit) | 3 (+ medical reviewer engaged) | Tested engines A, C, D, mid-parental (B gated) |
| 6 | Onboarding, age gate & measurement logging | 4, 5 | First-run flow to free result |
| 7 | Results, charts & safety signposting | 5, 6 | Result + chart + signposting screens |
| 8 | Backend, auth & sync | 4 | Supabase schema/RLS, Sign in with Apple, sync |
| 9 | Habits & Learn content | 4, 7 | Habit tracker, article system |
| 10 | Monetization & paywall | 7, 8 | StoreKit/RevenueCat, entitlements, paywall |
| 11 | AI Coach | 8, 9, 10 | Server proxy, safety pipeline, chat UI |
| 12 | Notifications, widgets & HealthKit | 6, 9 | Reminders, widget, Health sync |
| 13 | Family mode & clinician export | 8, 10 | Multi-child dashboard, PDF export |
| 14 | Privacy, security, compliance & analytics hardening | 8–13 | Audits, policies, deletion/export verified |
| 15 | Beta, ASO & launch | 14 | TestFlight beta, store listing, release |

MVP launch = Phases 1–10 + 12 (reminders only) + 13 (basic multi-profile, which is built in Phases 4/6) + 14 + 15. The AI Coach (11), Health/widgets (rest of 12) and the full family dashboard + clinician export (rest of 13) are P2 and ship as post-launch updates. This matches PRD §4. Phases are numbered by dependency, not release order, so P2 phases may be built after the v1.0 launch in Phase 15.

---

### Phase 1: Research & architecture ✅
- **Objective:** understand the competitor, define the product, architecture, monetization and plan.
- **Dependencies:** none.
- **Modules:** docs only.
- **Backend:** design only (TA §6).
- **APIs:** design only (TA §7).
- **Risks:** competitor data could not be fetched directly (network policy). Mitigated by tagging confidence and a manual checklist (CR §7).
- **Testing:** cross-document consistency review.
- **DoD:** 5 docs committed. Owner reviews the execution report and approves Phase 2.

### Phase 2: Brand, UX & design system
- **Objective:** original brand and UX that express "honest & calm".
- **Dependencies:** 1. Owner decisions on name/markets (PRD §11).
- **Modules:** `DesignSystem` spec (tokens, components from TA §9), wireframes for all MVP flows (PRD §5), clickable prototype (Figma or SwiftUI previews), app icon brief.
- **Backend:** none.
- **APIs:** none.
- **Risks:** name/trademark conflicts. Look-alike with the competitor (avoid). Accessibility gaps.
- **Testing:** 5-user hallway tests (adults/parents. Teens only with parental consent) on the prototype. Contrast checks.
- **DoD:** name cleared (USPTO/EUIPO search + App Store search), DS tokens defined, all MVP screens wireframed, manual competitor checklist (CR §7) done, owner sign-off.

### Phase 3: Project foundation & CI
- **Objective:** a buildable skeleton with quality gates.
- **Dependencies:** 2.
- **Modules:** Xcode project (iOS 17+, Swift 6), local packages (`PredictionKit`, `ReferenceData`, `DesignSystem`, `Persistence`, `SyncKit`), tab shell, SwiftLint/SwiftFormat, `.gitignore`, `.env.example` (names only), README dev setup.
- **Backend:** Supabase project created (no schema yet). Secrets stored only in the provider dashboard.
- **APIs:** none.
- **Risks:** macOS CI minutes cost. Signing setup.
- **Testing:** CI runs build + unit tests + lint on every PR. Secret scanning on.
- **DoD:** green CI on `main`, app launches to the tab shell on simulator and device, no secrets in the repo.

### Phase 4: Data model & local persistence
- **Objective:** local-first storage for accounts, profiles, measurements, habits, consents.
- **Dependencies:** 3.
- **Modules:** SwiftData models (TA §4), repository protocols + in-memory fakes, migrations plan, unit conversion utilities, plausibility validators (FR-4).
- **Backend:** schema SQL drafted to mirror local models (applied in Phase 8).
- **APIs:** none.
- **Risks:** SwiftData migration pain. Mitigated by versioned schemas from day 1.
- **Testing:** repository unit tests, migration tests, conversion round-trips.
- **DoD:** CRUD for all entities with tests. Multiple profiles supported in the model. Data Protection set to `complete`.

### Phase 5: Prediction engine (PredictionKit)
- **Objective:** deterministic, tested, cited prediction engines.
- **Dependencies:** 3. Medical reviewer engaged (thresholds/copy).
- **Modules:** LMS loader + interpolation, Engine A, mid-parental, Engine C (velocity, trajectory, completion), Engine D (habit score, no cm), combiner + confidence, signposting rules, Engine B **behind a feature flag** pending the TA §5.4 gate.
- **Backend:** none (on-device).
- **APIs:** internal Swift API only.
- **Risks:** transcription errors in coefficients. Overconfident ranges. Population bias. Mitigated by two-person verification, golden vectors, qualitative bands until calibrated, and stated limitations.
- **Testing:** TA §5.9 suite, ≥95% coverage, property test for lifestyle independence.
- **DoD:** all tests green, reviewer signs off thresholds/copy, Methods page text drafted with citations, Engine B decision recorded (ship/defer).

### Phase 6: Onboarding, age gate & measurement logging
- **Objective:** ≤12 required steps to a free result. Accurate logging.
- **Dependencies:** 4, 5.
- **Modules:** role selection, age gate (under-13 → parent flow), consent screens (versioned), inputs with guide, measurement guide, log list/edit, averaging of repeats.
- **Backend:** none (local). Consents synced later.
- **APIs:** none.
- **Risks:** drop-off. Age-gate circumvention (accept self-declaration, design neutral age gate per FTC guidance).
- **Testing:** UI tests for teen/parent/adult paths, accessibility audit (VoiceOver, AX sizes), copy review.
- **DoD:** new user reaches the result offline in ≤12 required steps. Under-13 cannot self-onboard. Consent records stored.

### Phase 7: Results, charts & safety signposting
- **Objective:** the core "aha" screens.
- **Dependencies:** 5, 6.
- **Modules:** `RangeCard`, `MethodCard`, `ConfidenceBadge`, Methods sheet, `PercentileChart` (with audio graph + table), velocity card, `SignpostCard`, share card (range only).
- **Backend:** none.
- **APIs:** none.
- **Risks:** users read the range as a promise. Mitigated by copy testing and disclaimers (PRD §8).
- **Testing:** snapshot tests (light/dark/AX sizes), UI tests, reviewer copy sign-off.
- **DoD:** all PRD MVP result requirements met (FR-1, 2, 3, 5, 6). Signposting triggers verified with synthetic data.

### Phase 8: Backend, auth & sync
- **Objective:** optional account, backup/sync, server-side deletion and export.
- **Dependencies:** 4.
- **Modules:** `SyncKit` (outbox, LWW, soft deletes), Sign in with Apple, account screens.
- **Backend:** apply schema, RLS policies, `account-delete`, `account-export` functions, backups, region choice. Record current vendor pricing (TA §12).
- **APIs:** PostgREST tables, export/delete functions (TA §7).
- **Risks:** RLS mistakes leaking data. Sync conflicts. Mitigated by RLS tests in CI and a two-device sync test matrix.
- **Testing:** pgTAP RLS tests (user A cannot read B), Deno function tests, offline→online sync tests, deletion end-to-end.
- **DoD:** sign in/out works, data syncs across 2 devices, deletion purges server rows, export returns the full dataset, no service key in the app.

### Phase 9: Habits & Learn content
- **Objective:** daily engagement without height-gain claims.
- **Dependencies:** 4, 7.
- **Modules:** habit categories + check-in, forgiving streaks, weekly summary (non-AI), article renderer (Markdown bundle), 5–10 cited articles, myth-busting.
- **Backend:** habit_logs sync. Optional remote content manifest (P2).
- **APIs:** PostgREST `habit_logs`.
- **Risks:** content accuracy. ED-risk nutrition copy. Mitigated by medical review and no calories for minors.
- **Testing:** unit tests for streak logic, reviewer sign-off on all articles, FR-2 regression.
- **DoD:** habits logged/synced, articles reviewed and cited, zero "adds cm" claims (copy lint list).

### Phase 10: Monetization & paywall
- **Objective:** honest Premium subscription.
- **Dependencies:** 7, 8.
- **Modules:** StoreKit products, RevenueCat SDK, entitlement service, paywall (MON §4), restore, trial reminder, feature gates (MON §2).
- **Backend:** `rc-webhook` → `entitlements`.
- **APIs:** webhook endpoint.
- **Risks:** rejection under Guideline 3.1.2. Gate bugs locking free features. Mitigated by a disclosure checklist and tests that safety/prediction are always free.
- **Testing:** StoreKit config file tests, sandbox purchases, webhook tests, UI tests for each gate.
- **DoD:** purchase/restore/cancel flows work in sandbox, prices set per storefront (decision recorded), paywall passes the dark-pattern checklist.

### Phase 11: AI Coach (P2)
- **Objective:** a safe, useful coach for 13+.
- **Dependencies:** 8, 9, 10.
- **Modules:** `CoachKit`, chat UI (streaming), memory viewer/delete, consent screen, safety states.
- **Backend:** `coach` function (TA §8 pipeline), rate limits, grounding retrieval over articles, message TTL job, provider key in secrets.
- **APIs:** `/coach` (SSE), `/coach-memory`.
- **Risks:** harmful/medical advice, prompt injection, cost overrun, minors' data. Mitigated by the safety pipeline, red-team set, caps and data-retention terms.
- **Testing:** red-team evaluation set (≥200 prompts: crisis, ED, supplements, HGH, diagnosis, jailbreaks, sexual content), with a pass threshold of 100% on critical categories. Load/cost test.
- **DoD:** safety eval passes, reviewer approves the system prompt, under-13 blocked server-side, provider named in the privacy policy.

### Phase 12: Notifications, widgets & HealthKit
- **Objective:** retention and native integration.
- **Dependencies:** 6, 9.
- **Modules:** local notifications (monthly measure, habits, trial reminder) with quiet hours. Widget extension (P2). HealthKit read/write height, read sleep/steps (P2).
- **Backend:** none (local notifications only, no push server at MVP).
- **APIs:** HealthKit, WidgetKit, UserNotifications.
- **Risks:** notification fatigue. HealthKit review (5.1.3).
- **Testing:** scheduling unit tests, device tests, Health permission denial paths.
- **DoD:** reminders reliable across time zones. Health data never leaves the device except user-initiated sync, as disclosed.

### Phase 13: Family mode & clinician export
- **Objective:** parent value (the buyer persona).
- **Dependencies:** 8, 10.
- **Modules:** family dashboard, child profile management and per-child controls (coach/sharing), PDF export (chart + measurements + methods + disclaimer).
- **Backend:** profile ownership via RLS (already in Phase 8). No sharing between accounts at MVP.
- **APIs:** none new (PDF rendered on device).
- **Risks:** exported PDF read as a diagnosis. Mitigated by clear framing and reviewer approval.
- **Testing:** multi-profile UI tests, PDF snapshot tests.
- **DoD:** a parent manages ≥3 children. PDF export is reviewed and accessible.

### Phase 14: Privacy, security, compliance & analytics hardening
- **Objective:** launch-ready trust posture.
- **Dependencies:** 8–13.
- **Modules:** privacy center, privacy-first analytics events (no health values), crash reporting, final disclaimers.
- **Backend:** retention jobs, backup policy docs, DPA with processors, EU region decision.
- **APIs:** none new.
- **Risks:** missed legal requirement. Mitigated by legal review of the privacy policy/ToS (COPPA, GDPR/AADC, CCPA), and a MASVS-lite checklist.
- **Testing:** security review, RLS penetration tests, deletion/export audit, App Privacy label vs actual network traffic (proxy inspection).
- **DoD:** policies published at stable URLs, privacy label accurate, all checklists signed off, no third-party trackers in the binary.

### Phase 15: Beta, ASO & launch
- **Objective:** ship v1.0.
- **Dependencies:** 14.
- **Modules:** TestFlight beta (adults/parents first. Teens only via parents), feedback loop, store screenshots (original), description (no medical claims), keywords, review notes explaining methods (Guideline 1.4.1).
- **Backend:** production scale tier, monitoring/alerts.
- **APIs:** none new.
- **Risks:** App Review rejection (health claims, subscriptions, kids). Mitigated by a pre-submission checklist and detailed reviewer notes with method citations.
- **Testing:** full regression, beta crash-free ≥99.5%, accessibility pass.
- **DoD:** approved and live in launch markets. Monitoring in place. Post-launch metrics dashboard (PRD §10).

---

## Cross-cutting risks

| Risk | Phase(s) | Mitigation |
|---|---|---|
| Medical inaccuracy / harmful copy | 5, 7, 9, 11 | Paid medical reviewer, cited sources, signposting |
| Store rejection (1.4.1, 3.1.2, 5.1.x) | 10, 14, 15 | Checklists, methods disclosure, reviewer notes |
| Children's privacy law | 6, 8, 14 | Parent-managed under-13, consent records, legal review |
| Solo-dev bandwidth | all | Strict MVP scope, P2 items deferrable |
| Competitor/clone copying | 2, 15 | Trust brand, family + export features are harder to copy |
