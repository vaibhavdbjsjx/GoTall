# Growth tracking app (working title: Arcwise)

iOS-first app for honest height-growth tracking: real growth charts, transparent estimates (coming in Phase 5), healthy-habit baselines and privacy by design. The final name is not decided; see `docs/launch-strategy.md`.

## Status
Phase 3 (growth intelligence engine): CDC 2000 percentiles, growth chart, growth speed, family-height range,
adult-height scenario with qualitative uncertainty, profile editing. See `docs/growth-engine.md`.
Phase 2 foundation: `docs/phase-2-foundation.md`.

## Structure
- `Sources/GrowthEngine`: growth science only (CDC reference, percentiles, velocity, scenario), unit-tested
- `Sources/GrowthCore`: platform-independent logic and state (Swift 6, fully unit-tested)
- `Reference/cdc2000`: CDC data file + provenance; `scripts/`: data generation/verification, screenshot capture
- `Sources/DesignSystem`: SwiftUI tokens and components
- `Sources/AppFeatures`: SwiftUI screens
- `App/`: iOS app target (XcodeGen spec + entry point)
- `docs/`: research, architecture and phase decisions

## Run
```sh
swift test                      # core tests (macOS or Linux)
brew install xcodegen           # once, on a Mac
cd App && xcodegen generate && open GrowthApp.xcodeproj   # run the iOS app (Xcode 16+, iOS 17+)
```

No third-party dependencies, no backend, no API keys.
