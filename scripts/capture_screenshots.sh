#!/bin/bash
# Captures simulator screenshots of DEBUG demo scenarios (synthetic data) across devices, light/dark and large text.
# Usage (on macOS with Xcode): scripts/capture_screenshots.sh <path-to-GrowthApp.app> <output-dir>
set -uo pipefail
APP="$1"
OUT="$2"
BUNDLE="com.example.growthapp"
mkdir -p "$OUT"

udid_for() { xcrun simctl list devices available | grep -E "$1" | head -1 | sed -E 's/.*\(([A-F0-9-]{36})\).*/\1/'; }

prepare() {
  local d="$1"
  xcrun simctl boot "$d" 2>/dev/null || true
  xcrun simctl bootstatus "$d" -b >/dev/null
  xcrun simctl install "$d" "$APP"
  xcrun simctl status_bar "$d" override --time "9:41" --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3 2>/dev/null || true
  xcrun simctl ui "$d" appearance light
  xcrun simctl ui "$d" content_size large
}

shoot() {
  local d="$1" name="$2"; shift 2
  xcrun simctl terminate "$d" "$BUNDLE" 2>/dev/null || true
  xcrun simctl launch "$d" "$BUNDLE" "$@" >/dev/null
  sleep 6
  xcrun simctl io "$d" screenshot "$OUT/$name.png" >/dev/null 2>&1 && echo "captured $name"
}

MAIN=$(udid_for "iPhone 1[5-7] \(")
[ -z "$MAIN" ] && MAIN=$(udid_for "iPhone 1[5-7] Pro \(")
echo "Main simulator: $MAIN"
prepare "$MAIN"

# Light, standard size
shoot "$MAIN" light-00-welcome
shoot "$MAIN" light-01-home-teen -demoScenario teen
shoot "$MAIN" light-02-home-teen-today -demoScenario teen -homeScrollTo today
shoot "$MAIN" light-03-habits-teen -demoScenario teen -initialTab habits
shoot "$MAIN" light-04-growth-teen -demoScenario teen -initialTab growth
shoot "$MAIN" light-05-growth-teen-numbers -demoScenario teen -initialTab growth -growthScrollTo velocity
shoot "$MAIN" light-06-explanation -demoScenario teen -initialTab growth -openExplanation YES
shoot "$MAIN" light-07-home-parent -demoScenario parent
shoot "$MAIN" light-08-switcher -demoScenario parent -openProfileSwitcher YES
shoot "$MAIN" light-09-measure-height -demoScenario teen -openAddMeasurement YES
shoot "$MAIN" light-10-measure-method -demoScenario teen -openAddMeasurement YES -measurementStep method
shoot "$MAIN" light-11-measure-review -demoScenario teen -openAddMeasurement YES -measurementStep review
shoot "$MAIN" light-12-measure-success -demoScenario starter -openAddMeasurement YES -measurementSuccess YES
shoot "$MAIN" light-13-profile -demoScenario teen -initialTab profile
shoot "$MAIN" light-14-onboarding-height -demoScenario onboarding
shoot "$MAIN" light-15-onboarding-summary -demoScenario onboardingSummary
shoot "$MAIN" light-16-home-adult -demoScenario adult
shoot "$MAIN" light-17-home-starter -demoScenario starter
shoot "$MAIN" light-18-growth-concern -demoScenario concern -initialTab growth

# Dark
xcrun simctl ui "$MAIN" appearance dark
shoot "$MAIN" dark-01-home-teen -demoScenario teen
shoot "$MAIN" dark-03-habits-teen -demoScenario teen -initialTab habits
shoot "$MAIN" dark-04-growth-teen -demoScenario teen -initialTab growth
shoot "$MAIN" dark-08-switcher -demoScenario parent -openProfileSwitcher YES
shoot "$MAIN" dark-12-measure-success -demoScenario starter -openAddMeasurement YES -measurementSuccess YES
shoot "$MAIN" dark-13-profile -demoScenario teen -initialTab profile
shoot "$MAIN" dark-15-onboarding-summary -demoScenario onboardingSummary
xcrun simctl ui "$MAIN" appearance light

# Accessibility text size
xcrun simctl ui "$MAIN" content_size accessibility-extra-large
shoot "$MAIN" ax-01-home-teen -demoScenario teen
shoot "$MAIN" ax-02-home-teen-today -demoScenario teen -homeScrollTo today
shoot "$MAIN" ax-03-habits-teen -demoScenario teen -initialTab habits
shoot "$MAIN" ax-04-growth-teen -demoScenario teen -initialTab growth
shoot "$MAIN" ax-11-measure-review -demoScenario teen -openAddMeasurement YES -measurementStep review
shoot "$MAIN" ax-13-profile -demoScenario teen -initialTab profile
xcrun simctl ui "$MAIN" content_size large
xcrun simctl shutdown "$MAIN" 2>/dev/null || true

# Small and large phones
SMALL=$(udid_for "iPhone SE")
if [ -n "$SMALL" ]; then
  prepare "$SMALL"
  shoot "$SMALL" se-01-home-teen -demoScenario teen
  shoot "$SMALL" se-03-habits-teen -demoScenario teen -initialTab habits
  shoot "$SMALL" se-04-growth-teen -demoScenario teen -initialTab growth
  shoot "$SMALL" se-15-onboarding-summary -demoScenario onboardingSummary
  xcrun simctl shutdown "$SMALL" 2>/dev/null || true
else
  echo "No iPhone SE simulator available"
fi
LARGE=$(udid_for "Pro Max \(")
if [ -n "$LARGE" ]; then
  prepare "$LARGE"
  shoot "$LARGE" max-01-home-teen -demoScenario teen
  shoot "$LARGE" max-04-growth-teen -demoScenario teen -initialTab growth
  xcrun simctl shutdown "$LARGE" 2>/dev/null || true
fi
ls "$OUT" | wc -l
