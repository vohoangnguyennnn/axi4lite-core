#!/usr/bin/env bash
# Regression suite: loopback. Usage: run.sh [build-dir] [seed]
set -euo pipefail
SUITE=loopback
TOP=tb_loopback
TOP_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/tb_loopback.sv"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../common/run_suite.sh"
