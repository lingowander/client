#!/usr/bin/env python3
"""Shared policy helpers (identical copy lives in both repos: client/ and server/).

Stdlib only. Do NOT add third-party imports: CI runs this before any dependency install.
Policy semantics are defined in docs/compliance/license-policy.md (draft, needs counsel review).
"""
from __future__ import annotations

import datetime as dt
import json
import os
import re
import sys
from dataclasses import dataclass, field

# Exact Exhibit B sentence from MPL-2.0 (https://www.mozilla.org/en-US/MPL/2.0/#exhibit-b).
# The curly quotes may be ASCII quotes in the wild, so match both.
EXHIBIT_B_RE = re.compile(
    r"This Source Code Form is\s+[\u201c\"]Incompatible With Secondary Licenses[\u201d\"]",
    re.IGNORECASE,
)
# The standard MPL-2.0 text itself contains the sentence once, inside the Exhibit B section.
MPL_FULL_TEXT_MARK = re.compile(r"Exhibit B\s*-\s*[\u201c\"]Incompatible With Secondary Licenses", re.IGNORECASE)
SCANNABLE_SUFFIXES = (".go", ".dart", ".kt", ".java", ".swift", ".m", ".h", ".c", ".cc", ".cpp", ".rs",
                      ".py", ".js", ".ts", ".md", ".txt", ".rst", "")
BLOCKING_SPDX = {"MPL-2.0-no-copyleft-exception"}  # SPDX id for MPL-2.0 + Exhibit B


@dataclass
class Finding:
    package: str
    version: str
    license: str
    level: str  # allowed | review | forbidden | unknown | blocked
    reason: str = ""
    exception: str = ""

    @property
    def blocking(self) -> bool:
        return self.level in ("forbidden", "unknown", "blocked", "review")  # review == unapproved review


@dataclass
class Policy:
    raw: dict
    allowed: set = field(default_factory=set)
    review: set = field(default_factory=set)
    forbidden: set = field(default_factory=set)

    @classmethod
    def load(cls, path: str) -> "Policy":
        with open(path, encoding="utf-8") as f:
            raw = json.load(f)
        return cls(raw, set(raw["allowed"]), set(raw["review"]), set(raw["forbidden"]))

    def norm(self, lic: str) -> str:
        lic = lic.strip()
        return self.raw.get("aliases", {}).get(lic, lic)

    def classify_id(self, spdx_id: str) -> str:
        spdx_id = self.norm(spdx_id)
        if spdx_id in BLOCKING_SPDX or spdx_id in self.forbidden:
            return "forbidden"
        if spdx_id in self.review:
            return "review"
        if spdx_id in self.allowed:
            return "allowed"
        return "unknown"

    def classify_expr(self, expr: str) -> str:
        """Tiny SPDX-expression evaluator: OR = best choice, AND = worst. No parentheses support:
        anything with parentheses is treated as unknown so a human looks at it."""
        order = ["allowed", "review", "unknown", "forbidden"]
        if "(" in expr or ")" in expr:
            return "unknown"
        or_parts = [p.strip() for p in re.split(r"\s+OR\s+", expr)]
        best = None
        for part in or_parts:
            and_parts = [p.strip() for p in re.split(r"\s+AND\s+", part)]
            worst = max((self.classify_id(p) for p in and_parts), key=order.index)
            if best is None or order.index(worst) < order.index(best):
                best = worst
        return best or "unknown"

    def find_exception(self, package: str, license_: str) -> dict | None:
        today = dt.date.today().isoformat()
        for ex in self.raw.get("exceptions", []):
            if ex.get("package") != package:
                continue
            if ex.get("license") not in (None, "*", license_):
                continue
            if not ex.get("approved_by") or not ex.get("approved_on"):
                continue  # an exception without a named approver does not count
            if ex.get("expires") and ex["expires"] < today:
                continue
            return ex
        return None


def has_exhibit_b(path: str) -> bool:
    try:
        with open(path, "r", encoding="utf-8", errors="ignore") as f:
            text = f.read()
    except OSError:
        return False
    hits = len(EXHIBIT_B_RE.findall(text))
    if hits == 0:
        return False
    if MPL_FULL_TEXT_MARK.search(text):
        return hits > 1  # full MPL text carries exactly one copy of the sentence
    return True


def scan_dir_for_exhibit_b(root: str, max_files: int = 20000) -> list[str]:
    found: list[str] = []
    n = 0
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in (".git", "node_modules", "testdata", ".dart_tool")]
        for fn in filenames:
            n += 1
            if n > max_files:
                return found
            if not fn.lower().endswith(SCANNABLE_SUFFIXES):
                continue
            p = os.path.join(dirpath, fn)
            try:
                if os.path.getsize(p) > 2_000_000:
                    continue
            except OSError:
                continue
            if has_exhibit_b(p):
                found.append(p)
    return found


def evaluate(policy: Policy, package: str, version: str, license_expr: str) -> Finding:
    level = policy.classify_expr(license_expr)
    ex = policy.find_exception(package, license_expr)
    if level == "review":
        if ex:
            return Finding(package, version, license_expr, "allowed", "review approved by exception", ex["approved_by"])
        return Finding(package, version, license_expr, "review", "needs review: add an approved exception")
    if level == "unknown":
        if ex:
            return Finding(package, version, license_expr, "allowed", "unknown license resolved manually", ex["approved_by"])
        return Finding(package, version, license_expr, "unknown", "license not recognised / not in policy")
    if level == "forbidden":
        return Finding(package, version, license_expr, "forbidden", "forbidden license (exceptions are not honoured)")
    return Finding(package, version, license_expr, "allowed")


def write_reports(findings: list[Finding], out_prefix: str, title: str) -> None:
    os.makedirs(os.path.dirname(out_prefix) or ".", exist_ok=True)
    with open(out_prefix + ".json", "w", encoding="utf-8") as f:
        json.dump([x.__dict__ for x in findings], f, ensure_ascii=False, indent=2)
    counts: dict[str, int] = {}
    for x in findings:
        counts[x.level] = counts.get(x.level, 0) + 1
    with open(out_prefix + ".md", "w", encoding="utf-8") as f:
        f.write(f"# {title}\n\n")
        f.write("Summary: " + ", ".join(f"{k}={v}" for k, v in sorted(counts.items())) + "\n\n")
        f.write("| package | version | license | level | note |\n|---|---|---|---|---|\n")
        for x in sorted(findings, key=lambda x: (x.level == "allowed", x.package)):
            f.write(f"| {x.package} | {x.version} | {x.license} | {x.level} | {x.reason} |\n")


def report_and_exit(findings: list[Finding], out_prefix: str, title: str) -> int:
    write_reports(findings, out_prefix, title)
    bad = [x for x in findings if x.blocking]
    for x in bad:
        print(f"::error::{x.level.upper()}: {x.package} {x.version} [{x.license}] - {x.reason}", file=sys.stderr)
    print(f"{len(findings)} packages checked, {len(bad)} blocking. Report: {out_prefix}.md")
    return 1 if bad else 0
