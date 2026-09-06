#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../_cli.sh"
runtime_lab_parse_cli "$@"

NAMESPACE="${NAMESPACE:-grokdevops}"
echo "[break] Introducing drift: manually scaling deployment outside of Helm..."
kubectl scale deployment grokdevops -n "$NAMESPACE" --replicas=5
echo "[break] Introducing drift: adding a rogue environment variable..."
kubectl set env deployment/grokdevops -n "$NAMESPACE" ROGUE_VAR=injected-outside-git
echo "[break] Current state has drifted from what Helm/Git declares."
echo "[break] In a GitOps setup, ArgoCD would detect this as OutOfSync."
echo "[break] Check: kubectl get deployment grokdevops -n $NAMESPACE -o yaml | grep -A5 env"
echo "[break] Check: kubectl get deployment grokdevops -n $NAMESPACE -o jsonpath='{.spec.replicas}'"
