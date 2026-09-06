#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../_cli.sh"
runtime_lab_parse_cli "$@"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
echo "[break] Creating a Dockerfile with an older, vulnerable base..."
mkdir -p "$SCRIPT_DIR/assets"
cat > "$SCRIPT_DIR/assets/Dockerfile.vulnerable" << 'EOF'
FROM python:3.9-slim-buster
RUN pip install flask==2.0.1
COPY <<-INNEREOF /app/main.py
from flask import Flask
app = Flask(__name__)

@app.route("/health")
def health():
    return "ok"
INNEREOF
CMD ["python", "/app/main.py"]
EOF
echo "[break] Building vulnerable test image..."
docker build -t grokdevops-vuln-test:latest -f "$SCRIPT_DIR/assets/Dockerfile.vulnerable" "$SCRIPT_DIR/assets/" 2>&1 || {
  echo "[break] Docker build failed. Ensure Docker is available."
  exit 1
}
echo "[break] Scanning with trivy..."
echo "  trivy image --severity CRITICAL,HIGH grokdevops-vuln-test:latest"
trivy image --severity CRITICAL,HIGH grokdevops-vuln-test:latest 2>/dev/null || {
  echo "[break] Trivy not installed. Install with: apt-get install trivy"
  echo "[break] Or review the README for expected output."
}
