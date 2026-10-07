# Growth tracking app (working title: Arcwise)

iOS-first app for honest height-growth tracking: real growth charts, transparent estimates (coming in Phase 5), healthy-habit baselines and privacy by design. The final name is not decided; see `docs/launch-strategy.md`.

## Status
Phase 2 (product foundation): design system, adaptive onboarding, local persistence, dashboard shell, navigation. See `docs/phase-2-foundation.md`.

## Structure
- `Sources/GrowthCore`: platform-independent logic and state (Swift 6, fully unit-tested)
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
