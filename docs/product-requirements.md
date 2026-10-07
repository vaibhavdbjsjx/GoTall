# Product Requirements Document (PRD)

> Phase 1 deliverable. Working title: **"Upward"** (placeholder. A trademark and App Store name search is required in Phase 2. We will not use "Tall"/"GoTall" in the name to avoid confusion with the competitor and its clones).
> Platform: iOS (iPhone first, iPad compatible). Companion docs: `competitor-research.md`, `technical-architecture.md`, `monetization.md`, `implementation-roadmap.md`.
> **Phase 1.5 update:** scope is locked in `mvp-scope.md`, which overrides §4 where they differ. Key changes: US storefront only, no weight, no Engine B, velocity needs ≥6-month intervals, clinician PDF + multi-profile are **MVP Premium**, AI coach is P1, local-first with no accounts in MVP (FR-8 becomes "delete all data", covering local + iCloud), ethnicity is never collected, 21+ get no prediction.

## 1. Vision

The most **honest and useful** height-growth companion for teens and parents. It gives a free, transparent adult-height estimate *with its uncertainty*, tracks real growth against CDC/WHO references, and builds healthy habits **without ever promising extra centimeters**.

**Product principles**
1. **Honest by design:** ranges, not single numbers. Methods visible. Limits stated.
2. **Value before paywall:** the prediction is free.
3. **Safe for minors:** no body photos, no calorie counting for under-18s, no DMs, parent controls.
4. **Private by default:** local-first, no cross-app tracking, deletion in two taps.
5. **Not medical:** education and tracking, with clear "see a doctor" signposting.

## 2. Target users

| Persona | Age | Need | Pays? |
|---|---|---|---|
| **Teen tracker (primary user)** | 13–17 | "How tall will I be? Am I still growing? What can I do?" | Sometimes (via Apple Family / Ask to Buy) |
| **Parent (primary buyer)** | 30–55 | "Is my child growing normally? Track siblings, show the doctor." | Yes |
| **Young adult (18–21)** | 18–21 | "Have I stopped growing? Posture and health habits." | Yes |
| **Under-13 child** | <13 | Only through a parent-managed profile. Never has their own account | Parent pays |

**Out of scope:** clinicians as users (we may export *to* them), height-increase surgery or supplements, adults >21 looking for growth (we explain that growth plates have closed for most adults; posture content only).

## 3. Problems and jobs to be done

1. *Predict:* "Give me a credible estimate of my adult height."
2. *Track:* "Show whether I'm growing and how fast compared to others my age."
3. *Act:* "Tell me what healthy habits support my *genetic potential* (sleep, nutrition, activity), without lies."
4. *Reassure / escalate:* "Tell me when something is worth asking a doctor about."
5. *Family:* "Let me manage this for my kids in one place."

## 4. Scope

### 4.1 MVP (launch)

| Area | Requirement |
|---|---|
| Onboarding | ≤12 required steps to a free result: role (teen / parent / 18+), age gate, sex at birth (for reference charts, explained), birthdate, current height (+ guide), parents' heights (optional "don't know"), units |
| Age gate & consent | Self-declared birthdate. Under 13 → must be set up by a parent (parent account flow). 13–17 → teen flow with privacy explainer and optional parent link. No AI coach under 13 |
| Prediction | Engine A (reference/percentile projection) + mid-parental target, plus Engine B only if it passes the verification gate (Tech Arch §5.4) and inputs allow, shown as a **range**, with a "How we estimate" sheet. Engine D lifestyle **never changes cm** |
| Results screen | Range, most-likely band, method cards, confidence level (low/medium/high based on inputs), disclaimers, share card (range only) |
| Measurement log | Add/edit/delete measurements. Time-of-day note. Averaging of repeated entries |
| Charts | CDC 2–20 stature-for-age percentile chart (P3–P97 lines), user's points, current percentile |
| Velocity | cm/yr from ≥2 measurements ≥6 months apart (Phase 1.5). "Too noisy" state otherwise |
| Safety signposting | Red-flag rules (Tech Arch §5.6) → neutral "consider talking to a pediatrician" card |
| Habits | 4 categories (sleep, activity, nutrition, posture), daily check-in, forgiving streak |
| Content | 5–10 short cited articles (how growth works, growth plates, sleep, nutrition basics, measuring correctly, myths) |
| Profiles | Parent account with multiple child profiles. Teen single profile |
| Account | Works without an account (local). Sign in with Apple to back up and sync. Email sign-in optional |
| Privacy | In-app data export (JSON/CSV) and account + data deletion. Privacy center screen |
| Monetization | Free tier + Premium subscription (see `monetization.md`). Honest paywall, restore purchases |
| Notifications | Monthly measurement reminder, optional daily habit reminder, quiet hours |
| Units / locale | cm and ft/in. English |
| Accessibility | Dynamic Type, VoiceOver labels on charts (audio graph / data table), contrast AA, Reduce Motion |

### 4.2 P2 (fast follow)
AI Coach (13+, opt-in, server-side, safety-scoped). Clinician PDF export. Apple Health read/write. Widgets. Puberty-timing self-check (non-intimate). Exercise/posture routines. Sleep/activity logs. Referral program. Weekly review. Localization (5 languages). Full family dashboard.

### 4.3 P3 (validate first)
Food-group camera for adults/parents. Curated challenges (no open UGC). Web app. AR measuring assist (only with validation). Apple Watch. Android (would need a separate client; see Tech Arch §2).

### 4.4 Explicit non-goals
- Claims that any habit, exercise, food or supplement increases adult height.
- Bone-age estimation from photos/X-rays, or any diagnosis.
- Body or genital photos, Tanner-stage imagery.
- Calorie counting, weight-loss goals or BMI shaming for minors.
- Open chat, DMs or public profiles for minors.
- Selling or sharing health data for advertising.

## 5. Key user flows

1. **First run (teen):** Welcome → "Who's using this?" → birthdate (age gate) → sex for charts (with explanation) → height (guide link) → parents' heights (optional) → units → notifications ask (in context, later) → **free result** → soft premium offer (dismissible) → home.
2. **First run (parent):** Welcome → parent → create child profile(s) → same inputs per child → result per child → family home.
3. **Monthly measure:** reminder → guide → enter (or 3 entries averaged) → chart + velocity update → updated range (only if inputs changed meaningfully, with changes explained).
4. **Red flag:** rule triggers → calm info card with what it means, and that measurement error is common → "re-measure" or "talk to a doctor", plus a PDF export link (P2).
5. **Delete:** Settings → Privacy center → Delete account & data → confirm → server purge + local wipe → confirmation.

## 6. Functional requirements (selected, testable)

- FR-1: The prediction is shown as `[low, high]` cm with a most-likely band. Never as a lone integer.
- FR-2: Changing lifestyle/habit data **must not** change any predicted cm value (automated test).
- FR-3: If parents' heights are missing, the mid-parental card shows "not available" and confidence drops a level.
- FR-4: Inputs outside plausible bounds (height < P0.1 or > P99.9 for age/sex, or a change > a set threshold between entries) prompt "please double-check" before saving.
- FR-5: For age ≥ 18 (female) / ≥ 19 (male) with no growth over 12 months, the result says growth is likely complete and shows the current height as the expected adult height. *(Exact thresholds to be set with a medical reviewer in Phase 5.)*
- FR-6: Every prediction screen links to "How we estimate" (methods, sources, error ranges, limitations).
- FR-7: Under-13 profiles cannot access the AI coach, sharing or referrals.
- FR-8: Account deletion removes server data within 30 days (target: immediately for primary stores; backups per retention policy) and is available in-app.
- FR-9: The app runs fully offline for prediction, logging and charts.

## 7. Non-functional requirements

| Category | Requirement |
|---|---|
| Performance | Cold start < 1.5 s on a recent device. Prediction compute < 50 ms locally |
| Reliability | Crash-free sessions ≥ 99.5% |
| Privacy | No third-party ad/tracking SDKs. Data minimization. Encryption in transit and at rest |
| Security | No secrets in the app binary. Server-side LLM and receipt validation. RLS on all user tables |
| Accessibility | WCAG 2.2 AA equivalent |
| Compliance | App Store Guidelines (1.4.1, 1.3 Kids if applicable, 3.1.x, 5.1.x), COPPA, GDPR/UK GDPR incl. Age Appropriate Design Code, CCPA/CPRA (see Tech Arch §10) |

## 8. Medical, safety and compliance requirements

1. **Disclaimer:** "Upward provides estimates for education. It is not a medical device and doesn't diagnose. Talk to a doctor about growth concerns." Shown at onboarding and on the methods page; short version on results.
2. **Medical review:** a licensed pediatric clinician (paid consultant) reviews content, red-flag rules and copy before launch. Budget item. **Not optional.**
3. **Regulatory posture:** stay a general-wellness/education product. Avoid diagnostic intended use. Re-check FDA general-wellness and clinical-decision-support guidance and EU MDR software rules before launch. Get legal advice if features move toward diagnosis.
4. **Minors:** age gate. Under 13 only parent-managed (COPPA verifiable parental consent through the parent account). Teen-safe defaults (UK AADC): high privacy, no geolocation, no public sharing defaults.
5. **Body image and mental health:** no "short" shaming language. Neutral percentile copy. Content on height diversity. Resources link if a user expresses distress in the coach.
6. **AI:** disclosed as AI. Not a predictor. Not a doctor. Crisis/self-harm keyword handling with resources. Logs minimized (Tech Arch §8).
7. **UGC:** none in MVP. Any future UGC requires filtering, reporting, blocking and published moderation contact (Guideline 1.2).
8. **Ads:** none.

## 9. Differentiators (prioritized)

| # | Differentiator | Why it wins | Phase |
|---|---|---|---|
| 1 | **Free prediction, no bait-and-switch** | Removes the competitor's #1 complaint | MVP |
| 2 | **Honest ranges + visible methods & sources** | Trust. Passes Guideline 1.4.1 | MVP |
| 3 | **Real CDC percentile charts + velocity** | Actually useful. Retention through monthly measuring | MVP |
| 4 | **Parent / family mode** | Parents are the buyers. Under-13 compliance | MVP basic / P2 full |
| 5 | **Medical signposting ("worth asking a doctor")** | Real safety value. Earns parent trust | MVP |
| 6 | **Privacy-first: no tracking, local-first, 2-tap deletion** | Contrast with competitor's tracking label | MVP |
| 7 | **No dark patterns** (no fake timers, clear trials, renewal reminders) | Reviews, refunds, regulator-proof | MVP |
| 8 | **Measurement coach** (guide, averaging, outlier checks) | Better data → better estimates | MVP |
| 9 | **Clinician PDF export** | Unique utility for pediatric visits | P2 |
| 10 | **Apple-native polish** (Health, widgets, accessibility) | Premium feel, App Store featuring potential | P2 |
| 11 | **Safety-scoped AI coach grounded on reviewed content** | Value without hallucinated medical advice | P2 |
| 12 | **Teen-safe nutrition (food groups, no calories)** | Avoids ED risk, appeals to parents | P2 |

## 10. Success metrics (targets to be set after beta; no baseline exists)

- Activation: % of installs reaching a result. Time to result.
- Retention: D1/D7/D30. % logging a second measurement within 45 days.
- Monetization: trial start rate, trial→paid, refund rate, ARPU (see `monetization.md`).
- Trust: rating ≥ 4.6 with reviews not mentioning "scam/paywall". Support tickets per 1K users.
- Safety: red-flag card views → export/doctor-tap rate. Zero safety incidents in coach audits.

## 11. Open questions (owner decisions)

1. Final name and brand (Phase 2).
2. Budget for a medical reviewer and legal review (strongly recommended before launch).
3. Launch markets (affects GDPR/AADC scope and localization).
4. Whether to offer lifetime purchase at launch (see `monetization.md`).
