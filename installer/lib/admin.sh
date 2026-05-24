#!/usr/bin/env bash

set -Eeuo pipefail
IFS=$'\n\t'

bootstrap_admin_placeholder() {
  local install_dir="$1" dry_run="$2"

  print_info 'TODO: Create first sysop interactively after deploy (no hardcoded credentials).'
  print_info "Suggested command: cd '${install_dir}' && docker compose -f deploy/docker-compose.prod.yml exec app php artisan nextgn:sysop:create"
  if [[ "${dry_run}" == 'false' ]]; then
    log_message 'INFO' 'Admin bootstrap placeholder emitted; operator action required.'
  fi
}
