#!/usr/bin/env bash

set -Eeuo pipefail
IFS=$'\n\t'

VERIFY_WARNINGS=()

verify_installation() {
  local install_dir="$1" domain="$2" tls_enabled="$3" dry_run="$4"

  if [[ "${dry_run}" == 'true' ]]; then
    print_info 'DRY-RUN: verification skipped.'
    return 0
  fi

  run_cmd "${dry_run}" bash -lc "cd '${install_dir}' && docker compose -f deploy/docker-compose.prod.yml ps"

  verify_container_state "${install_dir}" app
  verify_container_state "${install_dir}" queue
  verify_container_state "${install_dir}" scheduler

  verify_http "http://127.0.0.1" 'HTTP'
  if [[ "${tls_enabled}" == 'true' ]]; then
    verify_http "https://${domain}" 'HTTPS'
  fi

  run_cmd "${dry_run}" bash -lc "cd '${install_dir}' && docker compose -f deploy/docker-compose.prod.yml exec -T app php artisan about >/dev/null"
}

verify_container_state() {
  local install_dir="$1" service="$2"
  local state compose_output

  state=''
  if compose_output="$(cd "${install_dir}" && docker compose -f deploy/docker-compose.prod.yml ps --format json "${service}" 2>/dev/null)"; then
    state="$(printf '%s\n' "${compose_output}" | rg -o '"State":"[^"]+"' | head -n1 | cut -d':' -f2 | tr -d '"')"
  fi
  if [[ "${state}" != 'running' && "${state}" != 'healthy' ]]; then
    VERIFY_WARNINGS+=("Service ${service} is not healthy/running.")
    print_warn "Verification warning: ${service} state='${state:-unknown}'."
  else
    print_success "Verification passed: ${service} is ${state}."
  fi
}

verify_http() {
  local url="$1" label="$2"
  if curl -fsS --max-time 10 "${url}" >/dev/null; then
    print_success "Verification passed: ${label} response from ${url}."
  else
    VERIFY_WARNINGS+=("${label} check failed for ${url}.")
    print_warn "Verification warning: ${label} check failed for ${url}."
  fi
}
