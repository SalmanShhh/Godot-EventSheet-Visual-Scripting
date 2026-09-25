#!/usr/bin/env bash
# Reads one run of tests/run_tests.gd (a whole suite, one shard or the tail) and exits 0 only when it
# is green. Usage: suite_verdict.sh <log file> <label>
#
# [FAIL] lines can be indented (nested reporters), and a test may print one ON PURPOSE to prove the
# red-run report formats it - such a line names itself with the deliberate_probe_not_a_failure marker
# and does not count. Same filter as tools/run_tests_parallel.ps1 and tools/test_report.gd.
set -u
LOG="$1"
LABEL="$2"
FAILURES=$(grep -F '[FAIL]' "$LOG" | grep -v 'deliberate_probe_not_a_failure' || true)
echo "$LABEL - PASS: $(grep -cE '^\[PASS\]' "$LOG")  FAIL: $(printf '%s' "$FAILURES" | grep -c . || true)"
VERDICT_OK=true
# The verdict line is the only always-right signal: a test that crashes mid-run prints zero [FAIL]
# lines, so the absence of failures alone does not make a run green.
grep -qxF 'All tests passed.' "$LOG" || VERDICT_OK=false
if [ -z "$FAILURES" ] && $VERDICT_OK; then exit 0; fi
# Say WHY in annotations: they are readable on the run page without repo access, the raw log is not.
if [ -n "$FAILURES" ]; then
  echo "Failures:"; echo "$FAILURES"
  # Two lines of context after each [FAIL]: tests print their expected/actual there.
  grep -F -A 2 '[FAIL]' "$LOG" | grep -v 'deliberate_probe_not_a_failure' | head -n 24 \
    | while IFS= read -r line; do echo "::error::$LABEL: $line"; done
fi
if ! $VERDICT_OK; then
  echo "::error::$LABEL: the 'All tests passed.' verdict never printed - the run died mid-suite."
  for trail in .godot/test_progress/*.log; do
    [ -f "$trail" ] && echo "::error::$LABEL: crash sentinel $(basename "$trail"): $(tail -n 1 "$trail")"
  done
  tail -n 8 "$LOG" | while IFS= read -r line; do echo "::error::$LABEL log tail: $line"; done
fi
exit 1
