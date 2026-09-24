.DEFAULT_GOAL := help

EMPTY :=
SPACE := $(EMPTY) $(EMPTY)
TEMP_DIR := $(if $(strip $(TMPDIR)),$(TMPDIR),/tmp)
DEFAULT_BUILD_DIR := $(if $(findstring $(SPACE),$(CURDIR)),$(TEMP_DIR)/axi4lite-core-verilator-build,$(CURDIR)/build)
REGRESSION_BUILD_ROOT ?= $(DEFAULT_BUILD_DIR)

.PHONY: help lint test test-checker test-master test-slave test-loopback coverage clean

help:
	@printf '%s\n' \
		'Usage: make <target> [SEED=<1..2147483647>]' \
		'' \
		'Targets:' \
		'  lint           Lint all 32-bit and 64-bit configurations' \
		'  test           Run every test suite' \
		'  test-checker   Run the AXI4-Lite protocol checker self-test' \
		'  test-master    Run the master adapter tests' \
		'  test-slave     Run the slave adapter tests' \
		'  test-loopback  Run the end-to-end loopback tests' \
		'  coverage       Run every test suite and require full functional coverage' \
		'  clean          Remove generated build output'

lint:
	./scripts/run_lint.sh

test: TEST_SUITE := all
test-checker: TEST_SUITE := checker
test-master: TEST_SUITE := master
test-slave: TEST_SUITE := slave
test-loopback: TEST_SUITE := loopback

test test-checker test-master test-slave test-loopback:
	TEST_SUITE="$(TEST_SUITE)" REGRESSION_BUILD_ROOT="$(REGRESSION_BUILD_ROOT)" ./scripts/run_regression.sh

coverage: test
	./scripts/coverage_report.py "$(REGRESSION_BUILD_ROOT)"

clean:
	rm -rf -- "$(REGRESSION_BUILD_ROOT)" "$(CURDIR)/obj_dir"
