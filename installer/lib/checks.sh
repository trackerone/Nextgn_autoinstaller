#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

MIN_DOCKER_VERSION="${NEXTGN_MIN_DOCKER_VERSION:-24.0.0}"
MIN_COMPOSE_VERSION="${NEXTGN_MIN_COMPOSE_VERSION:-2.20.0}"
MIN_DISK_KB="${NEXTGN_MIN_DISK_KB:-10485760}"
MIN_RAM_MB="${NEXTGN_MIN_RAM_MB:-2048}"
MIN_SWAP_MB="${NEXTGN_MIN_SWAP_MB:-512}"

check_os_version() {
  local os_id='' version_id=''

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

version_ge() { [ "$(printf '%s\n' "$2" "$1" | sort -V | head -n1)" = "$2" ]; }
check_privileges() { if [[ "${EUID}" -ne 0 ]] && ! sudo -n true 2>/dev/null; then print_error 'Root or passwordless sudo is required.'; exit 1; fi; print_success 'Privilege check passed.'; }

check_disk_ram() {
  local avail_disk_kb ram_mb swap_mb
  avail_disk_kb="$(df -Pk / | awk 'NR==2 {print $4}')"
  ram_mb="$(free -m | awk '/^Mem:/ {print $2}')"
  swap_mb="$(free -m | awk '/^Swap:/ {print $2}')"

  (( avail_disk_kb >= MIN_DISK_KB )) || { print_error "At least $((MIN_DISK_KB/1024/1024))GB free disk space is required."; exit 1; }
  (( ram_mb >= MIN_RAM_MB )) || { print_error "At least ${MIN_RAM_MB}MB RAM is required."; exit 1; }

  if (( swap_mb < MIN_SWAP_MB )); then
    print_warn "Swap is low or missing (${swap_mb}MB). Recommended minimum: ${MIN_SWAP_MB}MB."
    print_warn 'Action: configure swap to reduce OOM risk during builds and migrations.'
  fi
  print_success 'Disk and RAM checks passed.'
}

check_docker() {
  local docker_ver compose_ver
  command -v docker >/dev/null 2>&1 || { print_error 'Docker is not installed.'; exit 1; }
  docker info >/dev/null 2>&1 || { print_error 'Docker daemon is not running.'; exit 1; }
  docker compose version >/dev/null 2>&1 || { print_error 'Docker Compose plugin is required and must be working.'; exit 1; }

  docker_ver="$(docker version --format '{{.Server.Version}}' 2>/dev/null || true)"
  compose_ver="$(docker compose version --short 2>/dev/null || true)"

  if [[ -n "${docker_ver}" ]] && ! version_ge "${docker_ver}" "${MIN_DOCKER_VERSION}"; then
    print_warn "Unsupported Docker version ${docker_ver}; recommended >= ${MIN_DOCKER_VERSION}."
  fi
  if [[ -n "${compose_ver}" ]] && ! version_ge "${compose_ver}" "${MIN_COMPOSE_VERSION}"; then
    print_warn "Unsupported Compose version ${compose_ver}; recommended >= ${MIN_COMPOSE_VERSION}."
  fi

  print_success 'Docker daemon and Docker Compose plugin checks passed.'
}

get_public_ip() { curl -fsS https://api.ipify.org 2>/dev/null || true; }
check_domain_dns() { local domain="$1" public_ip dns_records; [[ "${domain}" =~ ^[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]] || { print_error "Invalid domain format: ${domain}"; exit 1; }; public_ip="$(get_public_ip)"; dns_records="$(getent ahosts "${domain}" | awk '{print $1}' | sort -u || true)"; if [[ -n "${public_ip}" && -n "${dns_records}" ]] && ! grep -qx "${public_ip}" <<<"${dns_records}"; then print_warn "DNS for ${domain} does not include this host public IP (${public_ip})."; else print_success "Domain check passed for ${domain}."; fi; }

check_existing_web_servers() { local conflicts=(); systemctl is-active --quiet nginx && conflicts+=(nginx); systemctl is-active --quiet apache2 && conflicts+=(apache2); systemctl is-active --quiet caddy && conflicts+=(caddy); if (( ${#conflicts[@]} > 0 )); then print_warn "Potential web server conflict(s): ${conflicts[*]}"; else print_success 'No active nginx/apache2/caddy services detected.'; fi; }

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
    print_warn 'Port checks found potential conflicts. Stop conflicting services before production cutover.'
  else
    print_success 'Port checks passed.'
  fi
}
