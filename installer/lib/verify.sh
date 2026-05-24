#!/usr/bin/env bash

set -Eeuo pipefail
IFS=$'\n\t'

VERIFY_WARNINGS=()
VERIFY_TIMEOUT_SECONDS="${NEXTGN_VERIFY_TIMEOUT_SECONDS:-180}"
VERIFY_RETRY_INTERVAL_SECONDS="${NEXTGN_VERIFY_RETRY_INTERVAL_SECONDS:-5}"

retry_until_timeout() {
  local description="$1"; shift
  local timeout_seconds="$1"; shift
  local interval="$1"; shift
  local elapsed=0

  until "$@"; do
    if (( elapsed >= timeout_seconds )); then
      print_warn "Verification warning: ${description} timed out after ${timeout_seconds}s."
      return 1
    fi
    sleep "${interval}"
    elapsed=$((elapsed + interval))
  done
  return 0
}

verify_installation() {
  local install_dir="$1" domain="$2" tls_enabled="$3" dry_run="$4"
  if [[ "${dry_run}" == 'true' ]]; then print_info 'DRY-RUN: verification skipped.'; return 0; fi

  run_cmd "${dry_run}" bash -lc "cd '${install_dir}' && docker compose -f deploy/docker-compose.prod.yml ps"
  verify_container_state "${install_dir}" app
  verify_container_state "${install_dir}" queue
  verify_container_state "${install_dir}" scheduler

  verify_http "http://127.0.0.1" 'HTTP'
  if [[ "${tls_enabled}" == 'true' ]]; then verify_http "https://${domain}" 'HTTPS'; fi

  run_cmd "${dry_run}" bash -lc "cd '${install_dir}' && docker compose -f deploy/docker-compose.prod.yml exec -T app php artisan about >/dev/null"
}

is_service_healthy() {
  local install_dir="$1" service="$2" state compose_output
  state=''
  if compose_output="$(cd "${install_dir}" && docker compose -f deploy/docker-compose.prod.yml ps --format json "${service}" 2>/dev/null)"; then
    state="$(printf '%s\n' "${compose_output}" | sed -n 's/.*"State":"\([^"]*\)".*/\1/p' | head -n1)"
  fi
  [[ "${state}" == 'running' || "${state}" == 'healthy' ]]
}

verify_container_state() {
  local install_dir="$1" service="$2"
  if retry_until_timeout "container ${service}" "${VERIFY_TIMEOUT_SECONDS}" "${VERIFY_RETRY_INTERVAL_SECONDS}" is_service_healthy "${install_dir}" "${service}"; then
    print_success "Verification passed: ${service} is running/healthy."
  else
    VERIFY_WARNINGS+=("Service ${service} did not become healthy in time.")
  fi
}

is_http_up() { local url="$1"; curl -fsS --max-time 10 "${url}" >/dev/null; }
verify_http() {
  local url="$1" label="$2"
  if retry_until_timeout "${label} check for ${url}" "${VERIFY_TIMEOUT_SECONDS}" "${VERIFY_RETRY_INTERVAL_SECONDS}" is_http_up "${url}"; then
    print_success "Verification passed: ${label} response from ${url}."
  else
    VERIFY_WARNINGS+=("${label} check failed for ${url}.")
  fi
}
