#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

check_os_version() {
  local os_id='' version_id=''

  # shellcheck source=/etc/os-release
  if [[ -r /etc/os-release ]]; then
    . /etc/os-release
    os_id="${ID:-}"
    version_id="${VERSION_ID:-}"
  fi

  if [[ "${os_id}" != 'ubuntu' ]] || [[ "${version_id}" != '22.04' && "${version_id}" != '24.04' ]]; then
    print_error "Unsupported OS: ${os_id} ${version_id}. Expected Ubuntu 22.04 or 24.04."
    exit 1
  fi
  print_success "OS check passed: Ubuntu ${version_id}"
}

check_privileges() { if [[ "${EUID}" -ne 0 ]] && ! sudo -n true 2>/dev/null; then print_error 'Root or passwordless sudo is required.'; exit 1; fi; print_success 'Privilege check passed.'; }

check_disk_ram() {
  local avail_disk_kb ram_mb
  avail_disk_kb="$(df -Pk / | awk 'NR==2 {print $4}')"
  ram_mb="$(free -m | awk '/^Mem:/ {print $2}')"
  (( avail_disk_kb >= 10485760 )) || { print_error 'At least 10GB free disk space is required.'; exit 1; }
  (( ram_mb >= 2048 )) || { print_error 'At least 2GB RAM is required.'; exit 1; }
  print_success 'Disk and RAM checks passed.'
}

check_docker() {
  command -v docker >/dev/null 2>&1 || { print_error 'Docker is not installed.'; exit 1; }
  docker info >/dev/null 2>&1 || { print_error 'Docker daemon is not running.'; exit 1; }
  docker compose version >/dev/null 2>&1 || { print_error 'Docker Compose plugin is required and must be working.'; exit 1; }
  print_success 'Docker daemon and Docker Compose plugin checks passed.'
}

get_public_ip() { curl -fsS https://api.ipify.org 2>/dev/null || true; }

check_domain_dns() {
  local domain="$1" public_ip dns_records
  [[ "${domain}" =~ ^[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]] || { print_error "Invalid domain format: ${domain}"; exit 1; }
  public_ip="$(get_public_ip)"
  dns_records="$(getent ahosts "${domain}" | awk '{print $1}' | sort -u || true)"
  if [[ -n "${public_ip}" && -n "${dns_records}" ]] && ! grep -qx "${public_ip}" <<<"${dns_records}"; then
    print_warn "DNS for ${domain} does not include this host public IP (${public_ip})."
  else
    print_success "Domain check passed for ${domain}."
  fi
}

check_existing_web_servers() {
  local conflicts=()
  systemctl is-active --quiet nginx && conflicts+=(nginx)
  systemctl is-active --quiet apache2 && conflicts+=(apache2)
  systemctl is-active --quiet caddy && conflicts+=(caddy)
  if (( ${#conflicts[@]} > 0 )); then
    print_warn "Potential web server conflict(s): ${conflicts[*]}"
  else
    print_success 'No active nginx/apache2/caddy services detected.'
  fi
}

check_ports() {
  local port line blocked='false'
  for port in 80 443; do
    line="$(ss -ltnp "( sport = :${port} )" 2>/dev/null | awk 'NR>1 {print $0; exit}' || true)"
    if [[ -n "${line}" ]]; then
      print_warn "Port ${port} is occupied: ${line}"
      blocked='true'
    fi
  done
  if [[ "${blocked}" == 'true' ]]; then
    print_warn 'Port checks found potential conflicts.'
  else
    print_success 'Port checks passed.'
  fi
}
