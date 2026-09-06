#!/usr/bin/env bash
# Shared helpers for chaos scripts

APPROVED_NAMESPACES="grokdevops monitoring argocd kube-system"
DRY_RUN=true
NAMESPACE="grokdevops"
FORCE_UNSAFE=false

chaos_usage() {
  local command="${0##*/}"

  case "$command" in
    break_readiness.sh)
      echo "Usage: $command [options]"
      echo "Preview or break the grokdevops deployment readiness probe."
      ;;
    cpu_stress.sh)
      echo "Usage: $command [options]"
      echo "Preview or run a temporary CPU stress pod."
      echo "Environment: DURATION sets the run time in seconds (default: 60)."
      ;;
    inject_bad_configmap.sh)
      echo "Usage: $command [options]"
      echo "Preview or inject a bad ConfigMap into the grokdevops deployment."
      ;;
    kill_pods.sh)
      echo "Usage: $command [--label SELECTOR] [--count N|all] [options]"
      echo "Preview or delete pods selected by a Kubernetes label."
      echo "  --label SELECTOR  Pod label selector (default: app.kubernetes.io/name=grokdevops)."
      echo "  --count N|all     Number of pods to delete (default: all)."
      ;;
    mem_stress.sh)
      echo "Usage: $command [options]"
      echo "Preview or run a temporary memory stress pod."
      echo "Environment: MEM_MB sets memory in MiB (default: 128); DURATION sets seconds (default: 60)."
      ;;
    scale_to_zero.sh)
      echo "Usage: $command [options]"
      echo "Preview or temporarily scale the grokdevops deployment to zero replicas."
      ;;
    toggle_networkpolicy.sh)
      echo "Usage: $command [apply|remove] [options]"
      echo "Preview or apply/remove the chaos deny-all NetworkPolicy (default action: apply)."
      ;;
    *)
      echo "Usage: $command [options]"
      echo "Run a namespace-scoped chaos exercise."
      ;;
  esac

  cat <<'EOF'

Common options:
  --dry-run                  Preview only (default).
  --yes                      Execute the chaos action.
  --namespace NS             Target namespace (default: grokdevops).
  --i-know-what-im-doing     Allow a namespace outside the approved list.
  -h, --help                 Show this help and exit.
EOF
}

chaos_arg_error() {
  printf '%s: error: %s\n' "${0##*/}" "$1" >&2
  printf "Try '%s --help' for usage.\n" "${0##*/}" >&2
  exit 2
}

chaos_parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help) chaos_usage; exit 0 ;;
      --dry-run) DRY_RUN=true; shift ;;
      --yes) DRY_RUN=false; shift ;;
      --namespace)
        if [[ $# -lt 2 || -z "$2" || "$2" == -* ]]; then
          chaos_arg_error "option --namespace requires a value"
        fi
        NAMESPACE="$2"
        shift 2
        ;;
      --namespace=) chaos_arg_error "option --namespace requires a value" ;;
      --namespace=*) NAMESPACE="${1#*=}"; shift ;;
      --i-know-what-im-doing) FORCE_UNSAFE=true; shift ;;
      -*) chaos_arg_error "unknown option: $1" ;;
      *) chaos_arg_error "unexpected argument: $1" ;;
    esac
  done
}

chaos_check_namespace() {
  local ns="$1"
  local allowed=false
  for approved in $APPROVED_NAMESPACES; do
    if [[ "$ns" == "$approved" ]]; then
      allowed=true
      break
    fi
  done
  if [[ "$allowed" == "false" ]] && [[ "$FORCE_UNSAFE" == "false" ]]; then
    echo "[ERROR] Namespace '$ns' is not in the approved list: $APPROVED_NAMESPACES"
    echo "[ERROR] Pass --i-know-what-im-doing to override."
    exit 1
  fi
}

chaos_print_mode() {
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "[DRY-RUN] Preview mode. Pass --yes to execute."
  else
    echo "[LIVE] Executing against namespace: $NAMESPACE"
  fi
}
