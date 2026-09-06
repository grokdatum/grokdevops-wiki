#!/usr/bin/env python3
"""Mine the grokdevops repo for commands and snippets suitable for typing practice.

Scans Markdown fenced code blocks, shell scripts, Makefiles, and Python files.
Outputs candidate rows as TSV that can be reviewed and merged into cards.tsv.

Usage:
    python3 build_commands.py                    # scan and print candidates
    python3 build_commands.py -o candidates.tsv  # write to file
    python3 build_commands.py --stats            # show category counts only
    python3 build_commands.py --python           # include Python snippet candidates
"""

import argparse
import re
import sys
from collections import Counter
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent.parent.parent
SCRIPT_DIR = Path(__file__).resolve().parent

# Directories to scan
SCAN_DIRS = [
    REPO_ROOT / "training",
    REPO_ROOT / "devops",
    REPO_ROOT / "tools",
    REPO_ROOT / "app",
    REPO_ROOT / "tests",
]
SCAN_FILES = [
    REPO_ROOT / "Makefile",
    REPO_ROOT / "README.md",
    REPO_ROOT / "CLAUDE.md",
    REPO_ROOT / "lab",
]

# Skip patterns
SKIP_DIRS = {"_attic", "__pycache__", ".git", "node_modules", ".terraform"}

# Command prefixes we care about
COMMAND_PREFIXES = [
    "kubectl",
    "helm",
    "docker",
    "terraform",
    "ansible",
    "ansible-playbook",
    "ansible-vault",
    "ansible-galaxy",
    "git",
    "systemctl",
    "journalctl",
    "systemd-analyze",
    "make",
    "python3",
    "pytest",
    "ruff",
    "pip",
    "find",
    "grep",
    "curl",
    "ss",
    "ps",
    "ip",
    "dig",
    "nslookup",
    "tar",
    "chmod",
    "chown",
    "ln",
    "xargs",
    "awk",
    "sed",
    "sort",
    "wc",
    "head",
    "tail",
    "cat",
    "less",
    "more",
    "df",
    "du",
    "free",
    "top",
    "htop",
    "kill",
    "pkill",
    "pgrep",
    "pstree",
    "lsof",
    "netstat",
    "traceroute",
    "ping",
    "mtr",
    "ethtool",
    "arping",
    "tcpdump",
    "iptables",
    "yamllint",
    "bash",
    "sh",
]

# Category mapping from first token
CATEGORY_MAP = {
    "kubectl": "kubectl",
    "helm": "helm",
    "docker": "docker",
    "terraform": "terraform",
    "ansible": "ansible",
    "ansible-playbook": "ansible",
    "ansible-vault": "ansible",
    "ansible-galaxy": "ansible",
    "git": "git",
    "systemctl": "systemd",
    "journalctl": "journalctl",
    "systemd-analyze": "systemd",
    "make": "make",
    "python3": "python",
    "pytest": "python",
    "ruff": "python",
    "pip": "python",
    "find": "linux",
    "grep": "linux",
    "curl": "linux",
    "ss": "linux",
    "ps": "linux",
    "ip": "linux",
    "dig": "linux",
    "nslookup": "linux",
    "tar": "linux",
    "chmod": "linux",
    "pstree": "linux",
    "df": "linux",
    "du": "linux",
    "free": "linux",
    "lsof": "linux",
    "traceroute": "linux",
    "ping": "linux",
    "mtr": "linux",
    "ethtool": "linux",
    "tcpdump": "linux",
    "iptables": "linux",
}


def should_skip(path: Path) -> bool:
    parts = set(path.parts)
    return bool(parts & SKIP_DIRS)


def extract_from_fenced_blocks(text: str, lang: str = "bash") -> list[str]:
    """Extract lines from Markdown fenced code blocks of the given language."""
    results = []
    if lang == "bash":
        pattern = re.compile(
            r"```(?:bash|sh|zsh|shell|console)?\s*\n(.*?)```",
            re.DOTALL | re.IGNORECASE,
        )
    elif lang == "python":
        pattern = re.compile(
            r"```(?:python|py)\s*\n(.*?)```",
            re.DOTALL | re.IGNORECASE,
        )
    else:
        return results

    for match in pattern.finditer(text):
        block = match.group(1)
        for line in block.splitlines():
            line = line.strip()
            if line.startswith("$ "):
                line = line[2:]
            elif line.startswith("# ") and not line.startswith("# !"):
                continue
            if not line or line.startswith("#"):
                continue
            results.append(line)
    return results


def extract_from_script(text: str) -> list[str]:
    commands = []
    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if line in ("then", "else", "fi", "do", "done", "esac", ";;"):
            continue
        if line.startswith("if ") or line.startswith("for "):
            continue
        if line.startswith("echo ") or line.startswith("printf "):
            continue
        commands.append(line)
    return commands


def extract_from_makefile(text: str) -> list[str]:
    commands = []
    for line in text.splitlines():
        if line.startswith("\t"):
            cmd = line.strip().lstrip("@-+")
            if not cmd or cmd.startswith("#") or cmd.startswith("echo"):
                continue
            commands.append(cmd)
    return commands


def extract_python_snippets(text: str) -> list[str]:
    """Extract short Python one-liners from .py files."""
    snippets = []
    for line in text.splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        # Skip imports, class defs, decorators, docstrings
        if stripped.startswith(("import ", "from ", "class ", "@", '"""', "'''")):
            continue
        # Skip too-short or too-long lines
        if len(stripped) < 8 or len(stripped) > 100:
            continue
        # Must look like a Python statement
        if any(
            stripped.startswith(kw)
            for kw in (
                "def ",
                "return ",
                "if ",
                "for ",
                "while ",
                "with ",
                "try:",
                "except",
                "raise ",
                "assert ",
                "print(",
                "result",
                "data",
                "path",
            )
        ):
            snippets.append(stripped)
    return snippets


def classify_command(cmd: str) -> str | None:
    tokens = cmd.split()
    if not tokens:
        return None
    first = tokens[0]
    if first == "sudo" and len(tokens) > 1:
        first = tokens[1]
    if first in COMMAND_PREFIXES:
        return first
    return None


def categorize(cmd: str) -> str:
    first = classify_command(cmd)
    return CATEGORY_MAP.get(first, "other") if first else "other"


def is_useful_command(cmd: str) -> bool:
    if len(cmd) < 4 or len(cmd) > 120:
        return False
    if re.match(r"^[A-Z_]+=", cmd):
        return False
    if cmd.startswith("$") or cmd.startswith("[") or cmd.startswith("test "):
        return False
    return classify_command(cmd) is not None


def normalize_text(cmd: str) -> str:
    return " ".join(cmd.split())


def scan_repo(
    include_python: bool = False,
) -> list[tuple[str, str, str]]:
    """Scan the repo. Returns (text, source_file, type) tuples."""
    results: list[tuple[str, str, str]] = []

    for scan_dir in SCAN_DIRS:
        if not scan_dir.exists():
            continue

        # Markdown files — shell blocks
        for md in scan_dir.rglob("*.md"):
            if should_skip(md):
                continue
            try:
                text = md.read_text(encoding="utf-8", errors="replace")
            except OSError:
                continue
            source = str(md.relative_to(REPO_ROOT))
            for cmd in extract_from_fenced_blocks(text, "bash"):
                results.append((cmd, source, "shell"))
            if include_python:
                for snippet in extract_from_fenced_blocks(text, "python"):
                    results.append((snippet, source, "python"))

        # Shell scripts
        for ext in ("*.sh", "*.bash"):
            for script in scan_dir.rglob(ext):
                if should_skip(script):
                    continue
                try:
                    text = script.read_text(encoding="utf-8", errors="replace")
                except OSError:
                    continue
                source = str(script.relative_to(REPO_ROOT))
                for cmd in extract_from_script(text):
                    results.append((cmd, source, "shell"))

        # Python files
        if include_python:
            for pyfile in scan_dir.rglob("*.py"):
                if should_skip(pyfile):
                    continue
                try:
                    text = pyfile.read_text(encoding="utf-8", errors="replace")
                except OSError:
                    continue
                source = str(pyfile.relative_to(REPO_ROOT))
                for snippet in extract_python_snippets(text):
                    results.append((snippet, source, "python"))

    # Specific files
    for fpath in SCAN_FILES:
        if not fpath.exists():
            continue
        try:
            text = fpath.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        source = fpath.name
        if fpath.name == "Makefile":
            for cmd in extract_from_makefile(text):
                results.append((cmd, source, "shell"))
        else:
            for cmd in extract_from_fenced_blocks(text, "bash"):
                results.append((cmd, source, "shell"))

    return results


def dedupe(
    candidates: list[tuple[str, str, str]],
) -> list[tuple[str, str, str, int]]:
    """Deduplicate. Returns (text, source, type, count)."""
    counts: Counter[str] = Counter()
    sources: dict[str, str] = {}
    types: dict[str, str] = {}
    for text, source, typ in candidates:
        norm = normalize_text(text)
        counts[norm] += 1
        if norm not in sources:
            sources[norm] = source
            types[norm] = typ
    return [(text, sources[text], types[text], count) for text, count in counts.most_common()]


def make_id(text: str, category: str, seen: set[str]) -> str:
    tokens = text.split()[:4]
    slug = "-".join(re.sub(r"[^a-z0-9]", "", t.lower()) for t in tokens if t)
    base_id = f"{category}-{slug}" if slug else f"{category}-item"
    final_id = base_id
    counter = 2
    while final_id in seen:
        final_id = f"{base_id}-{counter}"
        counter += 1
    seen.add(final_id)
    return final_id


def guess_difficulty(text: str) -> str:
    tokens = text.split()
    pipes = text.count("|")
    if pipes > 0 or len(tokens) > 6:
        return "3"
    if len(tokens) > 3:
        return "2"
    return "1"


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Mine repo for commands and snippets for typing practice."
    )
    parser.add_argument(
        "-o",
        "--output",
        type=Path,
        default=None,
        help="write TSV output to file (default: stdout)",
    )
    parser.add_argument(
        "--stats",
        action="store_true",
        help="show category counts only",
    )
    parser.add_argument(
        "--min-count",
        type=int,
        default=1,
        help="minimum occurrence count to include (default: 1)",
    )
    parser.add_argument(
        "--python",
        action="store_true",
        help="also mine Python snippets from .py files and markdown",
    )
    args = parser.parse_args()

    print("Scanning repo...", file=sys.stderr)
    raw = scan_repo(include_python=args.python)
    print(f"  found {len(raw)} raw lines", file=sys.stderr)

    # Filter shell commands for usefulness; keep all python as-is
    useful = []
    for text, src, typ in raw:
        if typ == "shell" and is_useful_command(text):
            useful.append((text, src, typ))
        elif typ == "python":
            useful.append((text, src, typ))
    print(f"  {len(useful)} pass usefulness filter", file=sys.stderr)

    deduped = dedupe(useful)
    print(f"  {len(deduped)} unique items", file=sys.stderr)

    if args.min_count > 1:
        deduped = [(t, s, tp, n) for t, s, tp, n in deduped if n >= args.min_count]
        print(
            f"  {len(deduped)} with count >= {args.min_count}",
            file=sys.stderr,
        )

    if args.stats:
        cat_counts: Counter[str] = Counter()
        for text, _, typ, _ in deduped:
            if typ == "python":
                cat_counts["python"] += 1
            else:
                cat_counts[categorize(text)] += 1
        print("\nCategory breakdown:", file=sys.stderr)
        for cat, count in cat_counts.most_common():
            print(f"  {cat:15s} {count}", file=sys.stderr)
        print(
            f"  {'TOTAL':15s} {sum(cat_counts.values())}",
            file=sys.stderr,
        )
        return

    # Build TSV
    seen_ids: set[str] = set()
    header = "id\tcategory\tdifficulty\ttext\twhat_it_does\tdetails\tsource_hint\ttags"

    out = open(args.output, "w", encoding="utf-8") if args.output else sys.stdout
    try:
        out.write(header + "\n")
        for text, source, typ, count in deduped:
            if typ == "python":
                cat = "python"
            else:
                cat = categorize(text)
            cid = make_id(text, cat, seen_ids)
            diff = guess_difficulty(text)
            out.write(f"{cid}\t{cat}\t{diff}\t{text}\tTODO: describe\tTODO: details\t{source}\t\n")
    finally:
        if args.output:
            out.close()

    dest = args.output or "stdout"
    print(f"\nWrote {len(deduped)} candidates to {dest}", file=sys.stderr)
    print("Review and merge useful rows into cards.tsv", file=sys.stderr)


if __name__ == "__main__":
    main()
