#!/usr/bin/env bash

set -Eeuo pipefail
IFS=$'\n\t'

docker_group_guidance() {
  local user_name
  user_name="${SUDO_USER:-${USER:-$(id -un 2>/dev/null || echo '')}}"

  if [[ -z "${user_name}" ]] || [[ "${user_name}" == 'root' ]]; then
    return 0
  fi

  if id -nG "${user_name}" 2>/dev/null | tr ' ' '\n' | grep -qx 'docker'; then
    return 0
  fi

  print_warn 'Current user may need docker group membership for manual Docker commands.'
  printf '  Suggested command: sudo usermod -aG docker %s\n' "${user_name}"
  printf '  Note: log out and log back in for group changes to take effect.\n'
}

print_install_summary() {
  local domain="$1" install_dir="$2" tls_enabled="$3" version="$4"
  local app_url="http://${domain}" docker_ver='unavailable' compose_ver='unavailable'
  local admin_mode='disabled/manual'

  if [[ "${tls_enabled}" == 'true' ]]; then
    app_url="https://${domain}"
  fi

  if [[ "${CREATE_ADMIN:-false}" == 'true' ]]; then
    if [[ "${DRY_RUN:-false}" == 'true' ]]; then
      admin_mode='dry-run'
    else
      admin_mode='enabled'
    fi
  fi

  if command -v docker >/dev/null 2>&1; then
    docker_ver="$(docker version --format '{{.Server.Version}}' 2>/dev/null || echo 'unavailable')"
    compose_ver="$(docker compose version --short 2>/dev/null || echo 'unavailable')"
  fi

  echo
  print_info 'Install summary:'
  printf '  Installer version: %s\n' "${version}"
  printf '  Domain: %s\n' "${domain}"
  printf '  Install path: %s\n' "${install_dir}"
  printf '  App URL: %s\n' "${app_url}"
  printf '  Docker provisioning mode: %s\n' "${INSTALL_DOCKER}"
  printf '  Docker version: %s\n' "${docker_ver}"
  printf '  Compose version: %s\n' "${compose_ver}"
  printf '  Log path: %s\n' "${LOG_FILE}"
  printf '  State path: %s\n' "${STATE_FILE}"
  printf '  Admin bootstrap: %s\n' "${admin_mode}"
  [[ -n "${ADMIN_EMAIL:-}" ]] && printf '  Admin email: %s\n' "${ADMIN_EMAIL}"
  if [[ "${admin_mode}" == 'disabled/manual' ]]; then
    printf '  Next steps: %s\n' "Review .env secrets, then run: cd '${install_dir}' && docker compose -f deploy/docker-compose.prod.yml exec app php artisan nextgn:sysop:create"
  else
    printf '  Next steps: %s\n' 'Review .env secrets, validate backups/monitoring.'
  fi

  docker_group_guidance

  if (( ${#VERIFY_WARNINGS[@]} > 0 )); then
    print_warn 'Warnings detected during DNS/TLS/health verification:'
    printf '  - %s\n' "${VERIFY_WARNINGS[@]}"
  fi
}
