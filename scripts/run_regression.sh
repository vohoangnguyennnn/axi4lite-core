#!/usr/bin/env bash
# Run the regression suites.
#
# Environment:
#   TEST_SUITE             all | checker | master | slave | loopback (default: all)
#   REGRESSION_BUILD_ROOT  build output directory (default: <repo>/build)
#   SEED                   random seed, 1..2147483647 (default: time-based);
#                          the upper bound is Verilator's +verilator+seed+ limit
#
# Each suite lives in verification/tests/<suite>/run.sh and is called as
#   run.sh <build-dir> <seed>
# A suite whose runner does not exist yet counts as a failure, so "all" never
# reports success while planned suites are missing.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_SUITE="${TEST_SUITE:-all}"
BUILD_ROOT="${REGRESSION_BUILD_ROOT:-$ROOT/build}"
ALL_SUITES=(checker master slave loopback)

if [[ -z "${SEED:-}" ]]; then
  SEED=$(( $(date +%s) % 2147483647 + 1 ))
fi
if ! [[ "$SEED" =~ ^[0-9]+$ ]] || (( SEED < 1 || SEED > 2147483647 )); then
  echo "run_regression: SEED must be an integer in 1..2147483647, got '$SEED'" >&2
  exit 1
fi

case "$TEST_SUITE" in
  all) suites=("${ALL_SUITES[@]}") ;;
  checker|master|slave|loopback) suites=("$TEST_SUITE") ;;
  *)
    echo "run_regression: unknown TEST_SUITE '$TEST_SUITE'" \
         "(expected all, ${ALL_SUITES[*]})" >&2
    exit 1
    ;;
esac

command -v verilator > /dev/null || {
  echo "run_regression: verilator not found in PATH" >&2
  exit 1
}

echo "regression: suites=${suites[*]} seed=$SEED build=$BUILD_ROOT"

declare -a results=()
failures=0
for suite in "${suites[@]}"; do
  runner="$ROOT/verification/tests/$suite/run.sh"
  echo "=== suite: $suite"
  if [[ ! -x "$runner" ]]; then
    echo "suite '$suite' is not implemented yet ($runner missing)"
    results+=("MISSING $suite")
    failures=$((failures + 1))
  elif "$runner" "$BUILD_ROOT/$suite" "$SEED"; then
    results+=("PASS    $suite")
  else
    results+=("FAIL    $suite")
    failures=$((failures + 1))
  fi
done

echo "=== summary (seed=$SEED)"
printf '  %s\n' "${results[@]}"
[[ $failures -eq 0 ]]
