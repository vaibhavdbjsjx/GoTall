# Stature: height, growth and posture (iOS)

**Growth, measured honestly. Habits that help you stand tall.** An iOS app for teens, parents and adults:
- real CDC growth charts and percentiles
- an adult-height estimate that shows its reasoning and is never sold as a guarantee
- a daily plan with levels, points and a forgiving streak
- 9 guided posture, mobility and core routines (26 moves) with timer, cues and haptics
- a 30-second camera posture check (Apple Vision, on device; nothing recorded)
- bedtime planner, food-variety check-ins, a puberty-stage check
- for parents: Outgrow Forecast (height and clothing size in 3, 6 and 12 months) and a doctor visit kit with a PDF report
- a Learn library of sourced articles
- **Stature Coach**, a growth assistant that runs on Apple's on-device model
- optional account (Sign in with Apple or email/password) to back up and restore

Private by design: no ads, no tracking, data on the device unless you choose to back it up.

## Status
Release candidate 1.0.0. What's left before App Store submission is in `docs/release-checklist.md`. The listing text and in-app purchase table are in `docs/app-store-listing.md`, and accounts setup is in `docs/backend-setup.md`.

## Structure
- `Sources/GrowthEngine`: growth science only (CDC reference, percentiles, velocity, scenario); unit-tested
- `Sources/GrowthCore`: platform-independent logic. Covers profiles, habits, the wellness engine (routines, posture scoring, bedtime, outgrow forecast, progression, today plan), notifications, StoreKit-neutral entitlements, accounts and backup, reports and PDF, and Coach safety. Swift 6, unit-tested on Linux and macOS.
- `Sources/DesignSystem`: SwiftUI tokens (midnight and champagne) and components
- `Sources/AppFeatures`: SwiftUI screens, plus the StoreKit 2, UserNotifications, Vision/AVFoundation, Sign in with Apple, Keychain and Foundation Models adapters
- `App/`: iOS app target (XcodeGen spec, icon, privacy manifest, StoreKit configuration, StoreKit and UI tests)
- `supabase/`: database migration and the `delete-account` Edge Function for optional accounts
- `site/`: privacy, terms and support pages generated from the in-app text by `scripts/build_site.py`
- `scripts/`: CDC data, simulator and App Store screenshots, iOS test runner

## Run
```sh
swift test                      # core tests (macOS or Linux)
brew install xcodegen           # once, on a Mac
cd App && xcodegen generate && open GrowthApp.xcodeproj   # Xcode 26, iOS 17+ (Coach AI needs Apple Intelligence)
scripts/run_ios_tests.sh        # StoreKit + UI tests on a simulator
```

No third-party Swift dependencies. Accounts are off until `STATURE_BACKEND_URL` and `STATURE_BACKEND_ANON_KEY` are set in `App/project.yml`.
