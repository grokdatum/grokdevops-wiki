#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

DURATION="${DURATION:-60}"
MEM_MB="${MEM_MB:-128}"
chaos_parse_args "$@"
chaos_check_namespace "$NAMESPACE"
chaos_print_mode

echo "[chaos] Will run memory stress pod in namespace '$NAMESPACE' (${MEM_MB}MB for ${DURATION}s)"

if [[ "$DRY_RUN" == "true" ]]; then
  echo "[DRY-RUN] Would create pod 'chaos-mem-stress' consuming ~${MEM_MB}MB"
  echo "[DRY-RUN] With limit of $((MEM_MB + 32))Mi — may OOMKill if MEM_MB > limit"
  exit 0
fi

kubectl delete pod chaos-mem-stress -n "$NAMESPACE" --ignore-not-found=true 2>/dev/null

echo "[chaos] Creating memory stress pod..."
kubectl run chaos-mem-stress -n "$NAMESPACE" \
  --image=busybox:1.36 \
  --restart=Never \
  --labels="chaos=mem-stress" \
  --overrides='{
    "spec": {
      "containers": [{
        "name": "chaos-mem-stress",
        "image": "busybox:1.36",
        "command": ["sh", "-c", "dd if=/dev/zero bs=1M count='"$MEM_MB"' | sleep '"$DURATION"'; echo done"],
        "resources": {"requests": {"memory": "64Mi"}, "limits": {"memory": "'"$((MEM_MB + 32))"'Mi"}}
      }],
      "terminationGracePeriodSeconds": 1
    }
  }'

echo "[chaos] Memory stress pod running."
echo "[chaos] Monitor: kubectl top pods -n $NAMESPACE"
echo ""
echo "[CLEANUP] kubectl delete pod chaos-mem-stress -n $NAMESPACE"
