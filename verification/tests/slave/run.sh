#!/usr/bin/env bash
# Regression suite: slave. Usage: run.sh [build-dir] [seed]
set -euo pipefail
SUITE=slave
TOP=tb_slave
TOP_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/tb_slave.sv"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../common/run_suite.sh"
