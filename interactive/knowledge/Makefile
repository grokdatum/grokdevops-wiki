# Knowledge Project Makefile
#
# Usage:
#   make help          # Show available targets
#   make check         # Run all knowledge project checks
#   make test          # Run pytest tests
#   make lint          # Check Python syntax and TSV headers
#
# This project contains:
#   - Flashcard tools (flashcard, flashcard-import, flashcard-tsv)
#   - Knowledge audit tools (gd-knowledge-audit, kb-audit)
#   - Canonical TSV card corpus (data/cards/)
#   - Interview Q&A corpus (interview/)

.PHONY: help check test lint

help:
	@echo "Knowledge Project"
	@echo ""
	@echo "Usage:"
	@echo "  make check    - Run all knowledge project checks"
	@echo "  make test     - Run pytest tests"
	@echo "  make lint     - Check Python syntax and TSV headers"

# Full check: lint + tests
check: lint test
	@echo ""
	@echo "=== All knowledge checks passed ==="

# Python syntax and TSV header validation
lint:
	@echo "=== Knowledge Project Lint ==="
	@echo ""
	@errors=0; \
	echo "[1/3] Python syntax (knowledge libs)..."; \
	for f in lib/flashcard_lib.py lib/flashcard_import_lib.py flashcard-tsv; do \
		python3 -m py_compile "$$f" 2>/dev/null || { echo "  FAIL: $$f"; errors=$$((errors + 1)); }; \
	done; \
	echo "  Checked knowledge Python files"; \
	echo ""; \
	echo "[2/3] Canonical TSV headers..."; \
	expected_header="id	category	difficulty	tags	question	answer	source_path"; \
	for f in data/cards/*.tsv; do \
		header=$$(awk '/^id\t/{print; exit}' "$$f" | tr -d '\r'); \
		if [ "$$header" != "$$expected_header" ]; then \
			echo "  FAIL: $$f has wrong header"; \
			errors=$$((errors + 1)); \
		fi; \
	done; \
	echo "  Checked TSV headers"; \
	echo ""; \
	echo "[3/3] No legacy txt files in interview/..."; \
	txt_count=$$(find interview -name '*.txt' -type f 2>/dev/null | wc -l); \
	if [ "$$txt_count" -gt 0 ]; then \
		echo "  FAIL: $$txt_count legacy txt files still present"; \
		errors=$$((errors + 1)); \
	else \
		echo "  No legacy txt files found (good)"; \
	fi; \
	echo ""; \
	if [ $$errors -gt 0 ]; then \
		echo "=== LINT FAILED: $$errors checks failed ==="; \
		exit 1; \
	fi; \
	echo "=== Lint passed ==="

# Run pytest tests
test:
	@echo "=== Knowledge Project Tests ==="
	@if python3 -c "import pytest" 2>/dev/null; then \
		python3 -m pytest tests/ -v --tb=short; \
	else \
		echo "pytest not installed, skipping tests"; \
	fi
