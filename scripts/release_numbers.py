#!/usr/bin/env python3
"""Fills the "## Current numbers" section of the two quality pages, for the release being built.

    python3 scripts/release_numbers.py --test-log FILE --commit SHA --terraform VERSION --runner NAME

The release workflow runs it after scripts/test.sh, on the tagged commit, and before
scripts/pack-docs.sh, so the numbers reach docs-content.tar.gz and are never committed: in the
repository each section holds only the placeholder. It changes only the working tree.

testing-and-quality.md gets what the release's own run of scripts/test.sh measured: the run blocks
that passed and failed in each test subject, read from terraform test's summary lines. performance.md
says it is not measured, and why: the module runs nothing itself.
"""

from __future__ import annotations

import argparse
import datetime
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DOCS = ROOT / "docs-content"
HEADING = "## Current numbers"
SUMMARY = re.compile(r"^(?:Success!|Failure!) (\d+) passed, (\d+) failed", re.MULTILINE)
SUBJECT = re.compile(r"^::group::(tests/\S+)$", re.MULTILINE)


def replace_section(page: Path, body: str) -> None:
    text = page.read_text(encoding="utf-8")
    start = text.find(f"\n{HEADING}\n")
    if start < 0:
        raise SystemExit(f"release_numbers.py: {page.name} has no '{HEADING}' section")
    start += len(f"\n{HEADING}\n")
    following = re.search(r"^#{1,2} ", text[start:], re.MULTILINE)
    end = start + following.start() if following else len(text)
    rest = text[end:]
    page.write_text(text[:start] + "\n" + body.rstrip("\n") + "\n" + ("\n" + rest if rest else ""), encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--test-log", required=True, type=Path)
    parser.add_argument("--commit", required=True)
    parser.add_argument("--terraform", required=True)
    parser.add_argument("--runner", required=True)
    args = parser.parse_args()

    log = args.test_log.read_text(encoding="utf-8")
    subjects = SUBJECT.findall(log)
    summaries = [(int(p), int(f)) for p, f in SUMMARY.findall(log)]
    if not subjects or len(subjects) != len(summaries):
        print(
            f"release_numbers.py: {len(subjects)} test subjects but {len(summaries)} summary lines in "
            f"{args.test_log}: the numbers cannot be read",
            file=sys.stderr,
        )
        return 2

    date = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%d")
    stamp = (
        f"Measured on commit `{args.commit[:12]}` on {date}, with Terraform {args.terraform} on a "
        f"GitHub-hosted `{args.runner}` runner, by this release's own run of `scripts/test.sh`. "
        "The method is under [What we check](#what-we-check)."
    )
    rows = ["| Test subject | Run blocks passed | Failed |", "| --- | --- | --- |"]
    for subject, (passed, failed) in zip(subjects, summaries):
        rows.append(f"| `{subject}` | {passed} | {failed} |")
    total_passed = sum(p for p, _ in summaries)
    total_failed = sum(f for _, f in summaries)
    rows.append(f"| All {len(subjects)} subjects | {total_passed} | {total_failed} |")
    replace_section(DOCS / "testing-and-quality.md", stamp + "\n\n" + "\n".join(rows) + "\n\n"
                    "Coverage and mutation scores are not measured for this release: the gate has no "
                    "coverage or mutation tool for Terraform.")

    replace_section(
        DOCS / "performance.md",
        f"Not measured for this release (commit `{args.commit[:12]}`, {date}): the module creates "
        "resources and runs nothing itself, so it has no throughput or latency of its own to measure. "
        "The engine's numbers are on the "
        "[Pathways performance page](https://docs.cosyte.com/pathways/performance).",
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
