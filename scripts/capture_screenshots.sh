#!/bin/bash
# Captures simulator screenshots of DEBUG demo scenarios (synthetic data) in light, dark and large-text modes.
# Usage (on macOS with Xcode): scripts/capture_screenshots.sh <path-to-GrowthApp.app> <output-dir>
set -uo pipefail
APP="$1"
OUT="$2"
BUNDLE="com.example.growthapp"
mkdir -p "$OUT"

DEVICE=$(xcrun simctl list devices available | grep -E "iPhone 1[5-7]( Pro)? \(" | grep -v "Max\|Plus" | head -1 | sed -E 's/^ *(.*) \(([A-F0-9-]+)\).*/\2/')
echo "Using simulator $DEVICE"
xcrun simctl boot "$DEVICE" 2>/dev/null || true
xcrun simctl bootstatus "$DEVICE" -b
xcrun simctl install "$DEVICE" "$APP"
xcrun simctl status_bar "$DEVICE" override --time "9:41" --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3 2>/dev/null || true

shoot() {
  local name="$1"; shift
  xcrun simctl terminate "$DEVICE" "$BUNDLE" 2>/dev/null || true
  xcrun simctl launch "$DEVICE" "$BUNDLE" "$@" >/dev/null
  sleep 6
  xcrun simctl io "$DEVICE" screenshot "$OUT/$name.png" >/dev/null 2>&1 && echo "captured $name"
}

run_set() {
  local prefix="$1"
  shoot "$prefix-01-home-teen" -demoScenario teen
  shoot "$prefix-02-growth-teen" -demoScenario teen -initialTab growth
  shoot "$prefix-03-growth-teen-estimate" -demoScenario teen -initialTab growth -growthScrollTo estimate
  shoot "$prefix-04-growth-teen-family" -demoScenario teen -initialTab growth -growthScrollTo family
  shoot "$prefix-05-explanation" -demoScenario teen -initialTab growth -openExplanation YES
  shoot "$prefix-06-home-parent" -demoScenario parent
  shoot "$prefix-07-growth-starter" -demoScenario starter -initialTab growth
  shoot "$prefix-08-home-adult" -demoScenario adult
  shoot "$prefix-09-growth-concern" -demoScenario concern -initialTab growth -growthScrollTo estimate
  shoot "$prefix-10-onboarding-height" -demoScenario onboarding
  shoot "$prefix-11-profile" -demoScenario parent -initialTab profile
}

xcrun simctl ui "$DEVICE" appearance light
xcrun simctl ui "$DEVICE" content_size large
run_set light
# Fresh install with no data shows the real first-run welcome screen.
shoot "light-00-welcome"

xcrun simctl ui "$DEVICE" appearance dark
shoot dark-01-home-teen -demoScenario teen
shoot dark-02-growth-teen -demoScenario teen -initialTab growth
shoot dark-03-growth-teen-estimate -demoScenario teen -initialTab growth -growthScrollTo estimate
shoot dark-05-explanation -demoScenario teen -initialTab growth -openExplanation YES
shoot dark-06-home-parent -demoScenario parent

xcrun simctl ui "$DEVICE" appearance light
xcrun simctl ui "$DEVICE" content_size accessibility-extra-large
shoot ax-01-home-teen -demoScenario teen
shoot ax-02-growth-teen -demoScenario teen -initialTab growth
shoot ax-03-growth-teen-estimate -demoScenario teen -initialTab growth -growthScrollTo estimate
shoot ax-10-onboarding-height -demoScenario onboarding
xcrun simctl ui "$DEVICE" content_size large

ls -la "$OUT"
