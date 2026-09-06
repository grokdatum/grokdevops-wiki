#!/usr/bin/env bash
set -euo pipefail

LAB_ROOT="/tmp/lab-cicd"

echo "=== CI/CD Pipeline Lab Setup ==="

rm -rf "${LAB_ROOT}"
mkdir -p "${LAB_ROOT}"/{src,tests}

echo "[1/5] Creating Python application..."
cat > "${LAB_ROOT}/src/app.py" <<'EOF'
from flask import Flask, jsonify

app = Flask(__name__)


@app.route("/")
def index():
    return jsonify({"status": "ok", "version": "1.0.0"})


@app.route("/health")
def health():
    return jsonify({"healthy": True})


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
EOF

echo "[2/5] Creating tests..."
cat > "${LAB_ROOT}/tests/test_app.py" <<'EOF'
import pytest
from src.app import app


@pytest.fixture
def client():
    app.config["TESTING"] = True
    with app.test_client() as client:
        yield client


def test_index(client):
    response = client.get("/")
    assert response.status_code == 200
    assert response.json["status"] == "ok"


def test_health(client):
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json["healthy"] is True
EOF

echo "[3/5] Creating requirements and config files..."
cat > "${LAB_ROOT}/requirements.txt" <<'EOF'
flask==3.0.0
pytest==7.4.3
flake8==6.1.0
EOF

cat > "${LAB_ROOT}/setup.cfg" <<'EOF'
[flake8]
max-line-length = 120
exclude = .git,__pycache__,venv
EOF

echo "[4/5] Creating Dockerfile..."
cat > "${LAB_ROOT}/Dockerfile" <<'EOF'
FROM python:3.12-slim

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY src/ ./src/
EXPOSE 5000

HEALTHCHECK --interval=30s --timeout=3s \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:5000/health')" || exit 1

CMD ["python", "src/app.py"]
EOF

echo "[5/5] Initializing git repository..."
cd "${LAB_ROOT}"
git init -q
git config user.email "lab@example.com"
git config user.name "Lab User"
mkdir -p .github/workflows
touch .github/workflows/.gitkeep
git add . && git commit -q -m "Initial project setup"

echo ""
echo "=== Setup Complete ==="
echo "Project at: ${LAB_ROOT}"
echo ""
echo "Project structure:"
echo "  src/app.py         — Flask application"
echo "  tests/test_app.py  — Pytest tests"
echo "  Dockerfile         — Container build"
echo "  requirements.txt   — Python dependencies"
echo ""
echo "Your mission:"
echo "  Create .github/workflows/ci.yml with:"
echo "  lint -> test -> build -> scan -> deploy"
echo ""
echo "Run ./grade.sh when done."
