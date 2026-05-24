#!/usr/bin/env bash

set -Eeuo pipefail
IFS=$'\n\t'

on_error() {
  local exit_code="$?"
  local line_no="${1:-unknown}"
  local cmd="${2:-unknown}"
  print_error "Installer failed at line ${line_no}: ${cmd} (exit: ${exit_code})"
  log_message 'ERROR' "line=${line_no} cmd=${cmd} exit=${exit_code}"
  exit "${exit_code}"
}

setup_error_trap() {
  trap 'on_error "${LINENO}" "${BASH_COMMAND}"' ERR
}
