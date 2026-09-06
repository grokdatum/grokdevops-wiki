"""
flashcard - Manage DevOps/SRE interview questions

Unix-style command for managing interview questions like flashcards.
Questions are stored as canonical TSV files per category under data/cards/.

Usage:
    flashcard list [CATEGORY] [-s|-l] [-d DIFF] [--limit N]
    flashcard show ID               # Show a question with answer
    flashcard random [-c CATEGORY] [-s|-l] [-d DIFF]
    flashcard quiz [-c CATEGORY] [-s|-l] [-d DIFF] [-n COUNT]
    flashcard add CATEGORY          # Add a new question
    flashcard categories            # List all categories
    flashcard edit ID               # Edit a question in $EDITOR
    flashcard search TERM           # Search questions

Filtering options:
    -s, --smallest   Sort by shortest content (simplest questions)
    -l, --largest    Sort by longest content (complex questions)
    -d, --difficulty Filter by difficulty: easy, medium, hard
    --limit N        Limit results to N questions (list only)

Data format:
    Canonical TSV files in data/cards/<category>.tsv
    Fields: id, category, difficulty, tags, question, answer, source_path

Subcommands:
    list       - List questions (optionally filtered by category)
    show       - Show a specific question with answer
    random     - Show a random question (hide answer by default)
    quiz       - Interactive quiz session
    add        - Add a new question interactively
    categories - List available categories
    edit       - Edit a question in $EDITOR
    search     - Search questions by keyword
"""

import argparse
import csv
import hashlib
import os
import random as random_module
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path


# --- ANSI color helpers (auto-disabled when piped) ---
def _use_color() -> bool:
    """Return True if stdout is a terminal (not piped/redirected)."""
    return hasattr(sys.stdout, "isatty") and sys.stdout.isatty()


_RESET = "\033[0m"
_BOLD = "\033[1m"
_CYAN = "\033[36m"  # question label
_GREEN = "\033[32m"  # answer label
_DIM = "\033[2m"  # separators


def _q_label() -> str:
    """Return styled 'QUESTION:' header."""
    if not _use_color():
        return "QUESTION:"
    return f"{_BOLD}{_CYAN}QUESTION:{_RESET}"


def _a_label() -> str:
    """Return styled 'ANSWER:' header."""
    if not _use_color():
        return "ANSWER:"
    return f"{_BOLD}{_GREEN}ANSWER:{_RESET}"


def _separator() -> str:
    """Return styled separator line."""
    line = "-" * 40
    if not _use_color():
        return line
    return f"{_DIM}{line}{_RESET}"


def _answer_text(text: str) -> str:
    """Return answer text in green when color is available."""
    if not _use_color():
        return text
    return f"{_GREEN}{text}{_RESET}"


# Canonical TSV cards directory - source of truth
_lib_dir = Path(__file__).parent  # projects/knowledge/lib
_project_dir = _lib_dir.parent  # projects/knowledge/
_default_cards_dir = _project_dir / "data" / "cards"

CARDS_DIR = Path(os.environ.get("INTERVIEW_CARDS_DIR", str(_default_cards_dir)))

# TSV field names (must match flashcard-tsv contract)
FIELDS = ["id", "category", "difficulty", "tags", "question", "answer", "source_path"]


@dataclass
class Question:
    """Represents an interview question loaded from canonical TSV."""

    id: str
    category: str
    question: str
    answer: str
    tags: list[str]
    difficulty: str
    source_path: str = ""

    @property
    def file_size(self) -> int:
        """Content length as complexity proxy (replaces legacy file size)."""
        return len(self.question) + len(self.answer)

    @classmethod
    def from_tsv_row(cls, row: dict[str, str]) -> "Question | None":
        """Parse a question from a TSV row dict."""
        question = (row.get("question") or "").strip()
        if not question:
            return None

        category = (row.get("category") or "").strip()
        tags_str = (row.get("tags") or "").strip()
        tags = [t.strip() for t in tags_str.split(",") if t.strip()] if tags_str else []

        return cls(
            id=(row.get("id") or "").strip(),
            category=category,
            question=question,
            answer=(row.get("answer") or "(no answer provided)").strip(),
            tags=tags,
            difficulty=(row.get("difficulty") or "medium").strip(),
            source_path=(row.get("source_path") or "").strip(),
        )


def _load_questions_from_tsv(tsv_path: Path) -> list[Question]:
    """Load all questions from a single category TSV file."""
    questions = []
    try:
        with tsv_path.open(encoding="utf-8", newline="") as fh:
            reader = csv.DictReader(fh, delimiter="\t")
            for row in reader:
                q = Question.from_tsv_row(row)
                if q:
                    questions.append(q)
    except Exception as e:
        print(f"flashcard: warning: could not read {tsv_path}: {e}", file=sys.stderr)
    return questions


def get_categories() -> list[str]:
    """Get list of available categories from TSV files."""
    if not CARDS_DIR.exists():
        return []
    return sorted(
        [
            f.stem
            for f in CARDS_DIR.iterdir()
            if f.is_file() and f.suffix == ".tsv" and not f.name.startswith(".")
        ]
    )


def get_questions(category: str | None = None) -> list[Question]:
    """Get all questions, optionally filtered by category."""
    questions: list[Question] = []

    if not CARDS_DIR.exists():
        return questions

    if category:
        tsv_path = CARDS_DIR / f"{category}.tsv"
        if tsv_path.exists():
            questions.extend(_load_questions_from_tsv(tsv_path))
    else:
        for tsv_path in sorted(CARDS_DIR.glob("*.tsv")):  # lint-ok: INV8 read-only loading
            if not tsv_path.name.startswith("."):
                questions.extend(_load_questions_from_tsv(tsv_path))

    return sorted(questions, key=lambda q: q.id)


def get_question_by_id(qid: str) -> Question | None:
    """Get a question by its ID (category/hash or just hash)."""
    if "/" in qid:
        category, _ = qid.split("/", 1)
        tsv_path = CARDS_DIR / f"{category}.tsv"
        if tsv_path.exists():
            for q in _load_questions_from_tsv(tsv_path):
                if q.id == qid:
                    return q
        return None

    # Search all categories
    for q in get_questions():
        if q.id == qid or q.id.endswith(f"/{qid}"):
            return q
    return None


def filter_questions(questions: list[Question], args) -> list[Question]:
    """Apply common filters: difficulty, smallest/largest sorting."""
    # Filter by difficulty if specified
    difficulty = getattr(args, "difficulty", None)
    if difficulty:
        questions = [q for q in questions if q.difficulty == difficulty]

    # Sort by content length if requested
    if getattr(args, "smallest", False):
        questions = sorted(questions, key=lambda q: q.file_size)
    elif getattr(args, "largest", False):
        questions = sorted(questions, key=lambda q: q.file_size, reverse=True)

    return questions


def flashcard_list(args) -> int:
    """List questions."""
    questions = get_questions(args.category if hasattr(args, "category") else None)

    if not questions:
        if args.category:
            print(f"No questions found in category: {args.category}")
            print(f"\nAvailable categories: {', '.join(get_categories()) or '(none)'}")
        else:
            print("No questions found.")
            print("\nAdd questions with: flashcard add <category>")
            print(f"Cards directory: {CARDS_DIR}")
        return 0

    # Apply filters (difficulty, size sorting)
    questions = filter_questions(questions, args)

    if not questions:
        diff = getattr(args, "difficulty", None)
        print(f"No questions found matching filters (difficulty={diff})")
        return 0

    # Apply limit if specified
    limit = getattr(args, "limit", None)
    if limit and limit < len(questions):
        questions = questions[:limit]

    # Check if we're in a sorted/filtered mode (flat list display)
    size_sorted = getattr(args, "smallest", False) or getattr(args, "largest", False)

    # Group by category if showing all (unless sorted by size, then show flat list)
    if not args.category and not size_sorted:
        by_cat: dict[str, list[Question]] = {}
        for q in questions:
            by_cat.setdefault(q.category, []).append(q)

        for cat in sorted(by_cat.keys()):
            cat_qs = by_cat[cat]
            print(f"\n{cat.upper()} ({len(cat_qs)} questions)")
            print("-" * 40)
            for q in cat_qs:
                diff_marker = {"easy": " ", "medium": "*", "hard": "!"}.get(q.difficulty, " ")
                tags_str = f" [{', '.join(q.tags)}]" if q.tags else ""
                # Truncate question for display
                qtext = q.question.split("\n")[0][:60]
                if len(q.question) > 60:
                    qtext += "..."
                print(f"  {diff_marker} {q.id}: {qtext}{tags_str}")
    else:
        # Show flat list (for single category or size-sorted mode)
        show_size = size_sorted
        if args.category:
            header = f"{args.category.upper()} ({len(questions)} questions)"
        elif getattr(args, "smallest", False):
            header = f"ALL QUESTIONS - smallest first ({len(questions)} questions)"
        elif getattr(args, "largest", False):
            header = f"ALL QUESTIONS - largest first ({len(questions)} questions)"
        else:
            header = f"ALL QUESTIONS ({len(questions)} questions)"
        print(header)
        print("-" * 40)
        for q in questions:
            diff_marker = {"easy": " ", "medium": "*", "hard": "!"}.get(q.difficulty, " ")
            tags_str = f" [{', '.join(q.tags)}]" if q.tags else ""
            qtext = q.question.split("\n")[0][: 50 if show_size else 60]
            if len(q.question) > (50 if show_size else 60):
                qtext += "..."
            if show_size:
                size_str = f" ({q.file_size}B)"
                print(f"  {diff_marker} {q.id}{size_str}: {qtext}{tags_str}")
            else:
                print(f"  {diff_marker} {q.id}: {qtext}{tags_str}")

    print(f"\nTotal: {len(questions)} questions")
    print("Legend: (space)=easy, *=medium, !=hard")
    return 0


def flashcard_show(args) -> int:
    """Show a specific question."""
    q = get_question_by_id(args.id)

    if not q:
        print(f"Question not found: {args.id}", file=sys.stderr)
        return 1

    print(f"ID: {q.id}")
    print(f"Category: {q.category}")
    print(f"Difficulty: {q.difficulty}")
    if q.tags:
        print(f"Tags: {', '.join(q.tags)}")
    print()
    print(_q_label())
    print(_separator())
    print(q.question)
    print()

    if not args.hide_answer:
        print(_a_label())
        print(_separator())
        print(_answer_text(q.answer))
    else:
        print("(Answer hidden - use --show-answer or -a to reveal)")

    return 0


def flashcard_random(args) -> int:
    """Show a random question."""
    questions = get_questions(args.category if hasattr(args, "category") else None)

    if not questions:
        print("No questions available.", file=sys.stderr)
        return 1

    # Apply difficulty filter first
    difficulty = getattr(args, "difficulty", None)
    if difficulty:
        questions = [q for q in questions if q.difficulty == difficulty]
        if not questions:
            print(f"No questions found with difficulty: {difficulty}", file=sys.stderr)
            return 1

    # If --smallest or --largest, pick from the top/bottom 20% (min 10)
    if getattr(args, "smallest", False):
        questions = sorted(questions, key=lambda q: q.file_size)
        pool_size = max(10, len(questions) // 5)
        questions = questions[:pool_size]
    elif getattr(args, "largest", False):
        questions = sorted(questions, key=lambda q: q.file_size, reverse=True)
        pool_size = max(10, len(questions) // 5)
        questions = questions[:pool_size]

    q = random_module.choice(questions)

    print(f"[{q.id}] ({q.difficulty})")
    if q.tags:
        print(f"Tags: {', '.join(q.tags)}")
    print()
    print(_q_label())
    print(_separator())
    print(q.question)
    print()

    if args.show_answer:
        print(_a_label())
        print(_separator())
        print(_answer_text(q.answer))
    else:
        print("(Press Enter to reveal answer, or Ctrl-C to skip)")
        try:
            input()
            print(_a_label())
            print(_separator())
            print(_answer_text(q.answer))
        except (KeyboardInterrupt, EOFError):
            print("\n(Answer hidden)")

    return 0


def flashcard_quiz(args) -> int:
    """Interactive quiz session."""
    questions = get_questions(args.category if hasattr(args, "category") else None)

    if not questions:
        print("No questions available.", file=sys.stderr)
        return 1

    # Apply difficulty filter
    difficulty = getattr(args, "difficulty", None)
    if difficulty:
        questions = [q for q in questions if q.difficulty == difficulty]
        if not questions:
            print(f"No questions found with difficulty: {difficulty}", file=sys.stderr)
            return 1

    # Sort by content length if requested, otherwise shuffle
    if getattr(args, "smallest", False):
        questions = sorted(questions, key=lambda q: q.file_size)
    elif getattr(args, "largest", False):
        questions = sorted(questions, key=lambda q: q.file_size, reverse=True)
    else:
        random_module.shuffle(questions)

    if args.count and args.count < len(questions):
        questions = questions[: args.count]

    print(f"Starting quiz with {len(questions)} questions")
    print("Press Enter to reveal answer, 'n' for next, 'q' to quit")
    print("=" * 50)

    correct = 0
    total = 0

    for i, q in enumerate(questions, 1):
        print(f"\n[{i}/{len(questions)}] {q.id} ({q.difficulty})")
        if q.tags:
            print(f"Tags: {', '.join(q.tags)}")
        print()
        print(_q_label())
        print(_separator())
        print(q.question)
        print()

        try:
            response = input("Press Enter for answer (n=next, q=quit): ").strip().lower()
        except (KeyboardInterrupt, EOFError):
            print("\n\nQuiz ended.")
            break

        if response == "q":
            print("\nQuiz ended.")
            break

        if response == "n":
            total += 1
            continue

        print()
        print(_a_label())
        print(_separator())
        print(_answer_text(q.answer))
        print()

        try:
            self_grade = input("Did you get it right? (y/n/s=skip): ").strip().lower()
        except (KeyboardInterrupt, EOFError):
            print("\n\nQuiz ended.")
            break

        total += 1
        if self_grade == "y":
            correct += 1
            print("Correct!")
        elif self_grade == "s":
            total -= 1
            print("Skipped")
        else:
            print("Keep studying!")

    # Show results
    if total > 0:
        pct = (correct / total) * 100
        print()
        print("=" * 50)
        print(f"Quiz Results: {correct}/{total} ({pct:.0f}%)")

    return 0


def _append_to_tsv(category: str, row: dict) -> None:
    """Append a single row to a category TSV file."""
    CARDS_DIR.mkdir(parents=True, exist_ok=True)
    tsv_path = CARDS_DIR / f"{category}.tsv"

    file_exists = tsv_path.exists() and tsv_path.stat().st_size > 0
    with tsv_path.open("a", encoding="utf-8", newline="") as fh:
        writer = csv.DictWriter(fh, fieldnames=FIELDS, delimiter="\t")
        if not file_exists:
            writer.writeheader()
        writer.writerow(row)


def _rewrite_tsv(category: str, rows: list[dict]) -> None:
    """Rewrite a category TSV file with updated rows."""
    CARDS_DIR.mkdir(parents=True, exist_ok=True)
    tsv_path = CARDS_DIR / f"{category}.tsv"

    with tsv_path.open("w", encoding="utf-8", newline="") as fh:
        writer = csv.DictWriter(fh, fieldnames=FIELDS, delimiter="\t")
        writer.writeheader()
        writer.writerows(rows)


def flashcard_add(args) -> int:
    """Add a new question interactively (writes to canonical TSV)."""
    category = args.category

    print(f"Adding question to: {category}")
    print()

    # Get question
    print("Enter question (end with empty line):")
    question_lines = []
    while True:
        try:
            line = input()
            if not line:
                break
            question_lines.append(line)
        except (KeyboardInterrupt, EOFError):
            print("\nCancelled.")
            return 1

    if not question_lines:
        print("No question entered.", file=sys.stderr)
        return 1

    # Get answer
    print("\nEnter answer (end with empty line):")
    answer_lines = []
    while True:
        try:
            line = input()
            if not line:
                break
            answer_lines.append(line)
        except (KeyboardInterrupt, EOFError):
            print("\nCancelled.")
            return 1

    if not answer_lines:
        print("No answer entered. Refusing to create incomplete flashcard.", file=sys.stderr)
        return 1

    # Get optional metadata
    print("\nTags (comma-separated, or empty):")
    try:
        tags_input = input().strip()
    except (KeyboardInterrupt, EOFError):
        tags_input = ""

    print("Difficulty (easy/medium/hard, default=medium):")
    try:
        difficulty = input().strip().lower() or "medium"
    except (KeyboardInterrupt, EOFError):
        difficulty = "medium"

    question_text = "\n".join(question_lines)
    answer_text = "\n".join(answer_lines)

    # Generate deterministic ID
    digest = hashlib.sha256(f"{category}\n{question_text}\n{answer_text}".encode()).hexdigest()[:12]
    qid = f"{category}/{digest}"

    row = {
        "id": qid,
        "category": category,
        "difficulty": difficulty,
        "tags": tags_input,
        "question": question_text,
        "answer": answer_text,
        "source_path": "",
    }
    _append_to_tsv(category, row)

    print(f"\nQuestion saved: {qid}")
    return 0


def flashcard_categories(args) -> int:
    """List available categories."""
    categories = get_categories()

    if not categories:
        print("No categories found.")
        print(f"\nCards directory: {CARDS_DIR}")
        print("Create a category by adding questions with: flashcard add <category>")
        return 0

    print("Available categories:")
    for cat in categories:
        tsv_path = CARDS_DIR / f"{cat}.tsv"
        count = len(_load_questions_from_tsv(tsv_path))
        print(f"  {cat}: {count} questions")

    return 0


def flashcard_edit(args) -> int:
    """Edit a question in $EDITOR (extracts to temp file, writes back to TSV)."""
    q = get_question_by_id(args.id)

    if not q:
        print(f"Question not found: {args.id}", file=sys.stderr)
        return 1

    # Create temp file with question content in readable format
    content = f"Q: {q.question}\n\nA: {q.answer}\n\n"
    if q.tags:
        content += f"Tags: {', '.join(q.tags)}\n"
    content += f"Difficulty: {q.difficulty}\n"

    with tempfile.NamedTemporaryFile(
        mode="w", suffix=".txt", delete=False, encoding="utf-8"
    ) as tmp:
        tmp.write(content)
        tmp_path = tmp.name

    try:
        editor = os.environ.get("EDITOR", "vi")
        result = subprocess.run([editor, tmp_path])
        if result.returncode != 0:
            return result.returncode

        # Re-read edited content
        edited = Path(tmp_path).read_text(encoding="utf-8")

        # Parse back from Q:/A: format
        import re

        q_match = re.search(r"(?ims)^Q:\s*(.+?)(?:\n\s*\n|\nA:)", edited)
        a_match = re.search(r"(?ims)^A:\s*(.+?)(?:\n\s*\n(?:Tags:|Difficulty:)|\Z)", edited)
        tags_match = re.search(r"(?im)^Tags:\s*(.+)$", edited)
        diff_match = re.search(r"(?im)^Difficulty:\s*(.+)$", edited)

        if not q_match:
            print(
                "flashcard: error: could not parse edited question (missing Q: line)",
                file=sys.stderr,
            )
            return 1

        new_question = q_match.group(1).strip()
        new_answer = a_match.group(1).strip() if a_match else q.answer
        new_tags = tags_match.group(1).strip() if tags_match else ", ".join(q.tags)
        new_difficulty = diff_match.group(1).strip().lower() if diff_match else q.difficulty

        # Update the TSV: load all rows, find and replace, write back
        tsv_path = CARDS_DIR / f"{q.category}.tsv"
        rows = []
        with tsv_path.open(encoding="utf-8", newline="") as fh:
            reader = csv.DictReader(fh, delimiter="\t")
            for row in reader:
                if (row.get("id") or "").strip() == q.id:
                    row["question"] = new_question
                    row["answer"] = new_answer
                    row["tags"] = new_tags
                    row["difficulty"] = new_difficulty
                rows.append(row)

        _rewrite_tsv(q.category, rows)
        print(f"Question updated: {q.id}")

    finally:
        Path(tmp_path).unlink(missing_ok=True)

    return 0


def flashcard_search(args) -> int:
    """Search questions by keyword."""
    term = args.term.lower()
    questions = get_questions(args.category if hasattr(args, "category") else None)

    matches = []
    for q in questions:
        if (
            term in q.question.lower()
            or term in q.answer.lower()
            or any(term in t.lower() for t in q.tags)
        ):
            matches.append(q)

    if not matches:
        print(f"No questions matching: {term}")
        return 0

    print(f"Found {len(matches)} questions matching '{term}':")
    print()

    for q in matches:
        print(f"  {q.id} ({q.difficulty})")
        qtext = q.question.split("\n")[0][:60]
        if len(q.question) > 60:
            qtext += "..."
        print(f"    {qtext}")

    return 0


def main(argv: list | None = None) -> int:
    """Main entry point for flashcard."""
    parser = argparse.ArgumentParser(
        description="Manage DevOps/SRE interview questions like flashcards"
    )
    subparsers = parser.add_subparsers(dest="subcommand", help="Subcommand")

    # list
    p_list = subparsers.add_parser("list", help="List questions")
    p_list.add_argument("category", nargs="?", help="Filter by category")
    size_group_list = p_list.add_mutually_exclusive_group()
    size_group_list.add_argument(
        "--smallest", action="store_true", help="Sort by shortest content (simplest questions)"
    )
    size_group_list.add_argument(
        "--largest", action="store_true", help="Sort by longest content (complex questions)"
    )
    p_list.add_argument(
        "--difficulty", choices=["easy", "medium", "hard"], help="Filter by difficulty level"
    )
    p_list.add_argument("--limit", type=int, help="Limit number of results")
    p_list.set_defaults(func=flashcard_list)

    # show
    p_show = subparsers.add_parser("show", help="Show a specific question")
    p_show.add_argument("id", help="Question ID (category/hash)")
    p_show.add_argument("--hide-answer", action="store_true", help="Hide the answer")
    p_show.set_defaults(func=flashcard_show)

    # random
    p_random = subparsers.add_parser("random", help="Show a random question")
    p_random.add_argument("--category", help="Filter by category")
    p_random.add_argument("--show-answer", action="store_true", help="Show answer immediately")
    size_group_random = p_random.add_mutually_exclusive_group()
    size_group_random.add_argument(
        "--smallest", action="store_true", help="Pick from shortest content (simplest questions)"
    )
    size_group_random.add_argument(
        "--largest", action="store_true", help="Pick from longest content (complex questions)"
    )
    p_random.add_argument(
        "--difficulty", choices=["easy", "medium", "hard"], help="Filter by difficulty level"
    )
    p_random.set_defaults(func=flashcard_random)

    # quiz
    p_quiz = subparsers.add_parser("quiz", help="Interactive quiz session")
    p_quiz.add_argument("--category", help="Filter by category")
    p_quiz.add_argument("--count", type=int, help="Number of questions")
    size_group_quiz = p_quiz.add_mutually_exclusive_group()
    size_group_quiz.add_argument(
        "--smallest", action="store_true", help="Start with shortest content (simplest questions)"
    )
    size_group_quiz.add_argument(
        "--largest", action="store_true", help="Start with longest content (complex questions)"
    )
    p_quiz.add_argument(
        "--difficulty", choices=["easy", "medium", "hard"], help="Filter by difficulty level"
    )
    p_quiz.set_defaults(func=flashcard_quiz)

    # add
    p_add = subparsers.add_parser("add", help="Add a new question")
    p_add.add_argument("category", help="Category for the question")
    p_add.set_defaults(func=flashcard_add)

    # categories
    p_cats = subparsers.add_parser("categories", help="List available categories")
    p_cats.set_defaults(func=flashcard_categories)

    # edit
    p_edit = subparsers.add_parser("edit", help="Edit a question in $EDITOR")
    p_edit.add_argument("id", help="Question ID to edit")
    p_edit.set_defaults(func=flashcard_edit)

    # search
    p_search = subparsers.add_parser("search", help="Search questions")
    p_search.add_argument("term", help="Search term")
    p_search.add_argument("--category", help="Filter by category")
    p_search.set_defaults(func=flashcard_search)

    args = parser.parse_args(argv)

    if not hasattr(args, "func"):
        parser.print_help()
        return 1

    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
