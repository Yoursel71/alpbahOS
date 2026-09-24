#!/usr/bin/env python3
"""check_docs.py -- alpbahOS belge tutarlılık denetimi (stdlib-only).

Belgelerin ilerlemenin gerisinde kalmasını erken yakalar. Denetimler:

  stale-term   Yaşayan belgelerde (durum/plan/kural belgeleri) artık geçersiz
               kararlara ait ifadeler: LFS/BLFS 13.1 (D33), pacman/libalpm ve
               Discover/PackageKit alpm (D31), multilib/32-bit (D32). Satır
               tarihsel/iptal bağlamı taşıyorsa ("tarihsel", "terk edildi",
               "~~", "kapsam dışı", D31/D32/D33 referansı...) sayılmaz.
  commit-ref   Backtick içindeki 7-12 ya da 40 haneli git nesne (commit/blob) hash'leri bu
               repoda var mı (`git cat-file`); alpbahOS-alp satırları atlanır.
  broken-link  Göreli Markdown bağlantılarının hedef dosyası var mı.
  decision-ref Belgelerde geçen D01..Dnn / P01..Pnn kimlikleri DECISIONS.md'de
               tanımlı mı.

WORKLOG ve devir belgeleri (docs/handoffs/) tarih sıralı kayıt olduğu için
stale-term denetiminden muaftır; diğer denetimler onlara da uygulanır.

Bir satırı bilinçli olarak muaf tutmak için satıra
`<!-- doccheck: ok -->` ekleyin.

Kullanım:
    python check_docs.py                # repo kökü: git rev-parse
    python check_docs.py --repo C:\\alpbahOS
    python check_docs.py --rule stale-term --rule commit-ref

Çıkış kodu: bulgu yoksa 0, varsa 1, kullanım/ortam hatasında 2.
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

# Kural belgeleri: güncel durumu/kuralı anlatır, eski ifade taşımamalı.
LIVING_DOCS = {
    "AGENTS.md", "CLAUDE.md", "CURRENT.md", "README.md",
    "docs/MASTER_PLAN.md", "docs/DECISIONS.md", "docs/BACKLOG.md",
    "docs/HYPERV_PLAN.md", "docs/CLAUDE_START.md", "docs/M2_BLFS_MANIFEST.md",
    "docs/AI_ENVIRONMENT_GUIDE.md", "docs/AGENT_STANDING_RULES.md",
}

STALE_TERMS = [
    (re.compile(r"\b13\.1\b"), "LFS/BLFS 13.1 hedefi D33 ile 12.4'e sabitlendi"),
    (re.compile(r"\b(pacman|libalpm|alpm)\b", re.I), "paket motoru D31 ile alp oldu"),
    (re.compile(r"\bDiscover\b"), "Discover/PackageKit alpm yolu D31 ile bırakıldı"),
    (re.compile(r"\bmultilib\b|\b32-bit\b|\blib32\b|\bELF32\b|\bi686\b", re.I), "32-bit/multilib D32 ile kapsam dışı"),
]

# Satırda bunlardan biri varsa eski ifade bilinçli (tarihsel/iptal) sayılır.
HISTORICAL_MARKERS = re.compile(
    r"tarihsel|terk edildi|bırakıldı|~~|kapsam dışı|uygulanmayacak|olmayacak|vaat edilmez"
    r"|\bD3[123]\b|\bP05\b|\bP13\b|\bP01\b|yerine|eskiden|artık|değil|doccheck: ok",
    re.I,
)

# Başka bir depoya ait hash'ler bu depoda aranmaz.
OTHER_REPO_MARKERS = re.compile(r"alpbahOS-alp", re.I)

COMMIT_IN_BACKTICKS = re.compile(r"`([0-9a-f]{7,12}|[0-9a-f]{40})`")
MD_LINK = re.compile(r"\[[^\]]*\]\(([^)\s]+)\)")
DECISION_ID = re.compile(r"\b([DP]\d{2})\b")
DECISION_DEF = re.compile(r"^\|\s*([DP]\d{2})\s*\|", re.M)


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
        print(f"check_docs: git deposu bulunamadı ({start}): {exc}", file=sys.stderr)
        raise SystemExit(2) from None
    return Path(out)


def tracked_markdown(root: Path) -> list[str]:
    out = subprocess.run(
        ["git", "-C", str(root), "ls-files", "*.md"],
        capture_output=True, text=True, check=True,
    ).stdout
    return sorted(line for line in out.splitlines() if line)


def object_exists(root: Path, sha: str, cache: dict[str, bool]) -> bool:
    """Commit, blob ya da tree -- belgeler üçüne de atıf yapıyor."""
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

    for no, line in enumerate(lines, start=1):
        if "doccheck: ok" in line:
            continue

        if "stale-term" in rules and is_living and not fenced[no - 1] and not HISTORICAL_MARKERS.search(line):
            for pattern, reason in STALE_TERMS:
                m = pattern.search(line)
                if m:
                    findings.append(Finding(rel, no, "stale-term", f"'{m.group(0)}': {reason}"))
                    break

        if "commit-ref" in rules and not OTHER_REPO_MARKERS.search(line):
            for sha in COMMIT_IN_BACKTICKS.findall(line):
                if not object_exists(root, sha, commit_cache):
                    findings.append(Finding(rel, no, "commit-ref", f"git nesnesi {sha} bu depoda yok"))

        if "broken-link" in rules and not fenced[no - 1]:
            for target in MD_LINK.findall(line):
                if re.match(r"^[a-z][a-z0-9+.-]*:", target, re.I) or target.startswith("#"):
                    continue  # http:, mailto:, çapa
                path_part = target.split("#", 1)[0]
                path_part = re.sub(r":\d+$", "", path_part)  # file.py:42 biçimi
                if path_part and not (root / rel).parent.joinpath(path_part).exists():
                    findings.append(Finding(rel, no, "broken-link", f"bağlantı hedefi yok: {target}"))

        if "decision-ref" in rules and rel != "docs/DECISIONS.md" and not fenced[no - 1]:
            for ident in DECISION_ID.findall(line):
                if ident not in defined_ids:
                    findings.append(Finding(rel, no, "decision-ref", f"{ident} DECISIONS.md'de tanımlı değil"))

    return findings


ALL_RULES = ("stale-term", "commit-ref", "broken-link", "decision-ref")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="alpbahOS belge tutarlılık denetimi")
    parser.add_argument("--repo", default=".", help="Depo içindeki herhangi bir yol (varsayılan: .)")
    parser.add_argument("--rule", action="append", choices=ALL_RULES, help="Yalnız bu kural(lar)ı çalıştır")
    args = parser.parse_args(argv)

    root = repo_root(Path(args.repo).resolve())
    rules = set(args.rule or ALL_RULES)
    decisions = root / "docs/DECISIONS.md"
    defined_ids = set(DECISION_DEF.findall(decisions.read_text(encoding="utf-8"))) if decisions.exists() else set()
    if "decision-ref" in rules and not defined_ids:
        print("check_docs: docs/DECISIONS.md okunamadı; decision-ref atlandı", file=sys.stderr)
        rules.discard("decision-ref")

    commit_cache: dict[str, bool] = {}
    findings: list[Finding] = []
    for rel in tracked_markdown(root):
        findings.extend(check_file(root, rel, rules, defined_ids, commit_cache))

    for f in findings:
        print(f)
    counts = {r: sum(1 for f in findings if f.rule == r) for r in sorted(rules)}
    summary = ", ".join(f"{r}={n}" for r, n in counts.items())
    print(f"\ncheck_docs: {len(findings)} bulgu ({summary})", file=sys.stderr)
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main())
