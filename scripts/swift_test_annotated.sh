#!/usr/bin/env bash
# Runs `swift test` and turns compiler errors and test failures into GitHub annotations,
# so failures are readable from the Checks tab and the API without downloading logs.
set -o pipefail
swift test 2>&1 | tee swift-test.log
status=${PIPESTATUS[0]}
if [ "$status" -ne 0 ]; then
  grep -E "error:|failed \(|XCTAssert|Fatal error" swift-test.log | grep -v "^\s*$" | sort -u | head -40 | while IFS= read -r line; do
    echo "::error title=swift test::${line//$'\r'/}"
  done
fi
exit "$status"
