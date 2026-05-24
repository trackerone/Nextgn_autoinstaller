#!/usr/bin/env bash

set -Eeuo pipefail
IFS=$'\n\t'

STATE_DIR='/var/lib/nextgn-installer'
STATE_FILE='/var/lib/nextgn-installer/state'
LOCK_FILE='/var/lock/nextgn-installer.lock'
LOCK_FD=201
CURRENT_PHASE='startup'
: "${LOG_FILE:=/var/log/nextgn-installer.log}"

run_cmd() {
  local dry_run="$1"
  shift
  if [[ "${dry_run}" == 'true' ]]; then
    print_and_log 'INFO' "DRY-RUN: $*"
    return 0
  fi
  print_and_log 'INFO' "RUN: $*"
  "$@"
}

acquire_install_lock() {
  local dry_run="$1"
  if [[ "${dry_run}" == 'true' ]]; then
    print_and_log 'INFO' 'DRY-RUN: lock acquisition skipped.'
    return 0
  fi

  mkdir -p "$(dirname -- "${LOCK_FILE}")"
  eval "exec ${LOCK_FD}>\"${LOCK_FILE}\""

  if ! flock -n "${LOCK_FD}"; then
    if [[ -s "${LOCK_FILE}" ]]; then
      print_and_log 'WARN' "Installer lock is held. Lock metadata: $(cat "${LOCK_FILE}" 2>/dev/null || true)"
    fi
    print_and_log 'ERROR' 'Another installer run appears active. If stale, verify PID and remove lock file manually.'
    exit 1
  fi

  printf 'pid=%s started=%s host=%s\n' "$$" "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" "$(hostname)" > "${LOCK_FILE}"
  print_and_log 'SUCCESS' "Acquired deployment lock: ${LOCK_FILE}"
}

release_install_lock() {
  if [[ "${DRY_RUN:-false}" == 'true' ]]; then
    return 0
  fi
  flock -u "${LOCK_FD}" || true
  rm -f "${LOCK_FILE}" || true
}

init_state() {
  local force="$1" dry_run="$2"
  if [[ "${dry_run}" == 'true' ]]; then
    return 0
  fi

  mkdir -p "${STATE_DIR}"
  if [[ -f "${STATE_FILE}" && "${force}" != 'true' ]]; then
    print_and_log 'INFO' 'Existing install state found; resume mode enabled.'
    return 0
  fi

  if [[ "${force}" == 'true' ]]; then
    : >"${STATE_FILE}"
    print_and_log 'WARN' 'Force mode enabled: existing state file cleared.'
  else
    touch "${STATE_FILE}"
  fi
}

record_phase() {
  local phase="$1"
  CURRENT_PHASE="${phase}"
  if [[ "${DRY_RUN:-false}" == 'false' ]]; then
    echo "phase:${phase}:$(date -u +'%Y-%m-%dT%H:%M:%SZ')" >>"${STATE_FILE}"
  fi
  print_and_log 'INFO' "Checkpoint phase: ${phase}"
}

print_recovery_guidance() {
  print_and_log 'WARN' "Failure detected during phase '${CURRENT_PHASE}'."
  print_and_log 'WARN' "State file preserved at ${STATE_FILE}; logs at ${LOG_FILE}."
  print_and_log 'WARN' 'Rollback guidance: inspect compose status, restore backups, then rerun with --force once corrected.'
}

is_step_done() { local step="$1"; [[ -f "${STATE_FILE}" ]] && grep -qx "${step}" "${STATE_FILE}"; }
mark_step_done() { local step="$1"; is_step_done "${step}" || echo "${step}" >>"${STATE_FILE}"; }

run_step() {
  : "${DRY_RUN:=false}"
  local step="$1"; shift
  if [[ "${DRY_RUN}" == 'false' ]] && is_step_done "${step}"; then
    print_and_log 'INFO' "Skipping completed step: ${step}"
    return 0
  fi
  "$@"
  if [[ "${DRY_RUN}" == 'false' ]]; then
    mark_step_done "${step}"
  fi
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
  run_cmd "${dry_run}" bash -lc "cd '${install_dir}' && docker compose -f deploy/docker-compose.prod.yml up -d"
  run_cmd "${dry_run}" bash -lc "cd '${install_dir}' && docker compose -f deploy/docker-compose.prod.yml run --rm app php artisan key:generate --force"
  run_cmd "${dry_run}" bash -lc "cd '${install_dir}' && docker compose -f deploy/docker-compose.prod.yml run --rm app php artisan migrate --force"
  run_cmd "${dry_run}" bash -lc "cd '${install_dir}' && docker compose -f deploy/docker-compose.prod.yml run --rm app php artisan config:cache"
  run_cmd "${dry_run}" bash -lc "cd '${install_dir}' && docker compose -f deploy/docker-compose.prod.yml run --rm app php artisan cache:clear"
  run_cmd "${dry_run}" bash -lc "cd '${install_dir}' && docker compose -f deploy/docker-compose.prod.yml run --rm app php artisan view:cache"
  run_cmd "${dry_run}" bash -lc "cd '${install_dir}' && docker compose -f deploy/docker-compose.prod.yml run --rm app php artisan route:cache"
  run_cmd "${dry_run}" bash -lc "cd '${install_dir}' && docker compose -f deploy/docker-compose.prod.yml run --rm app php artisan storage:link"
  run_cmd "${dry_run}" chmod -R ug+rwX "${install_dir}/storage" "${install_dir}/bootstrap/cache"
}
