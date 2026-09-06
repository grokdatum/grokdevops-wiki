#!/usr/bin/env python3
"""Typing Trainer — visible-string typing practice for commands and code.

Shows the exact text on screen. You retype it for muscle memory and syntax
familiarity. Repeats until your input matches. Does NOT execute anything.

Usage:
    trainer.py                         # all cards, shuffled
    trainer.py kubectl                 # just kubectl cards
    trainer.py kubectl -d 1 -n 10     # easy kubectl, 10 cards
    trainer.py --review                # practice missed cards first
    trainer.py list                    # list all cards
    trainer.py list kubectl            # list kubectl cards
    trainer.py categories              # show categories with counts
    trainer.py tags                    # show tags with counts
    trainer.py stats                   # full breakdown
    trainer.py progress                # show your missed-card history
"""

import argparse
import csv
import os
import random
import shutil
import sys
from collections import Counter
from pathlib import Path

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------

SCRIPT_DIR = Path(__file__).resolve().parent
DEFAULT_TSV = SCRIPT_DIR / "cards.tsv"
STATE_DIR = (
    Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local" / "state")) / "command-typing"
)
STATE_FILE = STATE_DIR / "progress.tsv"

# Subcommand names (reserved words that can't be used as category filters)
SUBCOMMANDS = {"list", "categories", "tags", "stats", "progress"}

# ---------------------------------------------------------------------------
# Terminal width and color
# ---------------------------------------------------------------------------


def term_width() -> int:
    """Get terminal width, default 80."""
    return shutil.get_terminal_size((80, 24)).columns


def supports_color() -> bool:
    """Check if stdout supports ANSI color."""
    if os.environ.get("NO_COLOR"):
        return False
    if not hasattr(sys.stdout, "isatty"):
        return False
    return sys.stdout.isatty()


class C:
    """ANSI color codes, auto-disabled when not supported."""

    RESET = ""
    BOLD = ""
    DIM = ""
    CYAN = ""
    GREEN = ""
    YELLOW = ""
    RED = ""
    MAGENTA = ""
    WHITE = ""
    BLUE = ""

    @classmethod
    def enable(cls) -> None:
        cls.RESET = "\033[0m"
        cls.BOLD = "\033[1m"
        cls.DIM = "\033[2m"
        cls.CYAN = "\033[36m"
        cls.GREEN = "\033[32m"
        cls.YELLOW = "\033[33m"
        cls.RED = "\033[31m"
        cls.MAGENTA = "\033[35m"
        cls.WHITE = "\033[37m"
        cls.BLUE = "\033[34m"


# ---------------------------------------------------------------------------
# Normalization and matching
# ---------------------------------------------------------------------------


def normalize(text: str) -> str:
    """Normalize whitespace: strip and collapse internal spaces."""
    return " ".join(text.split())


def find_mismatch(expected: str, actual: str) -> str:
    """Return a brief description of where the first mismatch is."""
    exp_tokens = expected.split()
    act_tokens = actual.split()
    for i, (e, a) in enumerate(zip(exp_tokens, act_tokens)):
        if e != a:
            return f"  mismatch at token {i + 1}: expected '{e}', got '{a}'"
    if len(act_tokens) < len(exp_tokens):
        missing = exp_tokens[len(act_tokens)]
        return f"  missing token(s) starting at: '{missing}'"
    if len(act_tokens) > len(exp_tokens):
        return f"  extra token(s) starting at: '{act_tokens[len(exp_tokens)]}'"
    return "  (unknown difference)"


# ---------------------------------------------------------------------------
# Data loading
# ---------------------------------------------------------------------------


def load_cards(path: Path) -> list[dict]:
    """Load typing cards from a TSV file."""
    cards = []
    with open(path, newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f, delimiter="\t")
        for row in reader:
            row = {k.strip(): v.strip() for k, v in row.items() if k}
            if row.get("text", ""):
                cards.append(row)
    return cards


def filter_cards(
    cards: list[dict],
    category: str | None = None,
    difficulty: str | None = None,
    tags: str | None = None,
) -> list[dict]:
    """Filter cards by category, difficulty, or tag."""
    result = cards
    if category:
        cats = {c.strip().lower() for c in category.split(",")}
        result = [c for c in result if c.get("category", "").lower() in cats]
    if difficulty:
        diffs = {d.strip() for d in difficulty.split(",")}
        result = [c for c in result if c.get("difficulty", "") in diffs]
    if tags:
        tag_set = {t.strip().lower() for t in tags.split(",")}
        result = [
            c for c in result if tag_set & {t.strip().lower() for t in c.get("tags", "").split(",")}
        ]
    return result


# ---------------------------------------------------------------------------
# State (missed cards tracking)
# ---------------------------------------------------------------------------


def load_missed() -> dict[str, int]:
    """Load missed-card counts from state file."""
    missed: dict[str, int] = {}
    if STATE_FILE.exists():
        with open(STATE_FILE, encoding="utf-8") as f:
            reader = csv.DictReader(f, delimiter="\t")
            for row in reader:
                cid = row.get("id", "").strip()
                count = int(row.get("missed", "0"))
                if cid:
                    missed[cid] = count
    return missed


def save_missed(missed: dict[str, int]) -> None:
    """Save missed-card counts to state file."""
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    with open(STATE_FILE, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f, delimiter="\t")
        writer.writerow(["id", "missed"])
        for cid, count in sorted(missed.items()):
            writer.writerow([cid, count])


def sort_missed_first(cards: list[dict], missed: dict[str, int]) -> list[dict]:
    """Sort cards so frequently missed ones come first."""
    return sorted(cards, key=lambda c: -missed.get(c.get("id", ""), 0))


# ---------------------------------------------------------------------------
# Display
# ---------------------------------------------------------------------------


def separator(char: str = "-") -> str:
    return char * term_width()


def show_card(card: dict, index: int, total: int) -> None:
    """Display a typing card with the visible target string."""
    w = term_width()
    cat = card.get("category", "?")
    diff = card.get("difficulty", "?")
    header = f"  Card {index}/{total}"
    meta = f"{cat} | difficulty {diff}"
    pad = max(w - len(header) - len(meta) - 2, 2)

    print(f"\n{C.DIM}{separator()}{C.RESET}")
    print(f"{C.BOLD}{header}{C.RESET}{' ' * pad}{C.DIM}{meta}{C.RESET}")
    print(f"{C.DIM}{separator()}{C.RESET}")
    print()
    print(f"  {C.BOLD}{C.CYAN}Type this:  {C.GREEN}{card['text']}{C.RESET}")
    print()
    print(f"  {C.DIM}What:       {C.RESET}{card.get('what_it_does', '?')}")
    print(f"  {C.DIM}Details:    {C.RESET}{card.get('details', '')}")
    print(f"  {C.DIM}Source:     {C.RESET}{card.get('source_hint', '?')}")
    print(f"{C.DIM}{separator()}{C.RESET}")


def show_summary(
    total: int,
    correct_first: int,
    skipped: int,
    session_missed: dict[str, int],
) -> None:
    """Show end-of-session summary."""
    print(f"\n{C.BOLD}{separator('=')}{C.RESET}")
    print(f"  {C.BOLD}SESSION COMPLETE{C.RESET}")
    print(f"{C.BOLD}{separator('=')}{C.RESET}")
    print(f"  Cards attempted:   {C.BOLD}{total}{C.RESET}")
    print(f"  Clean on first:    {C.GREEN}{correct_first}{C.RESET}")
    print(f"  Skipped:           {skipped}")
    if session_missed:
        print(f"  Needed retries:    {C.YELLOW}{len(session_missed)}{C.RESET}")
        top = sorted(session_missed.items(), key=lambda x: -x[1])[:5]
        print("  Most retried:")
        for cid, count in top:
            print(f"    {C.DIM}{cid}:{C.RESET} {count} attempt(s)")
    print(f"{C.BOLD}{separator('=')}{C.RESET}\n")


# ---------------------------------------------------------------------------
# Practice loop
# ---------------------------------------------------------------------------


def run_practice(cards: list[dict], shuffle: bool, review: bool) -> None:
    """Run the interactive training session."""
    if not cards:
        print("No cards match your filters. Try broader options.")
        sys.exit(1)

    missed_state = load_missed()

    if review:
        cards = sort_missed_first(cards, missed_state)
    elif shuffle:
        random.shuffle(cards)

    total = len(cards)
    correct_first = 0
    skipped = 0
    session_missed: dict[str, int] = {}

    print(f"\n  {C.BOLD}Typing Trainer{C.RESET}")
    print(f"  {total} card(s) loaded")
    print(f"  Retype each line exactly as shown.  {C.DIM}Commands: :quit :skip :show{C.RESET}")
    print()

    for i, card in enumerate(cards, 1):
        expected = normalize(card["text"])
        show_card(card, i, total)
        first_attempt = True

        while True:
            try:
                answer = input(f"  {C.CYAN}retype>{C.RESET} ")
            except (EOFError, KeyboardInterrupt):
                print("\n")
                show_summary(total, correct_first, skipped, session_missed)
                save_missed(missed_state)
                sys.exit(0)

            stripped = answer.strip()

            if stripped == ":quit":
                show_summary(i - 1, correct_first, skipped, session_missed)
                save_missed(missed_state)
                sys.exit(0)

            if stripped == ":skip":
                skipped += 1
                print("  skipped.")
                break

            if stripped in (":show", ":hint"):
                print(f"  {C.CYAN}target:{C.RESET} {C.GREEN}{card['text']}{C.RESET}")
                continue

            normalized = normalize(stripped)

            if normalized == expected:
                print(f"  {C.GREEN}matched!{C.RESET}")
                if first_attempt:
                    correct_first += 1
                break
            else:
                cid = card.get("id", f"unknown-{i}")
                session_missed[cid] = session_missed.get(cid, 0) + 1
                missed_state[cid] = missed_state.get(cid, 0) + 1
                first_attempt = False
                print(f"  {C.YELLOW}not quite.{C.RESET}")
                print(f"{C.DIM}{find_mismatch(expected, normalized)}{C.RESET}")
                print("  retype the visible text.\n")

    show_summary(total, correct_first, skipped, session_missed)
    save_missed(missed_state)


# ---------------------------------------------------------------------------
# Info subcommands
# ---------------------------------------------------------------------------


def cmd_list(cards: list[dict]) -> None:
    """List matching cards."""
    for card in cards:
        print(
            f"{card.get('id', '?'):30s}  "
            f"{card.get('category', '?'):12s}  "
            f"{card.get('difficulty', '?'):2s}  {card['text']}"
        )
    print(f"\n{len(cards)} card(s)")


def cmd_categories(cards: list[dict]) -> None:
    """Show categories with counts."""
    counts: Counter[str] = Counter(c.get("category", "?") for c in cards)
    print(f"\n  {'Category':<16s} {'Cards':>5s}")
    print(f"  {'-' * 22}")
    for cat, count in sorted(counts.items(), key=lambda x: -x[1]):
        print(f"  {cat:<16s} {count:>5d}")
    print(f"  {'-' * 22}")
    print(f"  {'TOTAL':<16s} {len(cards):>5d}\n")


def cmd_tags(cards: list[dict]) -> None:
    """Show tags with counts."""
    counts: Counter[str] = Counter()
    for card in cards:
        for t in card.get("tags", "").split(","):
            t = t.strip()
            if t:
                counts[t] += 1
    print(f"\n  {'Tag':<24s} {'Cards':>5s}")
    print(f"  {'-' * 30}")
    for tag, count in sorted(counts.items(), key=lambda x: -x[1]):
        print(f"  {tag:<24s} {count:>5d}")
    print(f"\n  {len(counts)} tag(s)\n")


def cmd_stats(cards: list[dict]) -> None:
    """Show breakdown by category and difficulty."""
    # Build matrix
    cat_diff: dict[str, Counter[str]] = {}
    for card in cards:
        cat = card.get("category", "?")
        diff = card.get("difficulty", "?")
        if cat not in cat_diff:
            cat_diff[cat] = Counter()
        cat_diff[cat][diff] += 1

    diffs = sorted({d for c in cat_diff.values() for d in c})
    diff_labels = {d: f"D{d}" for d in diffs}

    header = f"  {'Category':<16s}" + "".join(f" {diff_labels[d]:>5s}" for d in diffs)
    header += f" {'Total':>6s}"
    print(f"\n{header}")
    print(f"  {'-' * (16 + 6 * len(diffs) + 7)}")

    totals: Counter[str] = Counter()
    cat_order = sorted(cat_diff.keys(), key=lambda k: -sum(cat_diff[k].values()))
    for cat in cat_order:
        row_total = sum(cat_diff[cat].values())
        row = f"  {cat:<16s}"
        for d in diffs:
            count = cat_diff[cat].get(d, 0)
            totals[d] += count
            row += f" {count:>5d}"
        row += f" {row_total:>6d}"
        print(row)

    grand = sum(totals.values())
    footer = f"  {'TOTAL':<16s}" + "".join(f" {totals[d]:>5d}" for d in diffs)
    footer += f" {grand:>6d}"
    print(f"  {'-' * (16 + 6 * len(diffs) + 7)}")
    print(f"{footer}\n")


def cmd_progress() -> None:
    """Show missed-card history."""
    missed = load_missed()
    if not missed:
        print("\n  No practice history yet. Start with: trainer.py\n")
        return

    total_misses = sum(missed.values())
    top = sorted(missed.items(), key=lambda x: -x[1])

    print(f"\n  {C.BOLD}Practice Progress{C.RESET}")
    print(f"  {'-' * 40}")
    print(f"  Cards practiced:    {len(missed)}")
    print(f"  Total misses:       {total_misses}")
    print()
    print(f"  {C.BOLD}Most-missed cards:{C.RESET}")
    for cid, count in top[:15]:
        bar = "#" * min(count, 20)
        print(f"    {cid:30s}  {count:>3d}  {C.YELLOW}{bar}{C.RESET}")
    if len(top) > 15:
        print(f"    ... and {len(top) - 15} more")
    print()


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

# Shared filter arguments used by both 'practice' (default) and 'list'
FILTER_ARGS = [
    (
        ["-d", "--difficulty"],
        {"type": str, "default": None, "help": "filter by difficulty (1,2,3)"},
    ),
    (
        ["-t", "--tags"],
        {
            "type": str,
            "default": None,
            "help": "filter by tags (comma-separated, e.g. k8s-daily,systemd-debug)",
        },
    ),
    (
        ["-n", "--limit"],
        {"type": int, "default": None, "help": "limit to N cards"},
    ),
    (
        ["-f", "--file"],
        {
            "type": Path,
            "default": DEFAULT_TSV,
            "help": "path to cards TSV (default: cards.tsv)",
        },
    ),
]


def add_filter_args(parser: argparse.ArgumentParser) -> None:
    for flags, kwargs in FILTER_ARGS:
        parser.add_argument(*flags, **kwargs)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Typing Trainer — visible-string practice for commands and code.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=(
            "examples:\n"
            "  trainer.py kubectl              practice kubectl cards\n"
            "  trainer.py kubectl -d 1 -n 10   easy kubectl, 10 cards\n"
            "  trainer.py -t k8s-debug         practice by tag\n"
            "  trainer.py --review             missed cards first\n"
            "  trainer.py list                 list all cards\n"
            "  trainer.py list kubectl          list kubectl cards\n"
            "  trainer.py categories           show categories\n"
            "  trainer.py tags                 show tags\n"
            "  trainer.py stats                full breakdown\n"
            "  trainer.py progress             your history\n"
        ),
    )
    parser.add_argument("--no-color", action="store_true", help="disable color")
    parser.add_argument(
        "positional",
        nargs="*",
        default=[],
        help="command (list|categories|tags|stats|progress) or category filter",
    )
    add_filter_args(parser)
    parser.add_argument("--review", action="store_true", help="practice missed cards first")
    parser.add_argument("--ordered", action="store_true", help="present cards in file order")

    return parser


def main() -> None:
    parser = build_parser()
    args = parser.parse_args()

    if not args.no_color and supports_color():
        C.enable()

    # Parse positional args into command and category
    positional = args.positional
    command = None
    category = None

    if positional and positional[0] in SUBCOMMANDS:
        command = positional[0]
        category = positional[1] if len(positional) > 1 else None
    elif positional:
        category = positional[0]

    # Subcommands that don't need cards
    if command == "progress":
        cmd_progress()
        return

    # Load cards for everything else
    tsv_path = args.file
    cards = load_cards(tsv_path)

    if command == "categories":
        cmd_categories(cards)
        return

    if command == "tags":
        cmd_tags(cards)
        return

    if command == "stats":
        cmd_stats(cards)
        return

    # Apply filters (list and practice both use them)
    cards = filter_cards(cards, category=category, difficulty=args.difficulty, tags=args.tags)

    if command == "list":
        cmd_list(cards)
        return

    # Default: practice
    shuffle = not args.ordered and not args.review

    if args.limit and args.limit > 0:
        if shuffle:
            random.shuffle(cards)
        cards = cards[: args.limit]

    run_practice(cards, shuffle=shuffle, review=args.review)


if __name__ == "__main__":
    main()
