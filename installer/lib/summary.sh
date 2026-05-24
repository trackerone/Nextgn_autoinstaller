#!/usr/bin/env bash

set -Eeuo pipefail
IFS=$'\n\t'

print_install_summary() {
  local domain="$1" install_dir="$2" tls_enabled="$3"
  local app_url="http://${domain}"

  if [[ "${tls_enabled}" == 'true' ]]; then
    app_url="https://${domain}"
  fi

  echo
  print_info 'Install summary:'
  printf '  Domain: %s\n' "${domain}"
  printf '  Install path: %s\n' "${install_dir}"
  printf '  App URL: %s\n' "${app_url}"
  printf '  Log path: %s\n' "${LOG_FILE}"
  printf '  State path: %s\n' "${STATE_FILE}"
  printf '  Next steps: %s\n' 'Review .env secrets, run admin bootstrap command, validate backups/monitoring.'

  if (( ${#VERIFY_WARNINGS[@]} > 0 )); then
    print_warn 'Warnings detected during DNS/TLS/health verification:'
    printf '  - %s\n' "${VERIFY_WARNINGS[@]}"
  fi
}
