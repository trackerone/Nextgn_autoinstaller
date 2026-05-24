#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

run_cmd() {
  local dry_run="$1"
  shift

  if [[ "${dry_run}" == 'true' ]]; then
    print_info "DRY-RUN: $*"
    log_message 'DRY-RUN' "$*"
    return 0
  fi

  print_info "RUN: $*"
  log_message 'RUN' "$*"
  "$@"
}
