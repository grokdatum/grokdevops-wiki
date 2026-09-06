"""Tests for trainer normalization, matching, and data loading."""

import csv
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from trainer import filter_cards, find_mismatch, load_cards, normalize  # noqa: I001, E402


# ---------------------------------------------------------------------------
# normalize()
# ---------------------------------------------------------------------------


def test_normalize_strips_whitespace():
    assert normalize("  kubectl get pods  ") == "kubectl get pods"


def test_normalize_collapses_spaces():
    assert normalize("kubectl   get    pods") == "kubectl get pods"


def test_normalize_tabs_and_mixed():
    assert normalize("kubectl\tget\t pods") == "kubectl get pods"


def test_normalize_empty():
    assert normalize("") == ""


def test_normalize_single_word():
    assert normalize("  top  ") == "top"


# ---------------------------------------------------------------------------
# find_mismatch()
# ---------------------------------------------------------------------------


def test_mismatch_wrong_token():
    result = find_mismatch("kubectl get pods", "kubectl get nodes")
    assert "token 3" in result
    assert "'pods'" in result
    assert "'nodes'" in result


def test_mismatch_missing_tokens():
    result = find_mismatch("kubectl get pods -A", "kubectl get pods")
    assert "missing" in result.lower()


def test_mismatch_extra_tokens():
    result = find_mismatch("kubectl get pods", "kubectl get pods -A")
    assert "extra" in result.lower()


def test_mismatch_first_token():
    result = find_mismatch("helm list -A", "kubectl list -A")
    assert "token 1" in result


# ---------------------------------------------------------------------------
# load_cards()
# ---------------------------------------------------------------------------


def _write_tsv(rows):
    """Helper: write rows to a temp TSV and return the path."""
    header = [
        "id",
        "category",
        "difficulty",
        "text",
        "what_it_does",
        "details",
        "source_hint",
        "tags",
    ]
    f = tempfile.NamedTemporaryFile(mode="w", suffix=".tsv", delete=False, newline="")
    writer = csv.writer(f, delimiter="\t")
    writer.writerow(header)
    for row in rows:
        writer.writerow(row)
    f.flush()
    f.close()
    return Path(f.name)


def test_load_cards():
    path = _write_tsv(
        [
            [
                "test-1",
                "kubectl",
                "1",
                "kubectl get pods",
                "list pods",
                "basic",
                "seed",
                "k8s-daily,pods",
            ],
            [
                "test-2",
                "python",
                "1",
                'print("hello")',
                "print hello",
                "basic output",
                "seed",
                "python-basics",
            ],
        ]
    )
    cards = load_cards(path)
    path.unlink()

    assert len(cards) == 2
    assert cards[0]["text"] == "kubectl get pods"
    assert cards[1]["category"] == "python"


def test_load_cards_skips_empty_text():
    path = _write_tsv(
        [
            ["test-1", "kubectl", "1", "kubectl get pods", "list pods", "", "seed", ""],
            ["test-2", "kubectl", "1", "", "empty", "", "seed", ""],
        ]
    )
    cards = load_cards(path)
    path.unlink()

    assert len(cards) == 1


def test_load_real_cards_tsv():
    """Verify the actual cards.tsv loads without errors."""
    tsv_path = Path(__file__).resolve().parent.parent / "cards.tsv"
    if tsv_path.exists():
        cards = load_cards(tsv_path)
        assert len(cards) > 100
        for card in cards:
            assert card["text"].strip(), f"Empty text in row: {card}"


# ---------------------------------------------------------------------------
# filter_cards()
# ---------------------------------------------------------------------------


def test_filter_by_category():
    cards = [
        {"category": "kubectl", "text": "kubectl get pods"},
        {"category": "git", "text": "git status"},
        {"category": "kubectl", "text": "kubectl logs"},
    ]
    result = filter_cards(cards, category="kubectl")
    assert len(result) == 2


def test_filter_by_difficulty():
    cards = [
        {"difficulty": "1", "text": "a"},
        {"difficulty": "2", "text": "b"},
        {"difficulty": "1", "text": "c"},
    ]
    result = filter_cards(cards, difficulty="1")
    assert len(result) == 2


def test_filter_by_tags():
    cards = [
        {"tags": "k8s-daily,pods", "text": "a"},
        {"tags": "git-daily,branch", "text": "b"},
        {"tags": "k8s-daily,logs", "text": "c"},
    ]
    result = filter_cards(cards, tags="k8s-daily")
    assert len(result) == 2


def test_filter_by_workflow_tag():
    """Workflow subset tags like k8s-debug, python-basics work."""
    cards = [
        {"tags": "k8s-daily,pods", "text": "a"},
        {"tags": "k8s-debug,logs", "text": "b"},
        {"tags": "python-basics,print", "text": "c"},
    ]
    result = filter_cards(cards, tags="k8s-debug")
    assert len(result) == 1
    assert result[0]["text"] == "b"


def test_filter_combined():
    cards = [
        {"category": "kubectl", "difficulty": "1", "text": "a"},
        {"category": "kubectl", "difficulty": "2", "text": "b"},
        {"category": "git", "difficulty": "1", "text": "c"},
    ]
    result = filter_cards(cards, category="kubectl", difficulty="1")
    assert len(result) == 1
    assert result[0]["text"] == "a"


# ---------------------------------------------------------------------------
# Python snippet cards
# ---------------------------------------------------------------------------


def test_python_card_matching():
    expected = normalize('print(f"count: {n}")')
    actual = normalize('print(f"count: {n}")')
    assert expected == actual


def test_python_card_mismatch():
    result = find_mismatch('print("hello")', 'print("world")')
    assert "token 1" in result


# ---------------------------------------------------------------------------
# Exact matching behavior
# ---------------------------------------------------------------------------


def test_exact_match_required():
    assert normalize("kubectl") != normalize("kubectl get pods")


def test_option_order_matters():
    assert normalize("kubectl get pods -A") != normalize("kubectl get -A pods")
