#!/usr/bin/env bash
set -euo pipefail

LAB_ROOT="/tmp/lab-terraform"

echo "=== Terraform IaC Lab Setup ==="

# Cleanup any previous containers from this lab
for c in lab-tf-web lab-tf-api lab-tf-db; do
    docker rm -f "${c}" 2>/dev/null || true
done
docker network rm lab-tf-network 2>/dev/null || true

rm -rf "${LAB_ROOT}"
mkdir -p "${LAB_ROOT}/modules/app-stack"

echo "[1/3] Creating project skeleton..."

cat > "${LAB_ROOT}/main.tf" <<'EOF'
# TODO: Configure the Docker provider and call the app-stack module
#
# Requirements:
#   1. Use the kreuzwerker/docker provider
#   2. Create a module block calling ./modules/app-stack
#   3. Pass variables for customization

terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

provider "docker" {}

# TODO: Add module "stack" block here
EOF

cat > "${LAB_ROOT}/variables.tf" <<'EOF'
# TODO: Define root-level variables that get passed to the module

variable "network_name" {
  description = "Name for the Docker network"
  type        = string
  default     = "lab-tf-network"
}

variable "web_image" {
  description = "Docker image for the web server"
  type        = string
  default     = "nginx:alpine"
}

variable "api_image" {
  description = "Docker image for the API server"
  type        = string
  default     = "hashicorp/http-echo:latest"
}

variable "db_image" {
  description = "Docker image for the database"
  type        = string
  default     = "redis:7-alpine"
}
EOF

cat > "${LAB_ROOT}/outputs.tf" <<'EOF'
# TODO: Define outputs (container IDs, network ID)
EOF

echo "[2/3] Creating module skeleton..."

cat > "${LAB_ROOT}/modules/app-stack/main.tf" <<'EOF'
# TODO: Implement the app-stack module
#
# This module should create:
#   1. A Docker network
#   2. Docker images (pull them)
#   3. Three containers: web, api, db
#   4. All containers on the shared network
EOF

cat > "${LAB_ROOT}/modules/app-stack/variables.tf" <<'EOF'
# TODO: Define module input variables
EOF

cat > "${LAB_ROOT}/modules/app-stack/outputs.tf" <<'EOF'
# TODO: Define module outputs (container IDs, network ID)
EOF

echo "[3/3] Verifying Terraform is available..."
if command -v terraform > /dev/null 2>&1; then
    echo "Terraform $(terraform version -json 2>/dev/null | python3 -c 'import sys,json;print(json.load(sys.stdin).get("terraform_version","unknown"))' 2>/dev/null || echo 'installed')"
else
    echo "WARNING: Terraform not found in PATH. Install it to complete this lab."
fi

echo ""
echo "=== Setup Complete ==="
echo "Project at: ${LAB_ROOT}"
echo ""
echo "Structure:"
echo "  main.tf              — Root module (needs module block)"
echo "  variables.tf         — Root variables (pre-populated)"
echo "  outputs.tf           — Root outputs (empty)"
echo "  modules/app-stack/   — Reusable module (needs implementation)"
echo ""
echo "Your mission:"
echo "  1. Implement the app-stack module"
echo "  2. Call it from main.tf"
echo "  3. terraform init && terraform apply"
echo ""
echo "Run ./grade.sh when done."
