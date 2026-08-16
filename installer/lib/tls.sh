#!/usr/bin/env bash

set -Eeuo pipefail
IFS=$'\n\t'

setup_tls() {
  local install_dir="$1" domain="$2" dry_run="$3" force="$4"

  if [[ "${dry_run}" == 'true' ]]; then
    print_info 'DRY-RUN: TLS setup skipped.'
    return 0
  fi

  print_info "Caddy manages HTTPS certificates and automatic renewal for ${domain}."
  if [[ "${force}" == 'true' ]]; then
    print_info 'Force mode keeps the existing Caddy certificate state and revalidates the active configuration.'
  fi

  run_cmd "${dry_run}" bash -lc "cd '${install_dir}' && docker compose -f deploy/docker-compose.prod.yml exec -T caddy caddy validate --config /etc/caddy/Caddyfile"
}
