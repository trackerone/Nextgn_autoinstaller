#!/usr/bin/env bash

set -Eeuo pipefail
IFS=$'\n\t'

ADMIN_MIN_PASSWORD_LENGTH=12

admin_bootstrap_enabled() {
  [[ "${CREATE_ADMIN:-false}" == 'true' ]]
}

print_admin_manual_guidance() {
  local install_dir="$1"
  print_info 'Admin bootstrap is disabled; run manual sysop creation after deploy.'
  print_info "Suggested command: cd '${install_dir}' && docker compose -f deploy/docker-compose.prod.yml exec app php artisan nextgn:sysop:create"
}

read_admin_password() {
  local password=''

  if [[ -n "${ADMIN_PASSWORD_FILE:-}" ]]; then
    [[ -f "${ADMIN_PASSWORD_FILE}" ]] || { print_error "Admin password file not found: ${ADMIN_PASSWORD_FILE}"; return 1; }
    [[ -r "${ADMIN_PASSWORD_FILE}" ]] || { print_error "Admin password file is not readable: ${ADMIN_PASSWORD_FILE}"; return 1; }
    password="$(head -n 1 "${ADMIN_PASSWORD_FILE}" | tr -d '\r')"
  elif [[ -n "${ADMIN_PASSWORD:-}" ]]; then
    password="${ADMIN_PASSWORD}"
  fi

  printf '%s' "${password}"
}

validate_admin_inputs() {
  local require_all="$1"
  local admin_password="$2"

  if [[ -n "${ADMIN_EMAIL:-}" ]] && [[ ! "${ADMIN_EMAIL}" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
    print_error 'Invalid admin email format.'
    return 1
  fi

  if [[ -n "${admin_password}" ]] && (( ${#admin_password} < ADMIN_MIN_PASSWORD_LENGTH )); then
    print_error "Admin password must be at least ${ADMIN_MIN_PASSWORD_LENGTH} characters long."
    return 1
  fi

  if [[ "${require_all}" == 'true' ]]; then
    [[ -n "${ADMIN_NAME:-}" ]] || { print_error 'Admin bootstrap enabled: --admin-name or NEXTGN_ADMIN_NAME is required.'; return 1; }
    [[ -n "${ADMIN_EMAIL:-}" ]] || { print_error 'Admin bootstrap enabled: --admin-email or NEXTGN_ADMIN_EMAIL is required.'; return 1; }
    [[ -n "${admin_password}" ]] || { print_error 'Admin bootstrap enabled: provide --admin-password-file or --admin-password.'; return 1; }
  fi

  return 0
}

create_first_admin() {
  local install_dir="$1"
  local admin_password="$2"

  print_and_log 'INFO' "RUN: Creating first sysop for ${ADMIN_EMAIL} (password via stdin; redacted)."

  local output
  set +e
  output="$(
    cd "${install_dir}" &&
      printf '%s\n' "${admin_password}" | docker compose -f deploy/docker-compose.prod.yml exec -T app php artisan nextgn:sysop:create \
        --name="${ADMIN_NAME}" \
        --email="${ADMIN_EMAIL}" \
        --password-stdin \
        --no-interaction 2>&1
  )"
  local status=$?
  set -e

  if [[ -n "${output}" ]]; then
    printf '%s\n' "${output}"
  fi

  if [[ ${status} -eq 0 ]]; then
    print_and_log 'SUCCESS' "Admin bootstrap completed for ${ADMIN_EMAIL}."
    return 0
  fi

  if printf '%s' "${output}" | grep -Eqi 'already exists|already initialized|already.*sysop'; then
    print_and_log 'WARN' 'Admin bootstrap reports existing sysop/admin; continuing (idempotent condition).'
    return 0
  fi

  print_error 'Admin bootstrap failed.'
  return ${status}
}

bootstrap_admin() {
  local install_dir="$1" dry_run="$2"
  local admin_password=''

  if ! admin_bootstrap_enabled; then
    print_admin_manual_guidance "${install_dir}"
    return 0
  fi

  if [[ -n "${ADMIN_PASSWORD:-}" ]] && [[ -n "${ADMIN_PASSWORD_FILE:-}" ]]; then
    print_and_log 'WARN' 'Both inline admin password and password file were provided; using password file.'
  elif [[ -n "${ADMIN_PASSWORD:-}" ]]; then
    print_and_log 'WARN' 'Inline admin password was provided; prefer --admin-password-file for production security.'
  fi

  admin_password="$(read_admin_password)"

  if [[ "${dry_run}" == 'true' ]]; then
    validate_admin_inputs 'false' "${admin_password}"
    print_info 'DRY-RUN: admin bootstrap enabled; would run first sysop creation command.'
    [[ -n "${ADMIN_EMAIL:-}" ]] && print_info "DRY-RUN: target admin email: ${ADMIN_EMAIL}"
    return 0
  fi

  validate_admin_inputs 'true' "${admin_password}"
  create_first_admin "${install_dir}" "${admin_password}"
}
