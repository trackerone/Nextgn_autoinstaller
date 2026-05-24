#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

check_os_version() {
  local os_id version_id
  os_id="$(. /etc/os-release && printf '%s' "${ID}")"
  version_id="$(. /etc/os-release && printf '%s' "${VERSION_ID}")"

  if [[ "${os_id}" != 'ubuntu' ]] || [[ "${version_id}" != '22.04' && "${version_id}" != '24.04' ]]; then
    print_error "Unsupported OS: ${os_id} ${version_id}. Expected Ubuntu 22.04 or 24.04."
    exit 1
  fi
  print_success "OS check passed: Ubuntu ${version_id}"
}

check_privileges() {
  if [[ "${EUID}" -ne 0 ]] && ! sudo -n true 2>/dev/null; then
    print_error 'Root or passwordless sudo is required.'
    exit 1
  fi
  print_success 'Privilege check passed.'
}

check_disk_ram() {
  local avail_disk_kb ram_mb
  avail_disk_kb="$(df -Pk / | awk 'NR==2 {print $4}')"
  ram_mb="$(free -m | awk '/^Mem:/ {print $2}')"

  if (( avail_disk_kb < 10485760 )); then
    print_error 'At least 10GB free disk space is required.'
    exit 1
  fi
  if (( ram_mb < 2048 )); then
    print_error 'At least 2GB RAM is required.'
    exit 1
  fi
  print_success 'Disk and RAM checks passed.'
}

check_docker() {
  command -v docker >/dev/null 2>&1 || { print_error 'Docker is not installed.'; exit 1; }
  command -v docker compose >/dev/null 2>&1 || { print_error 'Docker Compose plugin is required.'; exit 1; }
  print_success 'Docker and Docker Compose checks passed.'
}

check_domain_dns() {
  local domain="$1"
  if ! [[ "${domain}" =~ ^[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
    print_error "Invalid domain format: ${domain}"
    exit 1
  fi
  print_success "Domain format check passed for ${domain}."
}

check_ports() {
  local blocked='false'
  for port in 80 443; do
    if ss -ltn | awk '{print $4}' | grep -q ":${port}$"; then
      print_warn "Port ${port} appears in use."
      blocked='true'
    fi
  done

  if [[ "${blocked}" == 'true' ]]; then
    print_warn 'Port checks found potential conflicts.'
  else
    print_success 'Port checks passed.'
  fi
}
