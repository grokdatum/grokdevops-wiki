"""
Tests for gd-flashcards extractor.

Golden extraction tests from fixture files.

The CLI uses subcommands (v0.2.0+):
  gd-flashcards extract files PATH...
  gd-flashcards extract files --tag TAG PATH...
"""

import os
import subprocess
from pathlib import Path

_KNOWLEDGE_ROOT = Path(__file__).resolve().parent.parent
TOOL = str(_KNOWLEDGE_ROOT / "gd-flashcards")
FIXTURES = str(_KNOWLEDGE_ROOT / "tests" / "fixtures" / "flashcards")


class TestFlashcardExtraction:
    """Golden tests for flashcard extraction."""

    def test_help(self):
        """--help exits 0."""
        result = subprocess.run([TOOL, "--help"], capture_output=True, text=True)
        assert result.returncode == 0
        assert "flashcards" in result.stdout.lower()

    def test_version(self):
        """--version prints version string."""
        result = subprocess.run([TOOL, "--version"], capture_output=True, text=True)
        assert result.returncode == 0
        # Verify format: "gd-flashcards X.Y.Z"
        assert "gd-flashcards" in result.stdout
        parts = result.stdout.strip().split()
        assert len(parts) == 2
        version_parts = parts[1].split(".")
        assert len(version_parts) == 3, f"Expected semver, got {parts[1]}"

    def test_extract_markdown_qa(self):
        """Extract Q:/A: pairs from markdown."""
        result = subprocess.run(
            [TOOL, "extract", "files", os.path.join(FIXTURES, "sample.md")],
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0
        lines = result.stdout.strip().split("\n")
        # Header + at least 3 cards
        assert len(lines) >= 4  # header + 3 cards
        # Check header
        assert lines[0].startswith("card_id\t")
        # Check Q/A pair was extracted
        assert "default data home directory" in result.stdout
        assert "~/.gd/" in result.stdout

    def test_extract_code_comments(self):
        """Extract FLASHCARD_Q/A from code comments."""
        result = subprocess.run(
            [TOOL, "extract", "files", os.path.join(FIXTURES, "sample.py")],
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0
        assert "set -euo pipefail" in result.stdout
        assert "Content-Addressable Storage" in result.stdout

    def test_extract_heading_answer(self):
        """Extract heading + Answer: from markdown."""
        result = subprocess.run(
            [TOOL, "extract", "files", os.path.join(FIXTURES, "sample.md")],
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0
        assert "append-only" in result.stdout.lower()

    def test_tag_option(self):
        """--tag adds tags to all cards."""
        result = subprocess.run(
            [TOOL, "extract", "files", "--tag", "test-tag", os.path.join(FIXTURES, "sample.md")],
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0
        # Every data line should contain test-tag
        lines = result.stdout.strip().split("\n")
        for line in lines[1:]:  # skip header
            if line.strip():
                assert "test-tag" in line

    def test_stable_card_ids(self):
        """Card IDs are stable across runs."""
        result1 = subprocess.run(
            [TOOL, "extract", "files", os.path.join(FIXTURES, "sample.md")],
            capture_output=True,
            text=True,
        )
        result2 = subprocess.run(
            [TOOL, "extract", "files", os.path.join(FIXTURES, "sample.md")],
            capture_output=True,
            text=True,
        )
        assert result1.stdout == result2.stdout

    def test_directory_walk(self):
        """Scanning a directory finds cards from all files."""
        result = subprocess.run(
            [TOOL, "extract", "files", FIXTURES], capture_output=True, text=True
        )
        assert result.returncode == 0
        # Should find cards from both sample.md and sample.py
        assert "default data home" in result.stdout
        assert "Content-Addressable Storage" in result.stdout

    def test_no_input_fails(self):
        """No input files to extract subcommand exits with error."""
        result = subprocess.run([TOOL, "extract", "files"], capture_output=True, text=True)
        assert result.returncode != 0
