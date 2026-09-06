#!/usr/bin/env bash
set -euo pipefail

LAB_ROOT="/tmp/lab-container-basics"

echo "=== Container Basics Lab Setup ==="
echo "Creating broken container project at ${LAB_ROOT}..."

# Idempotent cleanup
rm -rf "${LAB_ROOT}"
mkdir -p "${LAB_ROOT}"

# --- Create a simple Node.js app ---
cat > "${LAB_ROOT}/package.json" <<'EOF'
{
  "name": "broken-container-app",
  "version": "1.0.0",
  "description": "A badly containerized app",
  "main": "server.js",
  "scripts": {
    "start": "node server.js"
  },
  "dependencies": {
    "express": "^4.18.2"
  }
}
EOF

cat > "${LAB_ROOT}/server.js" <<'EOF'
const express = require('express');
const app = express();
const PORT = 3000;

app.get('/', (req, res) => res.json({ status: 'ok', app: 'container-basics-lab' }));
app.get('/health', (req, res) => res.json({ healthy: true }));

app.listen(PORT, () => console.log(`Server running on port ${PORT}`));
EOF

# --- Create the broken Dockerfile ---
cat > "${LAB_ROOT}/Dockerfile" <<'DOCKER'
# BAD Dockerfile — fix me!
FROM node:20

# Copies everything including .git and node_modules
COPY . /app
WORKDIR /app

# Installs deps AFTER copying all source (cache-busting)
RUN npm install

# Runs as root (bad!)
# No health check

EXPOSE 3000
CMD ["node", "server.js"]
DOCKER

# --- Create a fake .git directory and node_modules to bloat the context ---
mkdir -p "${LAB_ROOT}/.git/objects"
dd if=/dev/urandom of="${LAB_ROOT}/.git/objects/pack-data" bs=1M count=5 status=none

mkdir -p "${LAB_ROOT}/node_modules/.cache"
dd if=/dev/urandom of="${LAB_ROOT}/node_modules/.cache/junk" bs=1M count=10 status=none

# Create some markdown files that shouldn't be in the image
echo "# README" > "${LAB_ROOT}/README.md"
echo "# Contributing" > "${LAB_ROOT}/CONTRIBUTING.md"

echo ""
echo "=== Setup Complete ==="
echo "Broken project at: ${LAB_ROOT}"
echo ""
echo "Your mission:"
echo "  1. Rewrite the Dockerfile with multi-stage build"
echo "  2. Get the image under 200 MB"
echo "  3. Run as non-root user"
echo "  4. Fix layer caching (package.json copied before source)"
echo "  5. Add .dockerignore"
echo "  6. Add a health check"
echo "  7. Verify the container starts on port 3000"
echo ""
echo "Run ./grade.sh when done."
