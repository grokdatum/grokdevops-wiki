"""Tests for knowledge Option C: canonical TSV as sole source of truth.

Validates:
- Categories come from TSV files, not txt directories
- Questions load from TSV files without any txt files present
- Import writes to canonical TSV (no txt side effects)
- Question.from_tsv_row() handles edge cases
- Search and show work with TSV data
- flashcard_import_lib reads from TSV for validate/reindex

Invariants considered: #4b (UTF-8), #11 (text is truth), #9 (no unbounded buffering)
"""

import csv
import sys
import tempfile
from pathlib import Path

import pytest

# Add the knowledge lib to the path
_knowledge_root = Path(__file__).resolve().parent.parent
_lib_path = _knowledge_root / "lib"
sys.path.insert(0, str(_lib_path))


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------


@pytest.fixture
def cards_dir(tmp_path):
    """Create a temporary cards directory with sample TSV files."""
    cards = tmp_path / "cards"
    cards.mkdir()

    # linux.tsv - 2 questions
    linux_tsv = cards / "linux.tsv"
    with linux_tsv.open("w", encoding="utf-8", newline="") as fh:
        writer = csv.DictWriter(
            fh,
            fieldnames=[
                "id",
                "category",
                "difficulty",
                "tags",
                "question",
                "answer",
                "source_path",
            ],
            delimiter="\t",
        )
        writer.writeheader()
        writer.writerow(
            {
                "id": "linux/aaa111bbb222",
                "category": "linux",
                "difficulty": "easy",
                "tags": "linux, basics",
                "question": "What command lists files in a directory?",
                "answer": "The ls command lists directory contents.",
                "source_path": "",
            }
        )
        writer.writerow(
            {
                "id": "linux/ccc333ddd444",
                "category": "linux",
                "difficulty": "medium",
                "tags": "linux, processes",
                "question": "How do you list running processes?",
                "answer": "Use ps aux or top to list running processes.",
                "source_path": "",
            }
        )

    # docker.tsv - 1 question
    docker_tsv = cards / "docker.tsv"
    with docker_tsv.open("w", encoding="utf-8", newline="") as fh:
        writer = csv.DictWriter(
            fh,
            fieldnames=[
                "id",
                "category",
                "difficulty",
                "tags",
                "question",
                "answer",
                "source_path",
            ],
            delimiter="\t",
        )
        writer.writeheader()
        writer.writerow(
            {
                "id": "docker/eee555fff666",
                "category": "docker",
                "difficulty": "medium",
                "tags": "docker, containers",
                "question": "What is Docker?",
                "answer": "Docker is a platform for building and running containers.",
                "source_path": "",
            }
        )

    return cards


@pytest.fixture
def patched_flashcard_lib(cards_dir, monkeypatch):
    """Patch flashcard_lib to use the temporary cards directory."""
    import flashcard_lib

    monkeypatch.setattr(flashcard_lib, "CARDS_DIR", cards_dir)
    return flashcard_lib


@pytest.fixture
def patched_import_lib(tmp_path, monkeypatch):
    """Patch flashcard_import_lib to use temporary directories."""
    import flashcard_import_lib

    cards_dir = tmp_path / "cards"
    cards_dir.mkdir()

    data_dir = tmp_path / "data"
    data_dir.mkdir()

    monkeypatch.setattr(flashcard_import_lib, "CARDS_DIR", cards_dir)
    monkeypatch.setattr(flashcard_import_lib, "DATA_DIR", data_dir)
    monkeypatch.setattr(flashcard_import_lib, "CAS_DIR", data_dir / ".cas")
    monkeypatch.setattr(flashcard_import_lib, "REGISTRY_FILE", data_dir / ".import-registry.json")

    return flashcard_import_lib, cards_dir


# ---------------------------------------------------------------------------
# flashcard_lib tests - TSV as sole data source
# ---------------------------------------------------------------------------


class TestGetCategories:
    """Categories come from TSV files, not txt directories."""

    def test_categories_from_tsv_files(self, patched_flashcard_lib):
        lib = patched_flashcard_lib
        cats = lib.get_categories()
        assert cats == ["docker", "linux"]

    def test_empty_cards_dir(self, patched_flashcard_lib, monkeypatch):
        lib = patched_flashcard_lib
        empty = Path(tempfile.mkdtemp()) / "empty"
        empty.mkdir()
        monkeypatch.setattr(lib, "CARDS_DIR", empty)
        assert lib.get_categories() == []

    def test_nonexistent_cards_dir(self, patched_flashcard_lib, monkeypatch):
        lib = patched_flashcard_lib
        monkeypatch.setattr(lib, "CARDS_DIR", Path("/nonexistent/cards"))
        assert lib.get_categories() == []


class TestGetQuestions:
    """Questions are loaded from TSV, not txt."""

    def test_all_questions(self, patched_flashcard_lib):
        lib = patched_flashcard_lib
        questions = lib.get_questions()
        assert len(questions) == 3
        # Should be sorted by id
        ids = [q.id for q in questions]
        assert ids == sorted(ids)

    def test_filter_by_category(self, patched_flashcard_lib):
        lib = patched_flashcard_lib
        questions = lib.get_questions(category="linux")
        assert len(questions) == 2
        assert all(q.category == "linux" for q in questions)

    def test_nonexistent_category(self, patched_flashcard_lib):
        lib = patched_flashcard_lib
        questions = lib.get_questions(category="nonexistent")
        assert questions == []

    def test_question_fields(self, patched_flashcard_lib):
        lib = patched_flashcard_lib
        questions = lib.get_questions(category="docker")
        assert len(questions) == 1
        q = questions[0]
        assert q.id == "docker/eee555fff666"
        assert q.category == "docker"
        assert q.difficulty == "medium"
        assert "docker" in q.tags
        assert "Docker" in q.question
        assert "containers" in q.answer


class TestGetQuestionById:
    """Question lookup by ID works with TSV."""

    def test_lookup_by_full_id(self, patched_flashcard_lib):
        lib = patched_flashcard_lib
        q = lib.get_question_by_id("linux/aaa111bbb222")
        assert q is not None
        assert q.category == "linux"
        assert "lists files" in q.question

    def test_lookup_by_hash_only(self, patched_flashcard_lib):
        lib = patched_flashcard_lib
        q = lib.get_question_by_id("eee555fff666")
        assert q is not None
        assert q.category == "docker"

    def test_lookup_nonexistent(self, patched_flashcard_lib):
        lib = patched_flashcard_lib
        q = lib.get_question_by_id("nonexistent/xyz")
        assert q is None


class TestQuestionFromTsvRow:
    """Question.from_tsv_row handles edge cases."""

    def test_empty_question_returns_none(self, patched_flashcard_lib):
        lib = patched_flashcard_lib
        row = {"id": "x/y", "category": "x", "question": "", "answer": "stuff"}
        assert lib.Question.from_tsv_row(row) is None

    def test_missing_answer_gets_placeholder(self, patched_flashcard_lib):
        lib = patched_flashcard_lib
        row = {"id": "x/y", "category": "x", "question": "What?", "answer": ""}
        q = lib.Question.from_tsv_row(row)
        assert q is not None
        assert q.answer == "(no answer provided)"

    def test_tags_parsed_from_comma_string(self, patched_flashcard_lib):
        lib = patched_flashcard_lib
        row = {
            "id": "x/y",
            "category": "x",
            "question": "Q?",
            "answer": "A",
            "tags": "foo, bar, baz",
        }
        q = lib.Question.from_tsv_row(row)
        assert q.tags == ["foo", "bar", "baz"]

    def test_empty_tags_gives_empty_list(self, patched_flashcard_lib):
        lib = patched_flashcard_lib
        row = {"id": "x/y", "category": "x", "question": "Q?", "answer": "A", "tags": ""}
        q = lib.Question.from_tsv_row(row)
        assert q.tags == []

    def test_missing_difficulty_defaults_medium(self, patched_flashcard_lib):
        lib = patched_flashcard_lib
        row = {"id": "x/y", "category": "x", "question": "Q?", "answer": "A"}
        q = lib.Question.from_tsv_row(row)
        assert q.difficulty == "medium"


class TestFileSize:
    """file_size property uses content length, not filesystem."""

    def test_file_size_is_content_length(self, patched_flashcard_lib):
        lib = patched_flashcard_lib
        q = lib.get_question_by_id("docker/eee555fff666")
        assert q is not None
        expected = len(q.question) + len(q.answer)
        assert q.file_size == expected


class TestSearch:
    """Search works with TSV data."""

    def test_search_in_question(self, patched_flashcard_lib):
        lib = patched_flashcard_lib
        questions = lib.get_questions()
        term = "docker"
        matches = [
            q
            for q in questions
            if term in q.question.lower()
            or term in q.answer.lower()
            or any(term in t.lower() for t in q.tags)
        ]
        assert len(matches) >= 1
        assert any(q.category == "docker" for q in matches)


# ---------------------------------------------------------------------------
# flashcard_import_lib tests - import writes to TSV, no txt
# ---------------------------------------------------------------------------


class TestImportWritesToTsv:
    """import_questions() writes to canonical TSV, never creates txt files."""

    def test_import_creates_tsv_not_txt(self, patched_import_lib):
        lib, cards_dir = patched_import_lib

        cas = lib.QuestionCAS()
        cas._loaded = True
        cas._index = {}

        questions = [
            lib.ParsedQuestion(
                question="What is Kubernetes and why is it useful?",
                answer="Kubernetes is a container orchestration platform.",
                category="kubernetes",
                tags=["kubernetes"],
                difficulty="easy",
                source_file="test.md",
            )
        ]

        result = lib.import_questions(questions, "test-source", cas, dry_run=False, strict=False)

        assert result.added == 1

        # TSV should exist
        tsv_path = cards_dir / "kubernetes.tsv"
        assert tsv_path.exists()

        # Read back
        with tsv_path.open(encoding="utf-8", newline="") as fh:
            rows = list(csv.DictReader(fh, delimiter="\t"))
        assert len(rows) == 1
        assert rows[0]["category"] == "kubernetes"
        assert "Kubernetes" in rows[0]["question"]

        # No txt files anywhere in the temp directory
        txt_files = list(cards_dir.rglob("*.txt"))
        assert txt_files == [], f"Found unexpected txt files: {txt_files}"

    def test_import_dedup_skips_duplicates(self, patched_import_lib):
        lib, cards_dir = patched_import_lib

        cas = lib.QuestionCAS()
        cas._loaded = True
        cas._index = {}

        questions = [
            lib.ParsedQuestion(
                question="What is Kubernetes and why is it useful?",
                answer="Kubernetes is a container orchestration platform.",
                category="kubernetes",
            ),
            lib.ParsedQuestion(
                question="What is Kubernetes and why is it useful?",
                answer="K8s is a container orchestration tool.",
                category="kubernetes",
            ),
        ]

        result = lib.import_questions(questions, "test", cas, dry_run=False, strict=False)

        assert result.added == 1
        assert result.skipped_duplicates == 1

    def test_dry_run_creates_no_files(self, patched_import_lib):
        lib, cards_dir = patched_import_lib

        cas = lib.QuestionCAS()
        cas._loaded = True
        cas._index = {}

        questions = [
            lib.ParsedQuestion(
                question="What is Docker and how does it work?",
                answer="Docker packages apps in containers.",
                category="docker",
            )
        ]

        result = lib.import_questions(questions, "test", cas, dry_run=True)

        assert result.added == 1
        assert not (cards_dir / "docker.tsv").exists()


class TestValidateFromTsv:
    """cmd_validate reads from TSV, not txt."""

    def test_validate_reads_tsv(self, patched_import_lib):
        lib, import_cards_dir = patched_import_lib

        # Write a valid TSV in the import lib's cards dir
        import_cards_dir.mkdir(parents=True, exist_ok=True)
        tsv = import_cards_dir / "linux.tsv"
        with tsv.open("w", encoding="utf-8", newline="") as fh:
            writer = csv.DictWriter(fh, fieldnames=lib.FIELDS, delimiter="\t")
            writer.writeheader()
            writer.writerow(
                {
                    "id": "linux/abc123",
                    "category": "linux",
                    "difficulty": "easy",
                    "tags": "linux",
                    "question": "What is the Linux kernel?",
                    "answer": "The Linux kernel is the core of the operating system.",
                    "source_path": "",
                }
            )

        import argparse

        args = argparse.Namespace(category=None, verbose=False)
        rc = lib.cmd_validate(args)
        # Should succeed (no validation issues)
        assert rc == 0


class TestReindexFromTsv:
    """cmd_reindex reads from TSV, not txt."""

    def test_reindex_from_tsv(self, patched_import_lib):
        lib, cards_dir = patched_import_lib

        # Write a TSV
        tsv = cards_dir / "docker.tsv"
        with tsv.open("w", encoding="utf-8", newline="") as fh:
            writer = csv.DictWriter(fh, fieldnames=lib.FIELDS, delimiter="\t")
            writer.writeheader()
            writer.writerow(
                {
                    "id": "docker/xyz789",
                    "category": "docker",
                    "difficulty": "medium",
                    "tags": "docker",
                    "question": "How do you build a Docker image?",
                    "answer": "Use docker build -t name .",
                    "source_path": "",
                }
            )

        import argparse

        args = argparse.Namespace()
        rc = lib.cmd_reindex(args)
        assert rc == 0

        # CAS index should exist
        cas_index = lib.CAS_DIR / "index.tsv"
        assert cas_index.exists()


# ---------------------------------------------------------------------------
# No txt fallback - runtime never reads txt
# ---------------------------------------------------------------------------


class TestNoTxtFallback:
    """Runtime never falls back to reading txt files."""

    def test_no_txt_reading_in_flashcard_lib(self, patched_flashcard_lib):
        """Verify flashcard_lib has no reference to .txt file reading."""
        import inspect

        lib = patched_flashcard_lib
        source = inspect.getsource(lib)
        # Should not contain from_file (the old txt parser)
        assert "def from_file" not in source
        # Should not contain glob("*.txt") for reading
        assert '.glob("*.txt")' not in source

    def test_empty_cards_dir_returns_empty(self, patched_flashcard_lib, tmp_path, monkeypatch):
        """With no TSV files, questions list is empty (no txt fallback)."""
        lib = patched_flashcard_lib
        empty = tmp_path / "empty_cards"
        empty.mkdir()
        monkeypatch.setattr(lib, "CARDS_DIR", empty)
        assert lib.get_questions() == []
        assert lib.get_categories() == []
