#!/usr/bin/env bash
# Self-test for axi4lite_protocol_checker.
#
# Builds the self-test bench once per rule set (STRICT_PROFILE = 1 and 0) and
# runs every scenario. A legal scenario must print "SELFTEST PASS"; an illegal
# scenario must stop on the named assertion.
#
# Usage: verification/tests/checker/run.sh [build-dir] [seed]
# The scenarios are deterministic, so the seed is accepted and ignored.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
BUILD_DIR="${1:-$ROOT/build/checker}"

SOURCES=(
  "$ROOT/rtl/axi4lite_pkg.sv"
  "$ROOT/rtl/axi4lite_if.sv"
  "$ROOT/verification/checkers/axi4lite_protocol_checker.sv"
  "$ROOT/verification/tests/checker/axi4lite_checker_selftest_tb.sv"
)

# scenario : expected result with STRICT_PROFILE=1 : with STRICT_PROFILE=0
# "PASS" means no assertion may fire; anything else is the assertion label.
CASES=(
  "legal_basic:PASS:PASS"
  "legal_overlap:a_profile_no_second_aw:PASS"
  "second_aw:a_profile_no_second_aw:PASS"
  "ready_in_reset:a_profile_reset_ready_low:PASS"
  "aw_valid_drop:a_axi_aw_stable:a_axi_aw_stable"
  "w_payload_change:a_axi_w_stable:a_axi_w_stable"
  "b_payload_change:a_axi_b_stable:a_axi_b_stable"
  "ar_payload_change:a_axi_ar_stable:a_axi_ar_stable"
  "r_valid_drop:a_axi_r_stable:a_axi_r_stable"
  "b_before_w:a_axi_bvalid_has_aw_and_w:a_axi_bvalid_has_aw_and_w"
  "r_without_ar:a_axi_rvalid_has_ar:a_axi_rvalid_has_ar"
  "b_exokay:a_axi_no_exokay_b:a_axi_no_exokay_b"
  "r_exokay:a_axi_no_exokay_r:a_axi_no_exokay_r"
  "valid_in_reset:a_axi_reset_valid_low:a_axi_reset_valid_low"
  "valid_at_reset_exit:a_axi_reset_exit_valid_low:a_axi_reset_exit_valid_low"
)

build() {
  local strict="$1"
  local dir="$BUILD_DIR/strict$strict"
  # SYNCASYNCNET is waived because the bench drives ARESETn from clocked
  # stimulus while the checker uses it as an asynchronous reset. The design
  # itself is linted without waivers by scripts/run_lint.sh.
  verilator --binary --timing --assert -Wall -Wno-SYNCASYNCNET \
    --top-module axi4lite_checker_selftest_tb \
    "-GSTRICT_PROFILE=1'b$strict" \
    -Mdir "$dir" -o sim "${SOURCES[@]}" > "$dir.build.log" 2>&1 || {
      cat "$dir.build.log"
      echo "BUILD FAILED: STRICT_PROFILE=$strict" >&2
      exit 1
    }
}

mkdir -p "$BUILD_DIR"
build 1
build 0

failures=0
total=0

for entry in "${CASES[@]}"; do
  IFS=: read -r scenario expect_strict expect_generic <<< "$entry"
  for strict in 1 0; do
    if [[ "$strict" == 1 ]]; then expect="$expect_strict"; else expect="$expect_generic"; fi
    total=$((total + 1))
    log="$BUILD_DIR/strict$strict.$scenario.log"
    set +e
    # The subshell keeps bash's "Aborted" job report out of the output.
    ( "$BUILD_DIR/strict$strict/sim" "+SCENARIO=$scenario"; exit $? ) > "$log" 2>&1
    status=$?
    set -e

    if [[ "$expect" == PASS ]]; then
      if [[ $status -eq 0 ]] && grep -q "SELFTEST PASS" "$log" && ! grep -q "Assertion failed" "$log"; then
        result=ok
      else
        result=FAIL
      fi
    else
      first_fail="$(grep -m1 "Assertion failed" "$log" || true)"
      if [[ $status -ne 0 ]] && [[ "$first_fail" == *".$expect:"* ]]; then
        result=ok
      else
        result=FAIL
      fi
    fi

    printf '%-4s STRICT_PROFILE=%s %-22s expect %s\n' "$result" "$strict" "$scenario" "$expect"
    if [[ "$result" == FAIL ]]; then
      failures=$((failures + 1))
      sed 's/^/     | /' "$log"
    fi
  done
done

echo "checker self-test: $((total - failures))/$total passed"
[[ $failures -eq 0 ]]
