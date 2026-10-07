#!/bin/bash
# Runs the app-hosted StoreKit tests and the UI tests on an iPhone simulator.
# Usage (macOS with Xcode, after `cd App && xcodegen generate`): scripts/run_ios_tests.sh
set -uo pipefail
UDID=$(xcrun simctl list devices available | grep -E "iPhone 1[5-7] \(" | head -1 | sed -E 's/.*\(([A-F0-9-]{36})\).*/\1/')
echo "Test simulator: $UDID"
xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b >/dev/null
xcodebuild test \
  -project App/GrowthApp.xcodeproj \
  -scheme GrowthApp \
  -destination "id=$UDID" \
  -derivedDataPath build-tests \
  CODE_SIGNING_ALLOWED=NO 2>&1 | tee xcodebuild-test.log | grep -E "Test Case|error:|Executed|\*\* TEST|XCTAssert|Failing tests|crash|Restarting|exception|Terminating|signal|testCancellation"
status=${PIPESTATUS[0]}
echo "xcodebuild test exit status: $status"
if [ "$status" -ne 0 ]; then
  echo "---- failure context ----"
  grep -n -B3 -A12 -E "crash|Restarting after unexpected exit|exception|testCancellation" xcodebuild-test.log | head -150
fi
exit $status
