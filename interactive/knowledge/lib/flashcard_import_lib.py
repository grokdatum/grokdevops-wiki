"""
flashcard-import - Import interview questions from external sources

Imports questions from GitHub repos with deduplication using CAS backend.
Tracks import history to enable delta imports (only new questions).
Validates questions for quality issues before import.

Usage:
    flashcard-import import <repo_url>        # Import from GitHub repo
    flashcard-import check <repo_url>         # Dry run with validation
    flashcard-import validate [category]      # Validate existing questions
    flashcard-import list                     # List imported repos
    flashcard-import status                   # Show dedup stats
    flashcard-import reindex                  # Rebuild index

Import Options:
    --dry-run, -n       Show what would be imported without making changes
    --no-strict         Import questions even if they have validation issues
    --verbose, -v       Show validation errors as they occur
    --show-errors       Show detailed validation error messages

Validation:
    Questions are validated for quality issues before import:
    - EMPTY_QUESTION: Question text is empty or too short (<10 chars)
    - EMPTY_ANSWER: Answer is empty or has no actual content
    - VERY_SHORT: Answer is less than 5 characters (except True/False)
    - IMAGE_ONLY: Answer contains only an image with no text fallback
    - LINK_ONLY: Answer is just a link without explanation

    By default (--strict), questions with issues are rejected.
    Use --no-strict to import them anyway.

Supported Formats:
    - Markdown with <details> blocks (test-your-sysadmin-skills, devops-exercises)
    - Markdown with #### Question: / **Answer:** (awesome-devops-interview)
    - Markdown with ### Scenario: / ### Question: / ### Answer: (ansible scenarios)
    - Simple Q: / A: format (Jenkins-Zero-To-Hero)

Deduplication:
    Uses TextCAS backend with question fingerprinting (normalized text hash).
    Duplicates detected even across different sources/phrasings.
"""

import argparse
import csv
import hashlib
import json
import os
import re
import subprocess
import sys
import tempfile
import unicodedata
from abc import ABC, abstractmethod
from dataclasses import asdict, dataclass, field
from datetime import datetime
from pathlib import Path
from typing import Any

# Data directory for CAS index and import registry
_lib_dir = Path(__file__).parent  # projects/kb/lib
_project_dir = _lib_dir.parent  # projects/kb/
_default_data_dir = _project_dir / "interview"  # projects/kb/interview
DATA_DIR = Path(os.environ.get("INTERVIEW_DATA_DIR", str(_default_data_dir)))

# Canonical TSV cards directory - where imports write to
_default_cards_dir = _project_dir / "data" / "cards"
CARDS_DIR = Path(os.environ.get("INTERVIEW_CARDS_DIR", str(_default_cards_dir)))

# CAS storage for question index
CAS_DIR = DATA_DIR / ".cas"

# Registry file (keep as JSON for simplicity)
REGISTRY_FILE = DATA_DIR / ".import-registry.json"

# TSV field names (must match flashcard-tsv contract)
FIELDS = ["id", "category", "difficulty", "tags", "question", "answer", "source_path"]


# =============================================================================
# Question Fingerprinting (CAS-style)
# =============================================================================


def normalize_text(text: str) -> str:
    """Normalize text for fingerprinting.

    - Lowercase
    - Remove punctuation and special chars
    - Collapse whitespace
    - Unicode normalization
    """
    text = unicodedata.normalize("NFKC", text)
    text = text.lower()
    # Remove markdown/HTML formatting
    text = re.sub(r"\*\*|__|\*|_|`|##+", "", text)
    text = re.sub(r"<[^>]+>", "", text)
    text = re.sub(r"```[\s\S]*?```", "", text)
    text = re.sub(r"https?://\S+", "", text)
    # Keep only alphanumeric and spaces
    text = re.sub(r"[^a-z0-9\s]", " ", text)
    text = re.sub(r"\s+", " ", text).strip()
    return text


def fingerprint_question(question_text: str) -> str:
    """Generate a CAS-style fingerprint hash for a question.

    Uses MD5_16_SHA256_16 composite hash format for consistency with CAS.
    Returns a 33-char hash (16 + 1 + 16).
    """
    normalized = normalize_text(question_text)
    # Focus on core question (first 200 chars normalized)
    core = normalized[:200].encode("utf-8")

    md5_hash = hashlib.md5(core).hexdigest()[:16].upper()
    sha256_hash = hashlib.sha256(core).hexdigest()[:16].upper()

    return f"{md5_hash}_{sha256_hash}"


# =============================================================================
# Question CAS Index (TextCAS-backed)
# =============================================================================


class QuestionCAS:
    """CAS-backed question index for deduplication."""

    def __init__(self) -> None:
        self.cas_dir = CAS_DIR
        self.index_file = CAS_DIR / "index.tsv"
        self._index: dict[str, dict[str, str]] = {}
        self._loaded = False

    def _ensure_loaded(self) -> None:
        """Lazy load the index."""
        if self._loaded:
            return

        self.cas_dir.mkdir(parents=True, exist_ok=True)

        if self.index_file.exists():
            try:
                for line in self.index_file.read_text().strip().split("\n"):
                    if not line or line.startswith("#"):
                        continue
                    parts = line.split("\t")
                    if len(parts) >= 4:
                        fp, qid, source, preview = parts[0], parts[1], parts[2], parts[3]
                        self._index[fp] = {"id": qid, "source": source, "preview": preview}
            except Exception as e:
                print(f"flashcard-import: warning: could not load CAS index: {e}", file=sys.stderr)

        self._loaded = True

    def save(self) -> None:
        """Save index to TSV file."""
        self.cas_dir.mkdir(parents=True, exist_ok=True)

        lines = ["# FINGERPRINT\tID\tSOURCE\tPREVIEW"]
        for fp, data in sorted(self._index.items()):
            preview = data.get("preview", "")[:80].replace("\t", " ").replace("\n", " ")
            line = f"{fp}\t{data['id']}\t{data['source']}\t{preview}"
            lines.append(line)

        self.index_file.write_text("\n".join(lines) + "\n")

    def is_duplicate(self, question_text: str) -> tuple[bool, str | None]:
        """Check if question is a duplicate.

        Returns (is_dup, existing_id_if_dup)
        """
        self._ensure_loaded()
        fp = fingerprint_question(question_text)
        if fp in self._index:
            return True, self._index[fp].get("id")
        return False, None

    def add(self, question_text: str, question_id: str, source: str) -> None:
        """Add a question to the index."""
        self._ensure_loaded()
        fp = fingerprint_question(question_text)
        self._index[fp] = {"id": question_id, "source": source, "preview": question_text[:100]}

    def __len__(self):
        self._ensure_loaded()
        return len(self._index)

    def stats(self) -> dict[str, int]:
        """Get stats by source."""
        self._ensure_loaded()
        sources: dict[str, int] = {}
        for fp, data in self._index.items():
            source = data.get("source", "unknown")
            # Simplify GitHub URLs
            if "github" in source.lower():
                parts = source.split("/")
                source = parts[-1] if parts else source
            sources[source] = sources.get(source, 0) + 1
        return sources


# =============================================================================
# Import Registry
# =============================================================================


@dataclass
class ImportRecord:
    """Record of an import operation."""

    repo: str
    commit: str
    date: str
    questions_added: int
    questions_skipped: int
    categories: list[str]

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> "ImportRecord":
        return cls(**data)


@dataclass
class ImportRegistry:
    """Registry of imported repos."""

    imports: list[ImportRecord] = field(default_factory=list)

    @classmethod
    def load(cls) -> "ImportRegistry":
        if REGISTRY_FILE.exists():
            try:
                data = json.loads(REGISTRY_FILE.read_text())
                imports = [ImportRecord.from_dict(r) for r in data.get("imports", [])]
                return cls(imports=imports)
            except Exception as e:
                print(f"Warning: Could not load import registry: {e}", file=sys.stderr)
        return cls()

    def save(self) -> None:
        REGISTRY_FILE.parent.mkdir(parents=True, exist_ok=True)
        data = {
            "imports": [r.to_dict() for r in self.imports],
            "updated": datetime.now().isoformat(),
        }
        # Inv #8: deterministic JSON
        REGISTRY_FILE.write_text(json.dumps(data, indent=2, sort_keys=True))

    def get_last_import(self, repo: str) -> ImportRecord | None:
        for record in reversed(self.imports):
            if record.repo == repo:
                return record
        return None

    def add_import(self, record: ImportRecord) -> None:
        self.imports.append(record)


# =============================================================================
# Parsed Question
# =============================================================================


@dataclass
class QuestionValidationError:
    """Represents a validation issue with a question."""

    error_type: str  # EMPTY_ANSWER, VERY_SHORT, IMAGE_ONLY, LINK_ONLY, EMPTY_QUESTION
    message: str
    fixable: bool = False

    def __str__(self) -> str:
        status = "[FIXABLE]" if self.fixable else "[REJECTED]"
        return f"{status} {self.error_type}: {self.message}"


@dataclass
class ParsedQuestion:
    """A question parsed from an external source."""

    question: str
    answer: str
    category: str
    tags: list[str] = field(default_factory=list)
    difficulty: str = "medium"
    source_file: str = ""


# =============================================================================
# Question Validation
# =============================================================================


def get_clean_answer_text(answer: str) -> str:
    """Get clean text from answer for length analysis.

    Removes HTML tags, markdown formatting, but keeps actual content.
    """
    if not answer:
        return ""

    result = answer
    # Replace <br> with space
    result = re.sub(r"<br\s*/?>", " ", result)
    # Remove <img> tags completely
    result = re.sub(r"<img[^>]+/?>", "", result)
    # Remove other HTML tags but keep content
    result = re.sub(r"<[^>]+>", "", result)
    # Remove markdown bold/italic
    result = re.sub(r"\*\*([^*]+)\*\*", r"\1", result)
    result = re.sub(r"__([^_]+)__", r"\1", result)
    result = re.sub(r"\*([^*]+)\*", r"\1", result)
    result = re.sub(r"_([^_]+)_", r"\1", result)
    # Remove markdown links but keep text
    result = re.sub(r"\[([^\]]+)\]\([^)]+\)", r"\1", result)
    # Normalize whitespace
    result = " ".join(result.split())
    return result.strip()


def validate_question(question: ParsedQuestion) -> QuestionValidationError | None:
    """Validate a parsed question for quality issues.

    Returns None if valid, or a QuestionValidationError if there's an issue.

    Checks for:
    - EMPTY_QUESTION: Question text is empty or too short
    - EMPTY_ANSWER: Answer is empty
    - VERY_SHORT: Answer is less than 5 characters (not for True/False)
    - IMAGE_ONLY: Answer contains only an image with no text
    - LINK_ONLY: Answer is just a link without explanation
    """
    q_text = question.question.strip()
    answer = question.answer.strip()

    # Check for empty/short question
    if not q_text:
        return QuestionValidationError(
            error_type="EMPTY_QUESTION", message="Question text is empty", fixable=False
        )
    if len(q_text) < 10:
        return QuestionValidationError(
            error_type="EMPTY_QUESTION",
            message=f"Question too short ({len(q_text)} chars): '{q_text[:50]}'",
            fixable=False,
        )

    # Check for empty answer
    if not answer:
        return QuestionValidationError(
            error_type="EMPTY_ANSWER",
            message=f"Answer is empty for question: '{q_text[:50]}...'",
            fixable=False,
        )

    # Check if this is a True/False question (short answers are OK)
    is_true_false = bool(re.search(r"^True\s+(or|/)\s+False", q_text, re.IGNORECASE))
    if is_true_false:
        normalized = answer.lower().strip().rstrip(".")
        if normalized in {"true", "false"}:
            return None  # Valid True/False answer

    # Get clean answer text for analysis
    clean_answer = get_clean_answer_text(answer)
    has_code_block = "```" in answer
    has_inline_code = bool(re.search(r"`[^`]+`", answer))

    # Check for IMAGE_ONLY answer
    if re.search(r"<img[^>]+/?>", answer):
        if len(clean_answer) < 5:
            return QuestionValidationError(
                error_type="IMAGE_ONLY",
                message=f"Answer contains only an image with no text fallback: '{q_text[:50]}...'",
                fixable=False,
            )

    # Check for LINK_ONLY answer
    link_match = re.search(r"\[([^\]]+)\]\(([^)]+)\)", answer)
    if link_match:
        link_text = link_match.group(1).strip().lower()
        link_url = link_match.group(2).strip()
        rest_of_answer = re.sub(r"\[([^\]]+)\]\([^)]+\)", "", answer).strip()
        # If answer is essentially just a link
        link_only_texts = [
            "here",
            "link",
            "this",
            "explained here",
            "this link",
            "read more",
            "see here",
            "click here",
            "documentation",
        ]
        if len(rest_of_answer) < 10 and link_text.lower() in link_only_texts:
            return QuestionValidationError(
                error_type="LINK_ONLY",
                message=(
                    f"Answer is just a link without explanation: "
                    f"'{q_text[:40]}...' -> [{link_text}]({link_url[:30]}...)"
                ),
                fixable=False,
            )

    # Check for truly empty answer (after cleaning)
    if not clean_answer and not has_code_block and not has_inline_code:
        return QuestionValidationError(
            error_type="EMPTY_ANSWER",
            message=f"Answer has no actual content: '{q_text[:50]}...'",
            fixable=False,
        )

    # Check for VERY_SHORT answer (< 5 chars without code)
    if len(clean_answer) < 5 and not has_code_block and not has_inline_code:
        return QuestionValidationError(
            error_type="VERY_SHORT",
            message=(
                f"Answer too short ({len(clean_answer)} chars): "
                f"'{clean_answer}' for question: '{q_text[:40]}...'"
            ),
            fixable=False,
        )

    return None  # Valid question


# =============================================================================
# Format Parsers
# =============================================================================


class Parser(ABC):
    """Base class for format parsers."""

    name: str = "base"
    priority: int = 50  # Lower = higher priority

    @abstractmethod
    def can_parse(self, repo_path: Path) -> bool:
        """Check if this parser can handle the given repository."""
        pass

    @abstractmethod
    def parse(self, repo_path: Path) -> list[ParsedQuestion]:
        """Parse questions from the repository."""
        pass


class AwesomeDevOpsParser(Parser):
    """Parser for #### Question: / **Answer:** format (awesome-devops-interview)."""

    name = "awesome-devops"
    priority = 10

    def can_parse(self, repo_path: Path) -> bool:
        # Check for multiple .md files with #### Question: pattern
        for md_file in repo_path.glob("*.md"):
            if md_file.name.lower() in ("readme.md", "license.md", "contributing.md"):
                continue
            content = md_file.read_text()[:2000]
            if "#### Question:" in content and "**Answer:**" in content:
                return True
        return False

    def parse(self, repo_path: Path) -> list[ParsedQuestion]:
        questions = []

        for md_file in repo_path.glob("*.md"):
            if md_file.name.lower() in ("readme.md", "license.md", "contributing.md"):
                continue

            content = md_file.read_text()
            category = md_file.stem.lower()

            # Pattern: #### Question: ...\n**Answer:** ...
            pattern = r"####\s*Question:\s*(.*?)\n\*\*Answer:\*\*\s*(.*?)(?=\n####|\n\n\n|\Z)"

            for match in re.finditer(pattern, content, re.DOTALL):
                q_text = match.group(1).strip()
                a_text = match.group(2).strip()

                if len(q_text) < 10 or len(a_text) < 10:
                    continue

                questions.append(
                    ParsedQuestion(
                        question=q_text,
                        answer=a_text,
                        category=category,
                        difficulty="medium",
                        tags=[category],
                        source_file=md_file.name,
                    )
                )

        return questions


class ScenarioMarkdownParser(Parser):
    """Parser for ### Scenario: / ### Question: / ### Answer: format."""

    name = "scenario-markdown"
    priority = 15

    def can_parse(self, repo_path: Path) -> bool:
        readme = repo_path / "README.md"
        if readme.exists():
            content = readme.read_text()[:3000]
            return "### Scenario:" in content and "### Answer:" in content
        return False

    def parse(self, repo_path: Path) -> list[ParsedQuestion]:
        questions = []
        readme = repo_path / "README.md"
        content = readme.read_text()

        # Infer category from repo name or content
        category = "devops"
        if "ansible" in content.lower()[:500]:
            category = "ansible"
        elif "terraform" in content.lower()[:500]:
            category = "terraform"

        # Pattern: ## N. Title\n### Scenario:\n...\n### Question:\n...\n### Answer:\n...
        pattern = (
            r"##\s*\d+\.\s*(.*?)\n###\s*Scenario:\s*(.*?)"
            r"###\s*Question:\s*(.*?)###\s*Answer:\s*(.*?)"
            r"(?=\n##\s*\d+\.|\Z)"
        )

        for match in re.finditer(pattern, content, re.DOTALL):
            title = match.group(1).strip()
            scenario = match.group(2).strip()
            q_text = match.group(3).strip()
            a_text = match.group(4).strip()

            # Combine scenario and question
            full_question = f"{title}\n\nScenario: {scenario}\n\nQuestion: {q_text}"

            if len(q_text) < 10 or len(a_text) < 10:
                continue

            questions.append(
                ParsedQuestion(
                    question=full_question,
                    answer=a_text,
                    category=category,
                    difficulty="hard",  # Scenario-based = harder
                    tags=[category, "scenario"],
                    source_file="README.md",
                )
            )

        return questions


class SimpleQAParser(Parser):
    """Parser for simple Q: / A: format (Jenkins-Zero-To-Hero style)."""

    name = "simple-qa"
    priority = 20

    def can_parse(self, repo_path: Path) -> bool:
        # Look for files with Q: and A: patterns
        for md_file in repo_path.rglob("*.md"):
            content = md_file.read_text()[:3000]
            # Count Q: and A: occurrences (allow at start of line or after newline)
            q_count = len(re.findall(r"(?:^|\n)Q:\s", content))
            a_count = len(re.findall(r"(?:^|\n)A:\s", content))
            if q_count >= 3 and a_count >= 3:
                return True
        return False

    def parse(self, repo_path: Path) -> list[ParsedQuestion]:
        questions = []

        for md_file in repo_path.rglob("*.md"):
            content = md_file.read_text()

            # Infer category
            category = md_file.stem.lower().replace("_", "-")
            if category in ("readme", "interview-questions", "questions", "interview-questions"):
                # Try parent directory
                category = md_file.parent.name.lower()
            if category in (".", "repo"):
                category = "devops"

            # Map common names
            cat_map = {
                "interview-questions": "devops",
                "jenkins-zero-to-hero": "jenkins",
            }
            category = cat_map.get(category, category)

            # Pattern: Q: question\n\nA: answer (allow at start or after newline)
            pattern = r"(?:^|\n)Q:\s*(.*?)\n+A:\s*(.*?)(?=\nQ:|\Z)"

            for match in re.finditer(pattern, content, re.DOTALL):
                q_text = match.group(1).strip()
                a_text = match.group(2).strip()

                if len(q_text) < 10 or len(a_text) < 10:
                    continue

                questions.append(
                    ParsedQuestion(
                        question=q_text,
                        answer=a_text,
                        category=category,
                        difficulty="medium",
                        tags=[category],
                        source_file=str(md_file.name),
                    )
                )

        return questions


class DetailsMarkdownParser(Parser):
    """Parser for markdown with <details> blocks."""

    name = "details-markdown"
    priority = 25

    def can_parse(self, repo_path: Path) -> bool:
        readme = repo_path / "README.md"
        if readme.exists():
            content = readme.read_text()[:5000]
            return "<details>" in content and "<summary>" in content
        return False

    def parse(self, repo_path: Path) -> list[ParsedQuestion]:
        readme = repo_path / "README.md"
        content = readme.read_text()
        questions = []

        # Map section names to difficulty
        level_patterns = [
            (r"simple.?questions", "easy"),
            (r"junior", "easy"),
            (r"regular", "medium"),
            (r"senior", "hard"),
            (r"guru", "hard"),
            (r"advanced", "hard"),
            (r"beginner", "easy"),
        ]

        # Subcategory patterns
        subcat_patterns = [
            (r"system\s*questions", "linux"),
            (r"network\s*questions", "networking"),
            (r"devops\s*questions", "devops"),
            (r"security\s*questions", "security"),
            (r"cyber\s*security", "security"),
        ]

        # Pattern for details blocks
        pattern = (
            r"<details>\s*<summary>(?:<b>)?(.*?)(?:</b>)?"
            r"</summary>\s*<br>\s*(?:<b>\s*)?(.*?)"
            r"(?:\s*</b>)?\s*</details>"
        )

        for match in re.finditer(pattern, content, re.DOTALL | re.IGNORECASE):
            pos = match.start()
            q_text = match.group(1).strip()
            a_text = match.group(2).strip()

            # Clean HTML
            q_text = re.sub(r"<[^>]+>", "", q_text).strip().rstrip("*").strip()

            # Determine difficulty
            difficulty = "medium"
            before_text = content[:pos].lower()
            for pat, level in reversed(level_patterns):
                if re.search(pat, before_text[-2000:]):
                    difficulty = level
                    break

            # Determine category
            category = "linux"
            for pat, cat in reversed(subcat_patterns):
                if re.search(pat, before_text[-1000:]):
                    category = cat
                    break

            # Clean answer
            a_text = re.sub(
                r"\n*Useful resources:.*$",
                "",
                a_text,
                flags=re.DOTALL | re.IGNORECASE,
            ).strip()

            if not a_text or len(q_text) < 10 or len(a_text) < 5:
                continue

            questions.append(
                ParsedQuestion(
                    question=q_text,
                    answer=a_text,
                    category=category,
                    difficulty=difficulty,
                    tags=[category],
                    source_file="README.md",
                )
            )

        return questions


class DevOpsExercisesParser(Parser):
    """Parser for bregman-arie/devops-exercises format."""

    name = "devops-exercises"
    priority = 30

    def can_parse(self, repo_path: Path) -> bool:
        topics_dir = repo_path / "topics"
        if topics_dir.exists():
            for subdir in topics_dir.iterdir():
                if subdir.is_dir() and (subdir / "README.md").exists():
                    return True
        return False

    def parse(self, repo_path: Path) -> list[ParsedQuestion]:
        questions = []

        category_map = {
            "linux": "linux",
            "bash": "bash",
            "python": "python",
            "aws": "aws",
            "azure": "azure",
            "gcp": "gcp",
            "kubernetes": "kubernetes",
            "docker": "docker",
            "terraform": "terraform",
            "ansible": "ansible",
            "jenkins": "jenkins",
            "git": "git",
            "cicd": "cicd",
            "ci-cd": "cicd",
            "networking": "networking",
            "network": "networking",
            "security": "security",
            "containers": "docker",
            "sql": "databases",
            "nosql": "databases",
            "prometheus": "monitoring",
            "grafana": "monitoring",
            "openstack": "cloud",
            "cloud": "cloud",
            "dns": "networking",
            "virtualization": "linux",
            "go": "go",
            "mongo": "databases",
            "elastic": "databases",
            "shell": "bash",
            "hardware": "linux",
        }

        topics_dir = repo_path / "topics"
        if topics_dir.exists():
            for topic_dir in sorted(topics_dir.iterdir()):
                if not topic_dir.is_dir():
                    continue

                readme = topic_dir / "README.md"
                if not readme.exists():
                    continue

                topic_name = topic_dir.name.lower()
                category = category_map.get(topic_name, topic_name)

                content = readme.read_text()
                pattern = (
                    r"<details>\s*<summary>(.*?)</summary>"
                    r"\s*<br>\s*(?:<b>\s*)?(.*?)"
                    r"(?:\s*</b>)?\s*</details>"
                )

                for match in re.finditer(pattern, content, re.DOTALL | re.IGNORECASE):
                    q_text = re.sub(r"<[^>]+>", "", match.group(1)).strip()
                    a_text = match.group(2).strip()

                    if len(q_text) < 10 or len(a_text) < 5:
                        continue

                    difficulty = "medium"
                    if "bonus" in q_text.lower() or "advanced" in q_text.lower():
                        difficulty = "hard"
                    elif "basic" in q_text.lower() or "what is" in q_text.lower():
                        difficulty = "easy"

                    questions.append(
                        ParsedQuestion(
                            question=q_text,
                            answer=a_text,
                            category=category,
                            difficulty=difficulty,
                            tags=[category],
                            source_file=readme.name,
                        )
                    )

        return questions


class GenericMarkdownParser(Parser):
    """Fallback parser for generic markdown Q&A format."""

    name = "generic-markdown"
    priority = 100  # Lowest priority

    def can_parse(self, repo_path: Path) -> bool:
        return any(repo_path.rglob("*.md"))

    def parse(self, repo_path: Path) -> list[ParsedQuestion]:
        questions = []

        for md_file in repo_path.rglob("*.md"):
            if md_file.name.lower() in ("license.md", "contributing.md", "code_of_conduct.md"):
                continue

            try:
                content = md_file.read_text()
            except Exception as e:
                print(f"warn: read failed for {md_file}: {e}", file=sys.stderr)
                continue

            if len(content) < 100:
                continue

            # Try ## Header sections
            sections = re.split(r"\n##\s+", content)
            for section in sections[1:]:
                lines = section.strip().split("\n", 1)
                if len(lines) < 2:
                    continue

                q_text = lines[0].strip().rstrip("?") + "?"
                a_text = lines[1].strip()

                if len(q_text) < 15 or len(a_text) < 20:
                    continue

                category = md_file.parent.name.lower()
                if category in (".", "docs", "questions", "repo"):
                    category = md_file.stem.lower()

                questions.append(
                    ParsedQuestion(
                        question=q_text,
                        answer=a_text,
                        category=category,
                        difficulty="medium",
                        tags=[category],
                        source_file=str(md_file.name),
                    )
                )

        return questions


# Registry of parsers sorted by priority
PARSERS: list[Parser] = sorted(
    [
        AwesomeDevOpsParser(),
        ScenarioMarkdownParser(),
        SimpleQAParser(),
        DetailsMarkdownParser(),
        DevOpsExercisesParser(),
        GenericMarkdownParser(),
    ],
    key=lambda p: p.priority,
)


def get_parser(repo_path: Path) -> Parser | None:
    """Find the best parser for the repo."""
    for parser in PARSERS:
        if parser.can_parse(repo_path):
            return parser
    return None


# =============================================================================
# Canonical TSV helpers
# =============================================================================


def _append_to_canonical_tsv(category: str, row: dict) -> None:
    """Append a single row to the canonical category TSV."""
    CARDS_DIR.mkdir(parents=True, exist_ok=True)
    tsv_path = CARDS_DIR / f"{category}.tsv"

    file_exists = tsv_path.exists() and tsv_path.stat().st_size > 0
    with tsv_path.open("a", encoding="utf-8", newline="") as fh:
        writer = csv.DictWriter(fh, fieldnames=FIELDS, delimiter="\t")
        if not file_exists:
            writer.writeheader()
        writer.writerow(row)


def _load_tsv_questions(tsv_path: Path) -> list[dict]:
    """Load rows from a TSV file."""
    rows = []
    if not tsv_path.exists():
        return rows
    with tsv_path.open(encoding="utf-8", newline="") as fh:
        rows.extend(list(csv.DictReader(fh, delimiter="\t")))
    return rows


# =============================================================================
# Import Operations
# =============================================================================


def clone_repo(repo_url: str, target_dir: Path) -> tuple[bool, str]:
    """Clone a repo and return (success, commit_hash)."""
    if not repo_url.startswith(("http://", "https://", "git@")):
        repo_url = f"https://github.com/{repo_url}"

    try:
        result = subprocess.run(
            ["git", "clone", "--depth", "1", repo_url, str(target_dir)],
            capture_output=True,
            text=True,
            timeout=int(os.environ.get("GD_TIMEOUT_SUBPROCESS", "60")),
        )
        if result.returncode != 0:
            print(f"Clone failed: {result.stderr}", file=sys.stderr)
            return False, ""

        result = subprocess.run(
            ["git", "-C", str(target_dir), "rev-parse", "HEAD"], capture_output=True, text=True
        )
        return True, result.stdout.strip()[:12]

    except subprocess.TimeoutExpired:
        print("flashcard-import: error: clone timed out", file=sys.stderr)
        return False, ""
    except Exception as e:
        print(f"flashcard-import: error: clone failed: {e}", file=sys.stderr)
        return False, ""


@dataclass
class ImportResult:
    """Result of an import operation."""

    added: int = 0
    skipped_duplicates: int = 0
    rejected: int = 0
    categories: set[str] = field(default_factory=set)
    validation_errors: list[tuple[ParsedQuestion, QuestionValidationError]] = field(
        default_factory=list
    )

    def summary(self) -> str:
        """Generate a summary string."""
        lines = [
            f"  Added: {self.added}",
            f"  Skipped (duplicates): {self.skipped_duplicates}",
            f"  Rejected (validation): {self.rejected}",
        ]
        if self.categories:
            lines.append(f"  Categories: {', '.join(sorted(self.categories))}")
        return "\n".join(lines)


def import_questions(
    questions: list[ParsedQuestion],
    source: str,
    cas: QuestionCAS,
    dry_run: bool = False,
    strict: bool = True,
    verbose: bool = False,
) -> ImportResult:
    """Import questions with CAS deduplication and validation.

    Writes to canonical TSV files in CARDS_DIR (no txt files created).

    Args:
        questions: List of parsed questions to import
        source: Source identifier (repo URL)
        cas: CAS index for deduplication
        dry_run: If True, don't actually write files
        strict: If True, reject questions with validation errors
        verbose: If True, print validation errors as they occur

    Returns:
        ImportResult with statistics and any validation errors
    """
    result = ImportResult()

    for q in questions:
        # Step 1: Validate the question
        validation_error = validate_question(q)
        if validation_error:
            result.rejected += 1
            result.validation_errors.append((q, validation_error))
            if verbose:
                print(f"  REJECTED: {validation_error}", file=sys.stderr)
            if strict:
                continue  # Skip this question

        # Step 2: Check for duplicates
        is_dup, existing_id = cas.is_duplicate(q.question)
        if is_dup:
            result.skipped_duplicates += 1
            continue

        # Step 3: Import to canonical TSV
        category = q.category
        result.categories.add(category)

        # Generate deterministic ID
        digest = hashlib.sha256(f"{category}\n{q.question}\n{q.answer}".encode()).hexdigest()[:12]
        question_id = f"{category}/{digest}"

        if not dry_run:
            row = {
                "id": question_id,
                "category": category,
                "difficulty": q.difficulty,
                "tags": ", ".join(q.tags),
                "question": q.question,
                "answer": q.answer,
                "source_path": q.source_file,
            }
            _append_to_canonical_tsv(category, row)
            cas.add(q.question, question_id, source)

        result.added += 1

    return result


# =============================================================================
# CLI Commands
# =============================================================================


def cmd_import(args) -> int:
    """Import questions from a repo."""
    repo_url = args.repo
    dry_run = getattr(args, "dry_run", False)
    strict = getattr(args, "strict", True)
    verbose = getattr(args, "verbose", False)
    show_errors = getattr(args, "show_errors", False)

    print(f"Importing from: {repo_url}", file=sys.stderr)
    if dry_run:
        print("(DRY RUN - no changes will be made)", file=sys.stderr)
    if not strict:
        print("(PERMISSIVE MODE - questions with issues will still be imported)", file=sys.stderr)

    cas = QuestionCAS()
    registry = ImportRegistry.load()

    last_import = registry.get_last_import(repo_url)
    if last_import:
        print(
            f"Previous import: {last_import.date[:10]} ({last_import.questions_added} questions)",
            file=sys.stderr,
        )

    with tempfile.TemporaryDirectory() as tmpdir:
        repo_path = Path(tmpdir) / "repo"
        print("Cloning repository...", file=sys.stderr)
        success, commit = clone_repo(repo_url, repo_path)
        if not success:
            return 1

        print(f"Commit: {commit}", file=sys.stderr)

        parser = get_parser(repo_path)
        if not parser:
            print("flashcard-import: error: no parser found for this repo format", file=sys.stderr)
            return 1

        print(f"Using parser: {parser.name}", file=sys.stderr)

        print("Parsing questions...", file=sys.stderr)
        questions = parser.parse(repo_path)
        print(f"Found {len(questions)} questions", file=sys.stderr)

        if not questions:
            print("flashcard-import: no questions found to import", file=sys.stderr)
            return 0

        print("Importing (with validation and CAS deduplication)...", file=sys.stderr)
        result = import_questions(
            questions, repo_url, cas, dry_run=dry_run, strict=strict, verbose=verbose
        )

        print("\nResults:")
        print(result.summary())

        # Show validation errors if any
        if result.validation_errors:
            print(f"\nValidation Issues ({len(result.validation_errors)} questions rejected):")

            # Group errors by type
            errors_by_type: dict[str, list[tuple[ParsedQuestion, QuestionValidationError]]] = {}
            for q, err in result.validation_errors:
                if err.error_type not in errors_by_type:
                    errors_by_type[err.error_type] = []
                errors_by_type[err.error_type].append((q, err))

            for error_type, errors in sorted(errors_by_type.items()):
                print(f"\n  {error_type}: {len(errors)} questions")
                if show_errors or verbose:
                    for q, err in errors[:10]:  # Show first 10 of each type
                        print(f"    - {err.message[:80]}")
                    if len(errors) > 10:
                        print(f"    ... and {len(errors) - 10} more")

            if not show_errors and not verbose:
                print("\n  Use --show-errors to see details")

        if not dry_run and result.added > 0:
            cas.save()

            record = ImportRecord(
                repo=repo_url,
                commit=commit,
                date=datetime.now().isoformat(),
                questions_added=result.added,
                questions_skipped=result.skipped_duplicates,
                categories=sorted(result.categories),
            )
            registry.add_import(record)
            registry.save()

            print(f"\nImport complete. Total questions in CAS: {len(cas)}", file=sys.stderr)

    return 0 if result.rejected == 0 else 1


def cmd_list(args) -> int:
    """List imported repos."""
    registry = ImportRegistry.load()

    if not registry.imports:
        print("No imports recorded yet.")
        return 0

    print("Import History:")
    print("-" * 70)
    for record in registry.imports:
        print(f"\n{record.repo}")
        print(f"  Date: {record.date[:10]}")
        print(f"  Commit: {record.commit}")
        print(f"  Added: {record.questions_added}, Skipped: {record.questions_skipped}")
        print(f"  Categories: {', '.join(record.categories)}")

    return 0


def cmd_status(args) -> int:
    """Show deduplication stats."""
    cas = QuestionCAS()

    print("Question CAS Status:")
    print("-" * 40)
    print(f"  Unique questions indexed: {len(cas)}")

    stats = cas.stats()
    if stats:
        print("\nBy Source:")
        for source, count in sorted(stats.items(), key=lambda x: -x[1]):
            print(f"  {source}: {count}")

    return 0


def cmd_check(args) -> int:
    """Check what would be imported (dry run)."""
    args.dry_run = True
    args.strict = True  # Always validate in check mode
    return cmd_import(args)


def cmd_validate(args) -> int:
    """Validate existing questions from canonical TSV for quality issues."""
    category = getattr(args, "category", None)
    verbose = getattr(args, "verbose", False)

    print("Validating existing questions from canonical TSV...", file=sys.stderr)

    if not CARDS_DIR.exists():
        print("flashcard-import: error: no cards directory found", file=sys.stderr)
        return 1

    issues_found: list[tuple[str, QuestionValidationError]] = []
    total_checked = 0

    # Determine which TSV files to check
    if category:
        tsv_files = [CARDS_DIR / f"{category}.tsv"]
    else:
        tsv_files = sorted(
            [
                f
                for f in CARDS_DIR.iterdir()
                if f.is_file() and f.suffix == ".tsv" and not f.name.startswith(".")
            ]
        )

    for tsv_path in tsv_files:
        if not tsv_path.exists():
            print(f"Category TSV not found: {tsv_path.stem}", file=sys.stderr)
            return 1

        rows = _load_tsv_questions(tsv_path)
        for row in rows:
            total_checked += 1
            q_text = (row.get("question") or "").strip()
            a_text = (row.get("answer") or "").strip()
            cat = (row.get("category") or tsv_path.stem).strip()
            qid = (row.get("id") or "").strip()

            if not q_text:
                issues_found.append(
                    (
                        qid or f"{cat}/unknown",
                        QuestionValidationError("MALFORMED", "Missing question text", False),
                    )
                )
                continue

            parsed = ParsedQuestion(question=q_text, answer=a_text, category=cat)

            error = validate_question(parsed)
            if error:
                issues_found.append((qid or f"{cat}/unknown", error))
                if verbose:
                    print(f"  {qid}: {error}")

    print("\nValidation Results:")
    print(f"  Total questions checked: {total_checked}")
    print(f"  Questions with issues: {len(issues_found)}")

    if issues_found:
        # Group by error type
        errors_by_type: dict[str, list[tuple[str, QuestionValidationError]]] = {}
        for path, err in issues_found:
            if err.error_type not in errors_by_type:
                errors_by_type[err.error_type] = []
            errors_by_type[err.error_type].append((path, err))

        print("\nIssues by Type:")
        for error_type, errors in sorted(errors_by_type.items(), key=lambda x: -len(x[1])):
            print(f"\n  {error_type}: {len(errors)} questions")
            if verbose or len(errors) <= 5:
                for path, err in errors[:10]:
                    print(f"    - {path}")
                if len(errors) > 10:
                    print(f"    ... and {len(errors) - 10} more")

        if not verbose and len(issues_found) > 5:
            print("\n  Use --verbose to see all issues")

        return 1

    print("\nAll questions passed validation!", file=sys.stderr)
    return 0


def cmd_reindex(args) -> int:
    """Rebuild the CAS index from canonical TSV questions."""
    print("Rebuilding CAS index from canonical TSV questions...", file=sys.stderr)

    cas = QuestionCAS()
    cas._index = {}  # Clear
    cas._loaded = True

    if not CARDS_DIR.exists():
        print("flashcard-import: error: no cards directory found", file=sys.stderr)
        return 1

    count = 0
    for tsv_path in sorted(CARDS_DIR.glob("*.tsv")):  # lint-ok: INV8 read-only import
        if tsv_path.name.startswith("."):
            continue
        rows = _load_tsv_questions(tsv_path)
        for row in rows:
            q_text = (row.get("question") or "").strip()
            qid = (row.get("id") or "").strip()
            if q_text and qid:
                cas.add(q_text, qid, "existing")
                count += 1

    cas.save()
    print(f"Indexed {count} existing questions from canonical TSV", file=sys.stderr)
    return 0


# =============================================================================
# Main Entry Point
# =============================================================================


def main(argv: list | None = None) -> int:
    """Main entry point."""
    parser = argparse.ArgumentParser(description="Import interview questions from external sources")
    subparsers = parser.add_subparsers(dest="command", help="Command")

    # import
    p_import = subparsers.add_parser("import", help="Import from a repo")
    p_import.add_argument("repo", help="Repository URL or github shorthand (user/repo)")
    p_import.add_argument(
        "--dry-run", action="store_true", help="Show what would be imported without making changes"
    )
    p_import.add_argument(
        "--strict",
        action="store_true",
        default=True,
        help="Reject questions with validation issues (default)",
    )
    p_import.add_argument(
        "--no-strict",
        action="store_false",
        dest="strict",
        help="Import questions even if they have validation issues",
    )
    p_import.add_argument(
        "--verbose", action="store_true", help="Show validation errors as they occur"
    )
    p_import.add_argument(
        "--show-errors",
        action="store_true",
        help="Show detailed validation error messages in summary",
    )
    p_import.set_defaults(func=cmd_import)

    # list
    p_list = subparsers.add_parser("list", help="List imported repos")
    p_list.set_defaults(func=cmd_list)

    # status
    p_status = subparsers.add_parser("status", help="Show dedup stats")
    p_status.set_defaults(func=cmd_status)

    # check
    p_check = subparsers.add_parser("check", help="Check what would be imported (dry run)")
    p_check.add_argument("repo", help="Repository URL")
    p_check.add_argument(
        "--verbose", action="store_true", help="Show validation errors as they occur"
    )
    p_check.add_argument(
        "--show-errors", action="store_true", help="Show detailed validation error messages"
    )
    p_check.set_defaults(func=cmd_check)

    # validate
    p_validate = subparsers.add_parser(
        "validate",
        help="Validate existing questions for quality issues",
    )
    p_validate.add_argument(
        "category", nargs="?", default=None, help="Category to validate (default: all)"
    )
    p_validate.add_argument("--verbose", action="store_true", help="Show all issues in detail")
    p_validate.set_defaults(func=cmd_validate)

    # reindex
    p_reindex = subparsers.add_parser("reindex", help="Rebuild CAS index from canonical TSV")
    p_reindex.set_defaults(func=cmd_reindex)

    args = parser.parse_args(argv)

    if args.command is None:
        parser.print_help()
        return 1

    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
