#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

DOMAIN="${NEXTGN_DOMAIN:-}"
INSTALL_DIR="${NEXTGN_INSTALL_DIR:-}"
ENABLE_TLS="${NEXTGN_ENABLE_TLS:-false}"
OUTPUT_DIR="${NEXTGN_VALIDATION_OUTPUT_DIR:-${PWD}}"
JSON_ONLY='false'
GENERATE_SUPPORT_BUNDLE='false'

CHECK_NAMES=()
CHECK_STATUS=()
CHECK_MESSAGE=()
FAILED_CHECKS=0
WARN_CHECKS=0
SUPPORT_BUNDLE_PATH=''

usage() {
  cat <<'USAGE'
Usage: validate-vps-install.sh --domain <fqdn> --install-dir <path> [options]

Options:
  --domain <fqdn>       Domain configured for the installation.
  --install-dir <path>  Installation directory (for example /opt/nextgn-tracker).
  --tls                 Enable TLS-specific checks (or set NEXTGN_ENABLE_TLS=true).
  --output-dir <path>   Directory for validation-report.json/txt.
  --json-only           Only generate JSON report.
  --support-bundle      Run scripts/support-bundle.sh when final status is fail.
  --help                Show this help.

Environment overrides:
  NEXTGN_DOMAIN
  NEXTGN_INSTALL_DIR
  NEXTGN_ENABLE_TLS
  NEXTGN_VALIDATION_OUTPUT_DIR
USAGE
}

bool_is_true() {
  case "${1:-false}" in
    1|true|TRUE|yes|YES|on|ON) return 0 ;;
    *) return 1 ;;
  esac
}

json_escape() {
  local s="${1:-}"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/}"
  printf '%s' "${s}"
}

add_check() {
  local name="$1" status="$2" message="$3"
  CHECK_NAMES+=("${name}")
  CHECK_STATUS+=("${status}")
  CHECK_MESSAGE+=("${message}")
  [[ "${status}" == 'fail' ]] && FAILED_CHECKS=$((FAILED_CHECKS + 1))
  [[ "${status}" == 'warn' ]] && WARN_CHECKS=$((WARN_CHECKS + 1))
}

run_check() {
  local name="$1"
  shift
  local status='fail' message='Unknown failure'
  if output="$("$@" 2>&1)"; then
    status='pass'
    message="${output:-OK}"
  else
    status='fail'
    message="${output:-Command failed}"
  fi
  add_check "${name}" "${status}" "${message}"
}

warn_check() {
  add_check "$1" 'warn' "$2"
}

check_os_version() {
  if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    source /etc/os-release
    printf '%s %s' "${NAME:-unknown}" "${VERSION_ID:-unknown}"
    return 0
  fi
  return 1
}

check_hostname() { hostnamectl --static 2>/dev/null || hostname; }
check_public_ip() { curl -fsS --max-time 5 https://api.ipify.org; }

check_dns_resolution() {
  local resolved
  resolved="$(getent ahosts "${DOMAIN}" | awk 'NR==1 {print $1}')"
  [[ -n "${resolved}" ]] || return 1
  printf 'Resolved %s -> %s' "${DOMAIN}" "${resolved}"
}

check_docker_version() { docker --version; }
check_docker_compose_version() { docker compose version; }
check_docker_service_status() { systemctl is-active docker; }
check_env_exists() { [[ -f "${INSTALL_DIR}/.env" ]] && echo '.env exists'; }
check_compose_exists() { [[ -f "${INSTALL_DIR}/deploy/docker-compose.prod.yml" ]] && echo 'docker-compose.prod.yml exists'; }
check_nginx_exists() { [[ -f "${INSTALL_DIR}/deploy/nginx.conf" ]] && echo 'nginx.conf exists'; }
check_compose_config() { docker compose -f "${INSTALL_DIR}/deploy/docker-compose.prod.yml" config >/dev/null && echo 'compose config OK'; }
check_containers_exist() { docker compose -f "${INSTALL_DIR}/deploy/docker-compose.prod.yml" ps -a | awk 'NR>1{found=1} END{exit(found?0:1)}' && echo 'containers found'; }

container_is_running() {
  local service="$1"
  docker compose -f "${INSTALL_DIR}/deploy/docker-compose.prod.yml" ps --status running "${service}" | awk 'NR>1 {found=1} END{exit(found?0:1)}'
}

container_health_ok() {
  local service="$1" cid
  cid="$(docker compose -f "${INSTALL_DIR}/deploy/docker-compose.prod.yml" ps -q "${service}")"
  [[ -n "${cid}" ]] || return 1
  health="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "${cid}" 2>/dev/null || true)"
  [[ "${health}" == 'healthy' ]]
}

check_http_local() { curl -fsS -o /dev/null -m 5 http://127.0.0.1 && echo 'HTTP local reachable'; }
check_https_local() { curl -kfsS -o /dev/null -m 5 https://127.0.0.1 && echo 'HTTPS local reachable'; }
check_artisan_about() { docker compose -f "${INSTALL_DIR}/deploy/docker-compose.prod.yml" exec -T app php artisan about >/dev/null && echo 'artisan about OK'; }

check_admin_bootstrap() {
  if grep -Eq '^NEXTGN_ADMIN_BOOTSTRAPPED=true$' "${INSTALL_DIR}/.env" 2>/dev/null; then
    echo 'Admin bootstrap completed'
  else
    return 1
  fi
}

run_support_bundle() {
  local out
  out="$(bash "${ROOT_DIR}/scripts/support-bundle.sh" "${OUTPUT_DIR}" 2>&1)" || return 1
  SUPPORT_BUNDLE_PATH="$(awk -F': ' '/Support bundle created/{print $2}' <<<"${out}")"
  printf '%s' "${out}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --domain) DOMAIN="${2:-}"; shift 2 ;;
    --install-dir) INSTALL_DIR="${2:-}"; shift 2 ;;
    --tls) ENABLE_TLS='true'; shift ;;
    --output-dir) OUTPUT_DIR="${2:-}"; shift 2 ;;
    --json-only) JSON_ONLY='true'; shift ;;
    --support-bundle) GENERATE_SUPPORT_BUNDLE='true'; shift ;;
    --help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ -z "${DOMAIN}" || -z "${INSTALL_DIR}" ]]; then
  echo 'Error: --domain and --install-dir are required.' >&2
  usage
  exit 1
fi

mkdir -p "${OUTPUT_DIR}"
JSON_REPORT="${OUTPUT_DIR}/validation-report.json"
TEXT_REPORT="${OUTPUT_DIR}/validation-report.txt"

run_check 'OS version' check_os_version
run_check 'Hostname' check_hostname
run_check 'Public IP' check_public_ip
run_check 'DNS resolution for configured domain' check_dns_resolution
run_check 'Docker version' check_docker_version
run_check 'Docker Compose version' check_docker_compose_version
run_check 'docker service status' check_docker_service_status
run_check 'generated .env exists' check_env_exists
run_check 'docker-compose.prod.yml exists' check_compose_exists
run_check 'nginx.conf exists' check_nginx_exists
run_check 'docker compose config passes' check_compose_config
run_check 'containers exist' check_containers_exist

if container_is_running app >/dev/null 2>&1; then add_check 'app container running/healthy' pass 'app running';
elif container_health_ok app; then add_check 'app container running/healthy' pass 'app healthy';
else add_check 'app container running/healthy' fail 'app is not running/healthy'; fi

if container_is_running queue >/dev/null 2>&1; then
  add_check 'queue container running' pass 'queue running'
else
  add_check 'queue container running' fail 'queue not running'
fi
if container_is_running scheduler >/dev/null 2>&1; then
  add_check 'scheduler container running' pass 'scheduler running'
else
  add_check 'scheduler container running' fail 'scheduler not running'
fi
if container_health_ok db; then
  add_check 'database container healthy' pass 'db healthy'
else
  add_check 'database container healthy' warn 'db healthcheck missing or unhealthy'
fi
if container_health_ok redis; then
  add_check 'redis container healthy' pass 'redis healthy'
else
  add_check 'redis container healthy' warn 'redis healthcheck missing or unhealthy'
fi

run_check 'HTTP responds locally' check_http_local
if bool_is_true "${ENABLE_TLS}"; then
  run_check 'HTTPS responds if TLS enabled' check_https_local
else
  warn_check 'HTTPS responds if TLS enabled' 'TLS disabled, HTTPS check skipped'
fi

run_check 'Laravel artisan about works' check_artisan_about
if grep -Eq '^NEXTGN_CREATE_ADMIN=true$' "${INSTALL_DIR}/.env" 2>/dev/null; then
  run_check 'first admin bootstrap status if configured' check_admin_bootstrap
else
  warn_check 'first admin bootstrap status if configured' 'Admin bootstrap not configured'
fi

if run_support_bundle >/dev/null 2>&1; then
  add_check 'support bundle can be generated' pass "support bundle created: ${SUPPORT_BUNDLE_PATH}"
else
  add_check 'support bundle can be generated' fail 'support bundle generation failed'
fi

FINAL_STATUS='pass'
if (( FAILED_CHECKS > 0 )); then FINAL_STATUS='fail';
elif (( WARN_CHECKS > 0 )); then FINAL_STATUS='warn'; fi

{
  printf '{\n'
  printf '  "timestamp": "%s",\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
  printf '  "installer_version": "%s",\n' "$(cat "${ROOT_DIR}/VERSION" 2>/dev/null || echo unknown)"
  printf '  "domain": "%s",\n' "$(json_escape "${DOMAIN}")"
  printf '  "install_dir": "%s",\n' "$(json_escape "${INSTALL_DIR}")"
  printf '  "checks": [\n'
  for i in "${!CHECK_NAMES[@]}"; do
    printf '    {"name":"%s","status":"%s","message":"%s"}' \
      "$(json_escape "${CHECK_NAMES[$i]}")" "${CHECK_STATUS[$i]}" "$(json_escape "${CHECK_MESSAGE[$i]}")"
    [[ "$i" -lt $((${#CHECK_NAMES[@]} - 1)) ]] && printf ','
    printf '\n'
  done
  printf '  ],\n'
  printf '  "final_status": "%s"\n' "${FINAL_STATUS}"
  printf '}\n'
} >"${JSON_REPORT}"

if [[ "${JSON_ONLY}" != 'true' ]]; then
  {
    printf 'NextGN VPS Validation Report\n'
    printf 'Timestamp: %s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
    printf 'Domain: %s\nInstall dir: %s\n\n' "${DOMAIN}" "${INSTALL_DIR}"
    for i in "${!CHECK_NAMES[@]}"; do
      printf '%s: %s - %s\n' "${CHECK_STATUS[$i]^^}" "${CHECK_NAMES[$i]}" "${CHECK_MESSAGE[$i]}"
    done
    printf '\nFinal status: %s\n' "${FINAL_STATUS^^}"
    printf 'Next action: '
    if [[ "${FINAL_STATUS}" == 'fail' ]]; then
      printf 'review failing checks and run scripts/support-bundle.sh %s\n' "${OUTPUT_DIR}"
    elif [[ "${FINAL_STATUS}" == 'warn' ]]; then
      printf 'review warnings and validate expected environment differences\n'
    else
      printf 'installation validation passed\n'
    fi
    printf 'Log path: %s\n' "${LOG_FILE:-/var/log/nextgn-installer.log}"
    printf 'Support bundle path: %s\n' "${SUPPORT_BUNDLE_PATH:-not-generated}"
  } >"${TEXT_REPORT}"
fi

if [[ "${FINAL_STATUS}" == 'fail' ]] && [[ "${GENERATE_SUPPORT_BUNDLE}" == 'true' ]]; then
  run_support_bundle >/dev/null 2>&1 || true
fi

[[ "${FINAL_STATUS}" == 'fail' ]] && exit 1 || exit 0
