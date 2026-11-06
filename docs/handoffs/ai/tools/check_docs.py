#!/usr/bin/env python3
"""check_docs.py -- alpbahOS documentation consistency checker (stdlib-only).

Catches living documents that fall behind the project. Rules:

  stale-term   Living documents (CLAUDE.md, CURRENT.md, README.md, docs/MASTER_PLAN.md,
               docs/DECISIONS.md, docs/BACKLOG.md) must not use terms of retired
               decisions: Codex (D100), Hyper-V (D106), Windows paths C:\\alpbahOS
               (D104), AGENTS.md (D101), pacman/libalpm (D122). A line carrying
               historical or superseded context ("historical", "removed", "v1",
               "no longer", "instead of", ...) is not reported. Lines inside
               fenced code blocks are skipped. Files under docs/archive/ are
               frozen snapshots and are not checked for stale terms.
  commit-ref   Git object hashes (7-12 or 40 hex digits) in backticks must exist
               in this repository (`git cat-file`). Lines that mention
               alpbahOS-alp are skipped (other repository).
  broken-link  Relative Markdown link targets must exist. Not checked for files
               under docs/archive/ (moved snapshots, links point to the old layout).
  decision-ref Decision IDs (D01..D143, P01..P13, 2 or 3 digits) must be defined
               in docs/DECISIONS.md or docs/archive/DECISIONS-v1.md. The two
               decision files themselves are not checked for this rule.

Historical records (docs/handoffs/, docs/verification/, docs/WORKLOG.md,
docs/archive/) are not living documents, so stale-term does not apply to them.
commit-ref and decision-ref still apply to them.

To exempt a line on purpose, add `<!-- doccheck: ok -->` to that line.

Usage:
    python check_docs.py                # repository root: git rev-parse
    python check_docs.py --repo .
    python check_docs.py --rule stale-term --rule commit-ref

Exit code: 0 when there are no findings, 1 when there are findings,
2 on usage or environment error.
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

# Living documents: they describe the current state and rules, so they must not
# contain obsolete wording.
LIVING_DOCS = {"CLAUDE.md", "CURRENT.md", "README.md", "docs/MASTER_PLAN.md", "docs/DECISIONS.md", "docs/BACKLOG.md"}

# Current and archived decision records. Decision IDs are defined here.
DECISION_FILES = ("docs/DECISIONS.md", "docs/archive/DECISIONS-v1.md")

# Frozen snapshots: skipped by the broken-link and stale-term rules.
ARCHIVE_PREFIX = "docs/archive/"

STALE_TERMS = [
    (re.compile(r"\bcodex\b", re.I), "Codex was removed from the project (D100)"),
    (re.compile(r"\bHyper-V\b", re.I), "test environment is Fedora + QEMU (D106); Hyper-V is historical"),
    (re.compile(r"C:\\alpbahOS", re.I), "Windows paths are historical (D104)"),
    (re.compile(r"\bAGENTS\.md\b"), "AGENTS.md was merged into CLAUDE.md (D101)"),
    (re.compile(r"\b(pacman|libalpm)\b", re.I), "package engine is alp (D122)"),
]

# A line containing one of these is treated as historical or superseded context.
HISTORICAL_MARKERS = re.compile(
    r"tarihsel|terk edildi|bırakıldı|~~|kapsam dışı|uygulanmayacak|olmayacak|vaat edilmez"
    r"|yerine|eskiden|artık|değil|doccheck: ok"
    r"|historical|archive|archived|removed|dropped|superseded|replaced|formerly|no longer|instead of|not a target"
    r"|\bv1\b",
    re.I,
)

# Hashes that belong to another repository are not looked up here.
OTHER_REPO_MARKERS = re.compile(r"alpbahOS-alp", re.I)

COMMIT_IN_BACKTICKS = re.compile(r"`([0-9a-f]{7,12}|[0-9a-f]{40})`")
MD_LINK = re.compile(r"\[[^\]]*\]\(([^)\s]+)\)")
DECISION_ID = re.compile(r"\b([DP]\d{2,3})\b")
DECISION_DEF = re.compile(r"^\|\s*([DP]\d{2,3})\s*\|", re.M)


@dataclass
class Finding:
    path: str
    line: int
    rule: str
    message: str

    def __str__(self) -> str:
        return f"{self.path}:{self.line}: [{self.rule}] {self.message}"


def repo_root(start: Path) -> Path:
    try:
        out = subprocess.run(
            ["git", "-C", str(start), "rev-parse", "--show-toplevel"],
            capture_output=True, text=True, check=True,
        ).stdout.strip()
    except (FileNotFoundError, subprocess.CalledProcessError) as exc:
        print(f"check_docs: git repository not found ({start}): {exc}", file=sys.stderr)
        raise SystemExit(2) from None
    return Path(out)


def tracked_markdown(root: Path) -> list[str]:
    out = subprocess.run(
        ["git", "-C", str(root), "ls-files", "*.md"],
        capture_output=True, text=True, check=True,
    ).stdout
    return sorted(line for line in out.splitlines() if line)


def object_exists(root: Path, sha: str, cache: dict[str, bool]) -> bool:
    """Commit, blob or tree: documents refer to all three."""
    if sha not in cache:
        result = subprocess.run(
            ["git", "-C", str(root), "cat-file", "-e", sha],
            capture_output=True,
        )
        cache[sha] = result.returncode == 0
    return cache[sha]


def in_code_fence(lines: list[str]) -> list[bool]:
    flags, inside = [], False
    for line in lines:
        if line.lstrip().startswith("```"):
            flags.append(True)
            inside = not inside
        else:
            flags.append(inside)
    return flags


def check_file(root: Path, rel: str, rules: set[str], defined_ids: set[str], commit_cache: dict[str, bool]) -> list[Finding]:
    text = (root / rel).read_text(encoding="utf-8")
    lines = text.splitlines()
    fenced = in_code_fence(lines)
    findings: list[Finding] = []
    is_living = rel in LIVING_DOCS
    is_archived = rel.startswith(ARCHIVE_PREFIX)

    for no, line in enumerate(lines, start=1):
        if "doccheck: ok" in line:
            continue

        if "stale-term" in rules and is_living and not is_archived and not fenced[no - 1] and not HISTORICAL_MARKERS.search(line):
            for pattern, reason in STALE_TERMS:
                m = pattern.search(line)
                if m:
                    findings.append(Finding(rel, no, "stale-term", f"'{m.group(0)}': {reason}"))
                    break

        if "commit-ref" in rules and not OTHER_REPO_MARKERS.search(line):
            for sha in COMMIT_IN_BACKTICKS.findall(line):
                if not object_exists(root, sha, commit_cache):
                    findings.append(Finding(rel, no, "commit-ref", f"git object {sha} does not exist in this repository"))

        if "broken-link" in rules and not is_archived and not fenced[no - 1]:
            for target in MD_LINK.findall(line):
                if re.match(r"^[a-z][a-z0-9+.-]*:", target, re.I) or target.startswith("#"):
                    continue  # http:, mailto:, anchor
                path_part = target.split("#", 1)[0]
                path_part = re.sub(r":\d+$", "", path_part)  # file.py:42 form
                if path_part and not (root / rel).parent.joinpath(path_part).exists():
                    findings.append(Finding(rel, no, "broken-link", f"link target does not exist: {target}"))

        if "decision-ref" in rules and rel not in DECISION_FILES and not fenced[no - 1]:
            for ident in DECISION_ID.findall(line):
                if ident not in defined_ids:
                    findings.append(Finding(rel, no, "decision-ref", f"{ident} is not defined in docs/DECISIONS.md or docs/archive/DECISIONS-v1.md"))

    return findings


ALL_RULES = ("stale-term", "commit-ref", "broken-link", "decision-ref")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="alpbahOS documentation consistency check")
    parser.add_argument("--repo", default=".", help="any path inside the repository (default: .)")
    parser.add_argument("--rule", action="append", choices=ALL_RULES, help="run only these rule(s)")
    args = parser.parse_args(argv)

    root = repo_root(Path(args.repo).resolve())
    rules = set(args.rule or ALL_RULES)
    defined_ids: set[str] = set()
    for rel_decisions in DECISION_FILES:
        decisions = root / rel_decisions
        if decisions.exists():
            defined_ids |= set(DECISION_DEF.findall(decisions.read_text(encoding="utf-8")))
    if "decision-ref" in rules and not defined_ids:
        print("check_docs: no decision IDs found in docs/DECISIONS.md or docs/archive/DECISIONS-v1.md; decision-ref skipped", file=sys.stderr)
        rules.discard("decision-ref")

    commit_cache: dict[str, bool] = {}
    findings: list[Finding] = []
    for rel in tracked_markdown(root):
        findings.extend(check_file(root, rel, rules, defined_ids, commit_cache))

    for f in findings:
        print(f)
    counts = {r: sum(1 for f in findings if f.rule == r) for r in sorted(rules)}
    summary = ", ".join(f"{r}={n}" for r, n in counts.items())
    print(f"\ncheck_docs: {len(findings)} finding(s) ({summary})", file=sys.stderr)
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main())
