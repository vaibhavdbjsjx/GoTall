# Phase 4: Premium UX, Retention Loop and Polish

## 1. UI audit (before Phase 4, from the Phase 3 simulator screenshots)

**Top 10 problems**
1. Home was a stack of equal-weight cards; no hero and no answer to "how am I doing?".
2. No daily reason to return: Habits was a placeholder.
3. Percentile was only text; nothing made the position intuitive.
4. Growth was one long, uniform scroll of similar cards.
5. The chart was static and the selected-point block looked like a form.
6. Adding a measurement was a single dense form with no feedback afterwards.
7. Profile was a plain settings list, with no export, appearance or reminder choices.
8. The profile switcher was a bare menu without age, height or status.
9. The onboarding summary was a data dump that cut abruptly to Home.
10. Icons and badges were overused; warm colour appeared without meaning.

**Top 10 opportunities**
1. A signature, on-brand visual (door-frame height marks) for percentile position.
2. A chart preview on Home that links to Growth.
3. Check-ins on Home so the daily action takes one tap.
4. Weekly consistency with a forgiving rhythm instead of a fragile streak.
5. A stepped measurement flow with an honest success state.
6. A deterministic next-action engine.
7. A profile-switcher sheet with real summaries.
8. A Profile hub with export, appearance and reminder preferences.
9. A short reveal sequence into Home built from real facts.
10. Screenshot coverage of every new flow on small, standard and large phones.

## 2. Design changes

- **Kept the Spruce palette** (it tested well in light and dark). It evolved with a *hero surface* (very soft accent tint from the top-leading corner, used at most once per screen), quieter information rows (`QuietNote`) for secondary context, and warm colour reserved for insights only.
- **Signature visual: `DoorFrameRuler`.** A vertical ruler with the CDC percentile lines (3rd at the bottom, 97th at the top), the 25th–75th band shaded, and a marker for the current position. It shows position, not progress: nothing fills up or levels up. Hidden at accessibility text sizes, where the percentile is shown as text instead.
- New components:
  - `WeekDots` (partially filled rings; full days get a check; never red)
  - `ConsistencyGrid` (28-day intensity; empty days neutral grey)
  - `IntervalRing` (time since the last measurement against the suggested interval)
  - `CheckInRow` (large tappable row, success haptic, symbol bounce)
  - `SuccessSeal`
  - `AdaptiveStack` and `hiddenAtAccessibilitySizes()` (Phase 3 refinement)

## 3. Screens

- **Home:**
  - Header (greeting, profile switcher).
  - Hero: height, the percentile ruler, and a **data-justified status** (`GrowthStatus`). "Growing steadily" appears only with increasing speed *and* a steady percentile path; otherwise "Growing", "Little change recently", "Worth re-measuring", "Building your growth history" or "Adult height".
  - Estimate card with a "Why?" link to the explanation.
  - Trajectory preview that opens Growth.
  - **Today**: encouragement, week dots, inline check-ins, and the measurement-interval ring.
  - One insight.
  - **One next action** (`NextActionEngine`). Priority: measurement due, then today's check-in, then add family height, then informational next-measurement date, then review growth.
- **Growth:** hero with status and ruler; chart whose own line draws on point by point (reference curves don't animate; instant under Reduce Motion); a tinted selected-point card; an "Understanding the numbers" section (speed, estimate, family range) with explanations behind sheets and disclosures; history; guide.
- **Habits:** Today (x/y done, check-ins, choose habits), This week (week dots, "4 of 7 days", rhythm with its definition), Last four weeks (grid), Patterns (most consistent habit once there are at least 5 check-in days), Starting points.
- **Measurement flow:** height → method → date (graphical) → review (edit any step, warnings shown) → success. The success screen celebrates **better data**: "Growth speed is now available", "Your trend has started", "Measurement saved… consistent measuring makes the picture clearer". It never mentions centimetres gained.
- **Profile hub:**
  - Header card (avatar, name, age, height, status, Edit).
  - Profiles (switch or add).
  - Growth (measurements, family and details, reference).
  - Preferences (unit, appearance, reminders).
  - Privacy (export JSON, delete all).
  - Coming later (planned premium items, clearly labelled).
  - About.
- **Profile switcher:** a sheet of cards (avatar, name, age, height, status), with the active one highlighted and "Add a child".
- **Onboarding reveal:** after "Start tracking", lines appear one by one, each a fact from the profile just built ("Maya's profile is set up", "Growth chart: CDC, female, ages 2–20", "Current position: 48th percentile", "Your home screen is ready"). Under 2 seconds in total; instant under Reduce Motion. No "calculating" claims.

## 4. Retention loop and streak philosophy

**Loop:** open the app → see the hero (position and status) → one insight → one small action (check-in, or a measurement when due) → come back tomorrow for check-ins and every few months for a measurement. **Height is never requested daily**: daily engagement comes from habits only.

**Definitions** (shown in the UI wherever a number appears):
- *Check-in day:* a day with at least one habit done.
- *This week:* the last 7 days including today, e.g. "4 of 7 days".
- *Rhythm:* check-in days in the current run. One missed day in any 7 is forgiven, and today isn't counted as missed until it's over. Two misses within 7 days simply start a new run. **Nothing is "broken"**, and there is no red state or loss message.
- After a break the message is **"You're back. Continue from today."**
- A full week shows "A full week of check-ins." That's subtle; there are no confetti, XP or badges.
- There is **no "growth score" or "health score"**. Every number has a definition.
- Habits are yes/no self-reports (no calories, weight or numeric targets for minors) and **never affect any height number** (tested).

## 5. Notification architecture (design only, nothing delivered yet)

- `NotificationPreferences` are saved per device and every category is opt-in:
  - measurement reminders (one-off, at 10:00 on the suggested date, or tomorrow if already due)
  - daily check-in at a chosen time (repeating)
  - weekly summary (Sunday 18:00)
- `NotificationPlanner` turns preferences and profiles into a plan. It's unit-tested, including a check that copy contains no fear or guilt words ("losing", "streak", "hurry"…).
- The reminders screen says honestly that choices are saved and delivery starts in a later update, after iOS asks for permission.
- Phase 5: hand the plan to `UNUserNotificationCenter`, request permission in context (never at launch), and reschedule on data changes.

## 6. Premium / free boundary (design; no billing)

| Free (always) | Premium candidates (later) |
|---|---|
| Growth profile, CDC percentile, growth chart, adult-height estimate and its explanation, family range, unlimited measurement history, basic habits and consistency, export and delete | Doctor-ready report, advanced insights, family plan (multiple profiles, currently unlocked via `DevelopmentEntitlements`), advanced habit analytics, AI coach, Apple Health integration |

The Profile tab shows the premium items as "Planned", with the line "Your growth profile, chart, estimate and history stay free." There's no paywall and no locked core result.

## 7. Rejected or deferred (and why)

- **XP, badges, levels:** imply height is a game; also GoTall's pattern. Rejected.
- **A daily height measurement prompt:** daily measuring is noise and anxiety. Rejected.
- **A "growth score":** not scientifically meaningful. Rejected.
- **Pinch-zoom chart:** the range toggle is clearer and accessible. Deferred.
- **Notification delivery:** deferred to Phase 5 by design.
