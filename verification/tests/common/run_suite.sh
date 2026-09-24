# Shared runner for the master, slave, and loopback suites.
#
# Sourced by verification/tests/<suite>/run.sh after it sets:
#   SUITE     suite name
#   TOP       top-level module
#   TOP_FILE  path of the top-level source
# and receives <build-dir> <seed> as $1 and $2.
#
# Builds the bench at DATA_WIDTH 32 and 64 and runs every variant below.
# Run N of a build uses seed <seed> + N, printed for reproduction.
# Each run writes functional coverage (cover properties) to
# <build-dir>/dw<width>.<variant>.dat for scripts/coverage_report.py.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
BUILD_DIR="${1:-$ROOT/build/$SUITE}"
SEED="${2:-1}"

SOURCES=(
  "$ROOT/rtl/axi4lite_pkg.sv"
  "$ROOT/rtl/axi4lite_if.sv"
  "$ROOT/rtl/native_req_rsp_if.sv"
  "$ROOT/rtl/axi4lite_master_adapter.sv"
  "$ROOT/rtl/axi4lite_slave_adapter.sv"
  "$ROOT/verification/checkers/axi4lite_protocol_checker.sv"
  "$ROOT/verification/checkers/native_req_rsp_checker.sv"
  "$ROOT/verification/tb/axi4lite_tb_pkg.sv"
  "$ROOT/verification/tb/tb_clock_reset.sv"
  "$ROOT/verification/tb/tb_end_check.sv"
  "$ROOT/verification/tb/native_monitor.sv"
  "$ROOT/verification/tb/axi4lite_monitor.sv"
  "$ROOT/verification/tb/sb_channel.sv"
  "$ROOT/verification/tb/sb_path.sv"
  "$ROOT/verification/tb/native_requester_driver.sv"
  "$ROOT/verification/tb/native_target_model.sv"
  "$ROOT/verification/tb/axi4lite_master_driver.sv"
  "$ROOT/verification/tb/axi4lite_slave_model.sv"
  "$TOP_FILE"
)

# name : plusargs
VARIANTS=(
  "random:+REQ_RATE=50 +RSP_READY_RATE=50 +READY_RATE=50 +RSP_RATE=50 +ERR_RATE=20"
  "fast:+REQ_RATE=100 +RSP_READY_RATE=100 +READY_RATE=100 +RSP_RATE=100 +ERR_RATE=20"
  "slow:+REQ_RATE=15 +RSP_READY_RATE=15 +READY_RATE=15 +RSP_RATE=15 +ERR_RATE=20 +NUM_TXN=200"
  "reset:+REQ_RATE=50 +RSP_READY_RATE=50 +READY_RATE=50 +RSP_RATE=50 +ERR_RATE=20 +RESET_AT=1500"
)

mkdir -p "$BUILD_DIR"
# Coverage from an earlier run must not count toward this one.
rm -f "$BUILD_DIR"/*.dat

build() {
  local data_width="$1"
  local dir="$BUILD_DIR/dw$data_width"
  # Waivers apply to the bench build only; the RTL is linted without waivers
  # by scripts/run_lint.sh.
  #   SYNCASYNCNET  the bench drives ARESETn from clocked stimulus while the
  #                 design uses it as an asynchronous reset
  #   BLKSEQ        behavioral models update bookkeeping with blocking
  #                 assignments inside clocked processes
  #   WIDTHTRUNC    random stimulus is truncated from 32/64-bit $urandom
  if ! verilator --cc --exe --build -j "$(nproc)" --timing --assert \
         --coverage-user -Wall \
         -Wno-SYNCASYNCNET -Wno-BLKSEQ -Wno-WIDTHTRUNC \
         -CFLAGS "-DTB_TOP_CLASS=V$TOP" \
         --top-module "$TOP" "-GDATA_WIDTH=$data_width" \
         -Mdir "$dir" -o sim "${SOURCES[@]}" \
         "$ROOT/verification/tests/common/sim_main.cpp" > "$dir.build.log" 2>&1; then
    cat "$dir.build.log"
    echo "BUILD FAILED: $SUITE DATA_WIDTH=$data_width" >&2
    return 1
  fi
}

failures=0
total=0

for data_width in 32 64; do
  if ! build "$data_width"; then
    total=$((total + ${#VARIANTS[@]}))
    failures=$((failures + ${#VARIANTS[@]}))
    continue
  fi
  index=0
  for entry in "${VARIANTS[@]}"; do
    name="${entry%%:*}"
    read -r -a plusargs <<< "${entry#*:}"
    run_seed=$(( (SEED + index - 1) % 2147483647 + 1 ))
    index=$((index + 1))
    total=$((total + 1))
    log="$BUILD_DIR/dw$data_width.$name.log"

    set +e
    ( "$BUILD_DIR/dw$data_width/sim" "+verilator+seed+$run_seed" "${plusargs[@]}" \
        "+COVERAGE_FILE=$BUILD_DIR/dw$data_width.$name.dat"; exit $? ) > "$log" 2>&1
    status=$?
    set -e

    if [[ $status -eq 0 ]] && grep -q "TEST PASS" "$log"; then
      printf 'ok   %-8s DATA_WIDTH=%-2s %-6s seed=%-10s %s\n' \
        "$SUITE" "$data_width" "$name" "$run_seed" "$(grep -m1 'TEST PASS' "$log" | sed 's/.*TEST PASS: [a-z]* //')"
    else
      failures=$((failures + 1))
      printf 'FAIL %-8s DATA_WIDTH=%-2s %-6s seed=%-10s\n' "$SUITE" "$data_width" "$name" "$run_seed"
      echo "     reproduce: $BUILD_DIR/dw$data_width/sim +verilator+seed+$run_seed ${plusargs[*]}"
      grep -E "Error|Assertion|mismatch|watchdog|fatal" "$log" | head -8 | sed 's/^/     | /'
    fi
  done
done

echo "$SUITE: $((total - failures))/$total passed"
[[ $failures -eq 0 ]]
