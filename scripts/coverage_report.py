#!/usr/bin/env python3
"""Functional coverage report for the regression suites.

Reads the Verilator coverage files (*.dat) written by the master, slave, and
loopback suites, merges hits per cover property across checker instances,
and prints a table of hits per suite. Exits non-zero if any cover property
was never hit in any suite.

Usage: scripts/coverage_report.py <regression-build-root>
"""

import collections
import pathlib
import re
import sys

SUITES = ("master", "slave", "loopback")

# One coverage point: C '<\x01key\x02value ...>' <count>
LINE_RE = re.compile(r"^C '(?P<keys>.*)' (?P<count>\d+)$")


def parse_point(keys):
    fields = {}
    for item in keys.split("\x01"):
        if "\x02" in item:
            key, value = item.split("\x02", 1)
            fields[key] = value
    return fields


def main(argv):
    if len(argv) != 2:
        print(__doc__.strip().splitlines()[-1], file=sys.stderr)
        return 2

    root = pathlib.Path(argv[1])
    # (checker file, cover name) -> suite -> hits
    hits = collections.defaultdict(lambda: collections.Counter())
    files_read = 0

    for suite in SUITES:
        dat_files = sorted((root / suite).glob("*.dat"))
        if not dat_files:
            print(f"coverage: no coverage data for suite '{suite}' under "
                  f"{root / suite}; run the regression first", file=sys.stderr)
            return 1
        for dat in dat_files:
            files_read += 1
            for line in dat.read_text().splitlines():
                match = LINE_RE.match(line)
                if not match:
                    continue
                fields = parse_point(match.group("keys"))
                if not fields.get("page", "").startswith("v_user/"):
                    continue
                key = (pathlib.Path(fields["f"]).name, fields["o"])
                hits[key][suite] += int(match.group("count"))

    if not hits:
        print("coverage: no cover properties found", file=sys.stderr)
        return 1

    name_width = max(len(name) for _, name in hits)
    header = f"{'cover property':<{name_width}}  " + "  ".join(
        f"{suite:>9}" for suite in SUITES)
    uncovered = []
    current_file = None

    print(f"functional coverage from {files_read} runs")
    for (file_name, name) in sorted(hits):
        if file_name != current_file:
            current_file = file_name
            print(f"\n{file_name}")
            print(header)
        per_suite = hits[(file_name, name)]
        total = sum(per_suite.values())
        marker = "" if total else "   <-- NOT COVERED"
        print(f"{name:<{name_width}}  " + "  ".join(
            f"{per_suite[suite]:>9}" for suite in SUITES) + marker)
        if not total:
            uncovered.append(f"{file_name}:{name}")

    covered = len(hits) - len(uncovered)
    print(f"\ncoverage: {covered}/{len(hits)} cover properties hit")
    if uncovered:
        print("uncovered:\n  " + "\n  ".join(uncovered))
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
