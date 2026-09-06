"""
Tests for gd-knowledge-audit stale knowledge detector.
"""

import os
import subprocess
from pathlib import Path

_KNOWLEDGE_ROOT = Path(__file__).resolve().parent.parent
TOOL = str(_KNOWLEDGE_ROOT / "gd-knowledge-audit")
FIXTURES = str(_KNOWLEDGE_ROOT / "tests" / "fixtures" / "knowledge-audit")


class TestGdKnowledgeAudit:
    """Tests for gd-knowledge-audit."""

    def test_help(self):
        result = subprocess.run([TOOL, "--help"], capture_output=True, text=True)
        assert result.returncode == 0

    def test_version(self):
        result = subprocess.run([TOOL, "--version"], capture_output=True, text=True)
        assert result.returncode == 0

    def test_scan_fixture_directory(self, tmp_path):
        """Scan fixture directory and find stale content."""
        result = subprocess.run(
            [TOOL, FIXTURES, "--data-home", str(tmp_path)], capture_output=True, text=True
        )
        assert result.returncode == 0
        # Should have header
        assert "severity\tfile\tline\tfinding\thint" in result.stdout
        # Should detect old date
        assert "2020-01-15" in result.stdout

    def test_read_only(self):
        """Tool does not modify any files in the scanned directory."""
        import shutil
        import tempfile

        with tempfile.TemporaryDirectory() as tmpdir:
            # Copy fixtures
            scan_dir = os.path.join(tmpdir, "scan")
            shutil.copytree(FIXTURES, scan_dir)
            data_home = os.path.join(tmpdir, "data")

            # Record file states before
            before = {}
            for f in os.listdir(scan_dir):
                fp = os.path.join(scan_dir, f)
                if os.path.isfile(fp):
                    before[f] = os.path.getmtime(fp)

            # Run audit
            subprocess.run(
                [TOOL, scan_dir, "--data-home", data_home], capture_output=True, text=True
            )

            # Verify no files changed
            for f, mtime in before.items():
                assert os.path.getmtime(os.path.join(scan_dir, f)) == mtime

    def test_deterministic_output(self, tmp_path):
        """Same input produces same output."""
        r1 = subprocess.run(
            [TOOL, FIXTURES, "--data-home", str(tmp_path / "r1")], capture_output=True, text=True
        )
        r2 = subprocess.run(
            [TOOL, FIXTURES, "--data-home", str(tmp_path / "r2")], capture_output=True, text=True
        )
        assert r1.stdout == r2.stdout

    def test_nonexistent_dir_fails(self):
        result = subprocess.run(
            [TOOL, "/tmp/nonexistent_dir_abc123"], capture_output=True, text=True
        )
        assert result.returncode != 0
