# Phase 2: Product Foundation

> What was built in Phase 2, the decisions behind it, and what is verified. Working title: **Arcwise** (placeholder, set in `BrandConfig`; not a final name).

## 1. Repository layout

```
Package.swift                 SwiftPM package (GrowthCore always; DesignSystem + AppFeatures on Apple platforms)
Sources/GrowthCore/           Platform-independent logic: models, units, age policy, onboarding engine,
                              persistence, dashboard/summary builders, copy, entitlement + estimate boundaries
Sources/DesignSystem/         SwiftUI tokens, motion and reusable components (iOS)
Sources/AppFeatures/          SwiftUI screens: root, onboarding steps, Home, Growth, Habits, Profile (iOS)
Tests/GrowthCoreTests/        83 XCTest cases (run on Linux and macOS)
App/project.yml               XcodeGen spec for the iOS app target
App/Sources/GrowthApp.swift   @main entry point
.github/workflows/ci.yml      Linux core tests + macOS Xcode build
```

**Rule:** all logic and state live in `GrowthCore` (Swift 6 strict concurrency, no UI imports). Views are thin. Scientific calculations (Phase 5) will live in their own module, separate from UI and from any AI code.

## 2. Design system ("Spruce")

| Token group | Decision |
|---|---|
| Primary | Spruce green-teal, `#09705F` light / `#45C7AC` dark. Calm and confident; not medical blue, not fitness neon |
| Secondary | Warm clay `#A84F25` / `#F0A46E`, used only for insights and highlights |
| Caution | Amber, never red, for growth data. Red is reserved for destructive actions |
| Backgrounds | Warm paper `#F6F5F1` light. Deep graphite `#0D1012` dark (not pure black) |
| Surfaces | White / `#161A1D`. Secondary `#EEECE6` / `#1F2427` |
| Text | Three levels; every pair measured ≥ 4.5:1 (WCAG AA) on every surface, both modes |
| Dark mode | Designed separately: brighter accent, dark text on accent buttons, no shadows (hairlines and lighter surfaces instead) |
| Typography | SF Pro on Dynamic Type text styles (scales to accessibility sizes); SF Rounded with monospaced digits for numbers |
| Spacing | 4-pt grid (4…40), 20-pt page margin |
| Radius | 10 / 14 / 20 / 28, continuous corners |
| Elevation | Light: soft 5% shadow + hairline. Dark: hairline only |
| Tap targets | ≥ 44 pt everywhere |

Components: `AppButton` (primary/secondary/tertiary/destructive, loading), `AppCard`, `SectionHeader`, `MetricCard`, `MeasurementRow`, `Badge`, `SelectionCard`, `SelectableChip`, `MultiSelectCard`, `SegmentedChoice`, `FlowLayout`, `HeightInput`, `UnitToggle`, `DateInput`, `TimeInput`, `ChapterProgressView`, `OnboardingContainer`, `EmptyStateView`, `LoadingStateView`, `ErrorStateView`, `InfoBanner`, `PrivacyNotice`, `FeatureRow`, `BrandMark`.

Rebranding means editing three places: `BrandConfig` (name, tagline, URLs), `BrandPalette` (colours) and `APP_DISPLAY_NAME`/bundle ID in `App/project.yml`.

## 3. Motion

`Motion.quick` (0.18 s, selection), `standard` (spring 0.35), `page` (spring 0.42, direction-aware step slides), `progress` (0.45 s), `reveal` (spring 0.5). Number changes use `.numericText()`. Cards fade and lift in once, staggered by at most 0.15 s. **Reduce Motion:** slides become cross-fades, appear effects and press scaling are disabled, and the building screen shortens to 0.3 s. Nothing blocks interaction.

## 4. Onboarding

### 4.1 Flow (chapters, not step counts)

| Chapter | Steps | Shown when |
|---|---|---|
| Introduction (no progress bar) | Welcome → Privacy | First run only |
| Profile | Who is this for → Child's name* → Date of birth → Growth chart → Current height (+ measuring guide) | Name only for child profiles |
| Growth | Parent heights* → Earlier measurements? → Add measurements → Recent growth change* | Parent heights: ages 2–17. History and growth change: ages 2–20. Entry screen only if "Yes" |
| Lifestyle | Sleep* → Activity* → Eating* | Always (optional) |
| Goals | Goals* → What brings you here* → Concern support | Concern screen only if "Worried about growth" |
| Summary | Putting your profile together (≤ 0.9 s) → Growth profile summary → Start tracking | Always |

\* Skippable. **Required inputs: who it's for, date of birth, growth chart and current height** (plus the earlier-measurements yes/no). That is 4 required answers, fewer than the ≤10 cap in `mvp-scope.md`. Including welcome, privacy, the brief building screen and the summary, a teen without earlier measurements sees 16 screens, an adult 13 and a parent adding history 18, versus about 31 steps reported for the competitor (third-party, unverified).

Navigation: Back on every step, Skip on optional steps (clears that step's answers), Edit from the summary (returns to the summary unless the edit makes a new question relevant, e.g. changing "earlier measurements" to Yes). Every answer is saved immediately; closing or killing the app resumes on the same screen.

### 4.2 Every piece of information collected, and why

| Data | Required | Used for | Phase 1.5 alignment |
|---|---|---|---|
| Who it's for (myself / my child) | Yes | Copy (you vs. child's name), age policy, parent-managed profiles | Parent-managed under-13 |
| Child's nickname | No | Labels the profile, personalises parent copy. Device only | Minimal |
| Date of birth | Yes | Exact age → chart eligibility, age band, which questions appear | Age is computed, never asked |
| Growth chart (female/male) | Yes | Selects the sex-specific reference chart (CDC). Not gender identity; explained with a help note | Minimum needed for the reference |
| Current height + unit | Yes | Chart, percentile and estimate inputs (Phase 5) | Core |
| How it was measured (home / doctor or school / estimate) | Default "home" | Data quality → future uncertainty driver; prompts a real measurement if estimated | Uncertainty drivers |
| Biological parents' heights + measured/estimate, or "don't know" | No | Family-height range (context only, never the estimate); reported heights lower confidence | Context only |
| Earlier measurements (date + height, up to 10) | No | Real trend from day one; velocity needs ≥ 6-month spans | Engine C input |
| Recent growth change (faster / slower / same / not sure) | No | Explains the trend in plain language; never changes an estimate | Interpretation only |
| Sleep: bedtime, wake time, weekend pattern | No | Habit baselines (duration derived, so it isn't asked separately) | Lifestyle engine, no cm |
| Activity: level, sessions per week, preferred activities | No | Realistic routine suggestions | Lifestyle engine, no cm |
| Eating: meal regularity, pattern, challenges, usual drinks | No | Food-group suggestions. **No calories, weight or body questions** | Teen-safe nutrition |
| Goals (multi-select, order kept) | No | Orders Home (quick actions, insight) | Personalisation |
| What brings you here (incl. "worried about growth") | No | Tone; "worried" shows calm safety guidance and prioritises record-keeping | Safety signposting |

**Deliberately not collected:** weight, BMI, ethnicity, puberty details, relatives' heights, location, contacts, photos, email or account. Hidden answers are dropped when the profile is built (e.g. parent heights entered before correcting the birth date to adult age are not stored); tests cover this.

### 4.3 Copy rules
All copy lives in `OnboardingCopy` and `OptionCopy`. `CopyGuard` lists banned phrases ("guarantee", "grow taller", "% accurate", "true height", "HGH" and others) and a test scans every string. **The concern-support text and measuring guide need medical-reviewer approval before release.**

## 5. Main app

**Navigation: four tabs, Home · Growth · Habits · Profile.** A fifth tab was rejected because future features fit existing homes: the AI coach becomes a Home entry and sheet, reports go under Growth, nutrition and exercise under Habits, subscription and widgets under Profile. Parents switch children from a profile menu in each tab's header.

**Home ("command center")**, top to bottom: greeting + profile switcher; current-height hero (value, how long ago, estimate warning, change since the first measurement or a hint); adult-height card (a "Coming soon" placeholder with age-specific text, never a number); percentile placeholder; quick actions ordered by goals (Add measurement, View growth, Habits); habit baselines from onboarding; one rule-based insight.

**Growth:** a chart of the person's own measurements only (an empty state below two points), history with swipe-to-delete (the last measurement can't be deleted), add measurement. **Habits:** baselines plus a "check-ins are coming" empty state. **Profile:** profiles (add a child via the onboarding flow in additional-profile mode, gated through the `EntitlementProviding` boundary, currently unlocked), units, the full profile summary, privacy statements, delete all data (with confirmation), and a medical note.

## 6. Data and persistence

- `AppSnapshot { profiles, activeProfileID, onboardingDraft, privacyAcknowledgement, schemaVersion }` is saved as one JSON file in Application Support with iOS `completeFileProtection` and atomic writes.
- `GrowthProfile` stores the fields in §4.2 plus `measurements: [HeightMeasurement]` (cm, 1 dp; date, method, origin), timestamps and `schemaVersion`.
- **Evolution:** every non-identity field is decoded with `decodeIfPresent` and a default, unknown onboarding steps fall back safely, and `SnapshotMigrator` provides the hook for future upgrades. Tests load "old" JSON with missing fields.
- **Failure handling:** an unreadable file is never deleted automatically. The app offers "Start fresh", which moves the file aside for recovery. Save failures show a banner and keep the data in memory.

## 7. Deviations from earlier plans (and why)

| Change | Reason | Affects |
|---|---|---|
| **JSON file store behind a `ProfileStore` protocol instead of SwiftData** (mvp-scope said SwiftData + CloudKit) | Testable on any toolchain (all 83 tests run on Linux); avoids SwiftData migration pitfalls; additive decoding gives non-destructive evolution. iCloud sync can be added later as another `ProfileStore` (CloudKit records or SwiftData) without touching UI or onboarding | Phase 8 (sync) |
| **Optional lifestyle, goals and intent in onboarding** (MVP table listed only core inputs) | Requested for personalisation. Kept optional and skippable, so the required path stays at 4 inputs | Phase 9 habits use these baselines |
| **Swift 5 language mode for UI targets** | SwiftUI/UIKit APIs still produce strict-concurrency friction; all state and logic are in Swift 6 `GrowthCore` | None |
| **XcodeGen spec instead of a committed `.xcodeproj`** | Readable, reviewable, no merge conflicts. Requires `brew install xcodegen` on the Mac (developer tool, not an app dependency) | Phase 3 CI |
| **`Measurement` renamed `HeightMeasurement`** | Avoids a clash with Foundation's `Measurement<Unit>` | None |

## 8. Verification status (honest)

| Item | Status |
|---|---|
| GrowthCore builds in Swift 6 strict mode, zero warnings | ✅ Verified (Swift 6.1.3, Linux) |
| 83 unit tests: onboarding progression, back, skip, edit, branching (parent/child/teen/young adult/adult), resume after simulated termination, persistence, tolerant decoding, corrupt-file recovery, deletion, unit conversion, parsing, validation (future/impossible birth dates, invalid heights, history rules), dashboard (no fake data), copy guard | ✅ All passing |
| SwiftUI targets (DesignSystem, AppFeatures, App) | ⚠️ **Syntax-checked only** (`swiftc -parse`). They can't be type-checked or run in this Linux environment. The CI `ios-build` job compiles them on macOS; check its result before relying on it |
| Dark mode, Dynamic Type, VoiceOver, Reduce Motion | ⚠️ Implemented (system text styles, dynamic colours, labels and traits, motion fallbacks), **not tested on a device or simulator** |
| No fake scientific results | ✅ The estimate and percentile are placeholders; a test asserts no height or percentage appears in them |
| No secrets, no competitor assets or text | ✅ No keys, network calls or third-party dependencies; all copy and the brand mark are original |
