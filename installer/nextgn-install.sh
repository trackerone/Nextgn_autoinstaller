#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
cd "${REPO_ROOT}"

# shellcheck source=installer/lib/output.sh
source "${SCRIPT_DIR}/lib/output.sh"
# shellcheck source=installer/lib/logging.sh
source "${SCRIPT_DIR}/lib/logging.sh"
# shellcheck source=installer/lib/runner.sh
source "${SCRIPT_DIR}/lib/runner.sh"
# shellcheck source=installer/lib/config.sh
source "${SCRIPT_DIR}/lib/config.sh"
# shellcheck source=installer/lib/checks.sh
source "${SCRIPT_DIR}/lib/checks.sh"
# shellcheck source=installer/lib/license.sh
source "${SCRIPT_DIR}/lib/license.sh"
# shellcheck source=installer/lib/templates.sh
source "${SCRIPT_DIR}/lib/templates.sh"

main() {
  parse_args "$@"

  init_logging
  log_message 'INFO' 'NextGN installer started.'

  check_os_version
  check_privileges
  check_disk_ram
  check_docker
  check_domain_dns "${DOMAIN}"
  check_ports
  validate_license_key "${LICENSE_KEY}"

  run_cmd "${DRY_RUN}" mkdir -p "${APP_DIR}"

  if [[ ! -d "${APP_DIR}/.git" ]]; then
    run_cmd "${DRY_RUN}" git clone --branch "${REPO_BRANCH}" "${REPO_URL}" "${APP_DIR}"
  else
    print_warn "Repository already exists at ${APP_DIR}, skipping clone."
  fi

  if [[ "${DRY_RUN}" == 'false' ]]; then
    write_templates "${APP_DIR}" "${DOMAIN}" "${FORCE}"
  else
    print_info 'DRY-RUN: templates would be written.'
  fi

  print_info 'Non-destructive app bootstrap commands (example sequence):'
  print_info "- cd ${APP_DIR}"
  print_info '- cp .env.example .env (if missing)'
  print_info '- docker compose -f deploy/docker-compose.prod.yml run --rm app php artisan migrate --force'
  print_info '- docker compose -f deploy/docker-compose.prod.yml run --rm app php artisan config:cache'
  print_info '- docker compose -f deploy/docker-compose.prod.yml run --rm app php artisan route:cache'
  print_info '- set filesystem permissions for storage/bootstrap/cache'

  print_success 'NextGN installer workflow completed.'
  log_message 'INFO' 'NextGN installer completed successfully.'
}

main "$@"
