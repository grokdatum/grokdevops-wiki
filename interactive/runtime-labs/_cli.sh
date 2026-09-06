# shellcheck shell=bash
# Shared command-line contract for runtime-lab break/fix/verify/teardown scripts.

runtime_lab_usage() {
  local command="${0##*/}"
  local summary

  case "$command" in
    break.sh) summary="Introduce the controlled failure for this runtime lab." ;;
    fix.sh) summary="Apply the documented fix for this runtime lab." ;;
    verify.sh) summary="Verify the expected healthy state for this runtime lab." ;;
    teardown.sh) summary="Restore this runtime lab to its documented baseline." ;;
    *) summary="Run one phase of an interactive runtime lab." ;;
  esac

  printf 'Usage: %s [-h|--help]\n' "$command"
  printf '\n%s\n' "$summary"
  printf '\nOptions:\n'
  printf '  -h, --help  Show this help and exit.\n'
  printf '\nThis command accepts no positional arguments.\n'
}

runtime_lab_arg_error() {
  printf '%s: error: %s\n' "${0##*/}" "$1" >&2
  printf "Try '%s --help' for usage.\n" "${0##*/}" >&2
  exit 2
}

runtime_lab_parse_cli() {
  if (( $# == 0 )); then
    return 0
  fi

  if (( $# == 1 )) && [[ "$1" == "-h" || "$1" == "--help" ]]; then
    runtime_lab_usage
    exit 0
  fi

  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    runtime_lab_arg_error "the help option does not accept arguments"
  elif [[ "$1" == -* ]]; then
    runtime_lab_arg_error "unknown option: $1"
  else
    runtime_lab_arg_error "unexpected argument: $1"
  fi
}
