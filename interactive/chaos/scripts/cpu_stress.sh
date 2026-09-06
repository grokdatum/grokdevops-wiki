#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

DURATION="${DURATION:-60}"
chaos_parse_args "$@"
chaos_check_namespace "$NAMESPACE"
chaos_print_mode

echo "[chaos] Will run CPU stress pod in namespace '$NAMESPACE' for ${DURATION}s"

if [[ "$DRY_RUN" == "true" ]]; then
  echo "[DRY-RUN] Would create pod 'chaos-cpu-stress' running: dd if=/dev/urandom of=/dev/null"
  echo "[DRY-RUN] Pod would auto-terminate after ${DURATION}s"
  exit 0
fi

# Clean up any existing stress pod
kubectl delete pod chaos-cpu-stress -n "$NAMESPACE" --ignore-not-found=true 2>/dev/null

echo "[chaos] Creating CPU stress pod..."
kubectl run chaos-cpu-stress -n "$NAMESPACE" \
  --image=busybox:1.36 \
  --restart=Never \
  --labels="chaos=cpu-stress" \
  --overrides='{
    "spec": {
      "containers": [{
        "name": "chaos-cpu-stress",
        "image": "busybox:1.36",
        "command": ["sh", "-c", "timeout '"$DURATION"' dd if=/dev/urandom of=/dev/null bs=1M; echo done"],
        "resources": {"requests": {"cpu": "500m"}, "limits": {"cpu": "1"}}
      }],
      "terminationGracePeriodSeconds": 1
    }
  }'

echo "[chaos] CPU stress pod running for ${DURATION}s."
echo "[chaos] Monitor: kubectl top pods -n $NAMESPACE"
echo ""
echo "[CLEANUP] To stop early:"
echo "  kubectl delete pod chaos-cpu-stress -n $NAMESPACE"
