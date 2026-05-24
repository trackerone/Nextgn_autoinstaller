#!/usr/bin/env bash

set -Eeuo pipefail
IFS=$'\n\t'

STATE_DIR='/var/lib/nextgn-installer'
STATE_FILE='/var/lib/nextgn-installer/state'

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

init_state() {
  local force="$1" dry_run="$2"
  if [[ "${dry_run}" == 'true' ]]; then
    return 0
  fi

  mkdir -p "${STATE_DIR}"
  if [[ -f "${STATE_FILE}" && "${force}" != 'true' ]]; then
    print_info 'Existing install state found; resume mode enabled.'
    return 0
  fi

  if [[ "${force}" == 'true' ]]; then
    : >"${STATE_FILE}"
    print_warn 'Force mode enabled: existing state file cleared.'
  else
    touch "${STATE_FILE}"
  fi
}

is_step_done() {
  local step="$1"
  [[ -f "${STATE_FILE}" ]] && grep -qx "${step}" "${STATE_FILE}"
}

mark_step_done() {
  local step="$1"
  is_step_done "${step}" || echo "${step}" >>"${STATE_FILE}"
}

run_step() {
  : "${DRY_RUN:=false}"

  local step="$1"
  shift
  if [[ "${DRY_RUN}" == 'false' ]] && is_step_done "${step}"; then
    print_info "Skipping completed step: ${step}"
    return 0
  fi

  "$@"
  [[ "${DRY_RUN}" == 'false' ]] && mark_step_done "${step}"
}

bootstrap_app() {
  local install_dir="$1" domain="$2" dry_run="$3"
  local env_file="${install_dir}/.env"
  local env_template="${install_dir}/.env.example"

  if [[ ! -f "${env_file}" && -f "${env_template}" ]]; then
    run_cmd "${dry_run}" cp "${env_template}" "${env_file}"
  fi

  if [[ -f "${env_file}" ]]; then
    run_cmd "${dry_run}" sed -i "s|APP_URL=.*|APP_URL=https://${domain}|" "${env_file}"
  fi

  run_cmd "${dry_run}" bash -lc "cd '${install_dir}' && docker compose -f deploy/docker-compose.prod.yml pull"
  run_cmd "${dry_run}" bash -lc "cd '${install_dir}' && docker compose -f deploy/docker-compose.prod.yml build"
  run_cmd "${dry_run}" bash -lc "cd '${install_dir}' && docker compose -f deploy/docker-compose.prod.yml run --rm app php artisan key:generate --force"
  run_cmd "${dry_run}" bash -lc "cd '${install_dir}' && docker compose -f deploy/docker-compose.prod.yml run --rm app php artisan migrate --force"
  run_cmd "${dry_run}" bash -lc "cd '${install_dir}' && docker compose -f deploy/docker-compose.prod.yml run --rm app php artisan config:cache"
  run_cmd "${dry_run}" bash -lc "cd '${install_dir}' && docker compose -f deploy/docker-compose.prod.yml run --rm app php artisan cache:clear"
  run_cmd "${dry_run}" bash -lc "cd '${install_dir}' && docker compose -f deploy/docker-compose.prod.yml run --rm app php artisan view:cache"
  run_cmd "${dry_run}" bash -lc "cd '${install_dir}' && docker compose -f deploy/docker-compose.prod.yml run --rm app php artisan route:cache"
  run_cmd "${dry_run}" bash -lc "cd '${install_dir}' && docker compose -f deploy/docker-compose.prod.yml run --rm app php artisan storage:link"
  run_cmd "${dry_run}" chmod -R ug+rwX "${install_dir}/storage" "${install_dir}/bootstrap/cache"
}
