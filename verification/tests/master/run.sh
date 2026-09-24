#!/usr/bin/env bash
# Regression suite: master. Usage: run.sh [build-dir] [seed]
set -euo pipefail
SUITE=master
TOP=tb_master
TOP_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/tb_master.sv"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../common/run_suite.sh"
