.DEFAULT_GOAL := help

EMPTY :=
SPACE := $(EMPTY) $(EMPTY)
TEMP_DIR := $(if $(strip $(TMPDIR)),$(TMPDIR),/tmp)
DEFAULT_BUILD_DIR := $(if $(findstring $(SPACE),$(CURDIR)),$(TEMP_DIR)/axi4lite-core-verilator-build,$(CURDIR)/build)
REGRESSION_BUILD_ROOT ?= $(DEFAULT_BUILD_DIR)

.PHONY: help lint test test-master test-slave test-loopback clean

help:
	@printf '%s\n' \
		'Usage: make <target> [SEED=<1..4294967295>]' \
		'' \
		'Targets:' \
		'  lint           Lint all 32-bit and 64-bit configurations' \
		'  test           Run every test suite' \
		'  test-master    Run the master adapter tests' \
		'  test-slave     Run the slave adapter tests' \
		'  test-loopback  Run the end-to-end loopback tests' \
		'  clean          Remove generated build output'

lint:
	./scripts/run_lint.sh

test: TEST_SUITE := all
test-master: TEST_SUITE := master
test-slave: TEST_SUITE := slave
test-loopback: TEST_SUITE := loopback

test test-master test-slave test-loopback:
	TEST_SUITE="$(TEST_SUITE)" REGRESSION_BUILD_ROOT="$(REGRESSION_BUILD_ROOT)" ./scripts/run_regression.sh

clean:
	rm -rf -- "$(REGRESSION_BUILD_ROOT)" "$(CURDIR)/obj_dir"
