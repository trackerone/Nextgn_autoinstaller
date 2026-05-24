#!/usr/bin/env bash

set -Eeuo pipefail
IFS=$'\n\t'

setup_tls() {
  local install_dir="$1" domain="$2" dry_run="$3" force="$4"
  local cert_dir="${install_dir}/deploy/certs/live/${domain}"

  if [[ "${dry_run}" == 'true' ]]; then
    print_info 'DRY-RUN: TLS setup skipped.'
    return 0
  fi

  if [[ -d "${cert_dir}" && "${force}" != 'true' ]]; then
    print_warn "Existing certificates found at ${cert_dir}; skipping TLS setup (use --force to renew)."
    return 0
  fi

  print_info 'TLS requires DNS A/AAAA records for the domain to resolve to this host before issuance.'
  run_cmd "${dry_run}" mkdir -p "${install_dir}/deploy/certs"
  run_cmd "${dry_run}" bash -lc "cd '${install_dir}' && docker compose -f deploy/docker-compose.prod.yml run --rm certbot certonly --standalone --non-interactive --agree-tos --register-unsafely-without-email -d '${domain}'"
}
