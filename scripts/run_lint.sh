#!/usr/bin/env bash
# Lint the RTL and protocol checkers with Verilator -Wall.
#
# Every module is elaborated through verification/lint/axi4lite_lint_top.sv
# once per supported DATA_WIDTH. Any warning fails the run.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

SOURCES=(
  "$ROOT/rtl/axi4lite_pkg.sv"
  "$ROOT/rtl/axi4lite_if.sv"
  "$ROOT/rtl/native_req_rsp_if.sv"
  "$ROOT/rtl/axi4lite_master_adapter.sv"
  "$ROOT/rtl/axi4lite_slave_adapter.sv"
  "$ROOT/verification/checkers/axi4lite_protocol_checker.sv"
  "$ROOT/verification/checkers/native_req_rsp_checker.sv"
  "$ROOT/verification/lint/axi4lite_lint_top.sv"
)

command -v verilator > /dev/null || {
  echo "run_lint: verilator not found in PATH" >&2
  exit 1
}

failures=0
for data_width in 32 64; do
  if verilator --lint-only -Wall --timing \
       --top-module axi4lite_lint_top \
       "-GDATA_WIDTH=$data_width" \
       "${SOURCES[@]}"; then
    echo "lint ok   DATA_WIDTH=$data_width"
  else
    echo "lint FAIL DATA_WIDTH=$data_width"
    failures=$((failures + 1))
  fi
done

[[ $failures -eq 0 ]]
