#!/usr/bin/env bash

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
cd "${REPO_ROOT}"

# shellcheck source=installer/lib/output.sh
source "${SCRIPT_DIR}/lib/output.sh"
# shellcheck source=installer/lib/logging.sh
source "${SCRIPT_DIR}/lib/logging.sh"
# shellcheck source=installer/lib/strict.sh
source "${SCRIPT_DIR}/lib/strict.sh"
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
  setup_error_trap
  parse_args "$@"

  init_logging
  log_message 'INFO' 'NextGN installer started.'

  init_state "${FORCE}" "${DRY_RUN}"

  run_step 'os_check' check_os_version
  run_step 'privilege_check' check_privileges
  run_step 'resource_check' check_disk_ram
  run_step 'docker_check' check_docker
  run_step 'domain_check' check_domain_dns "${DOMAIN}"
  run_step 'service_conflicts' check_existing_web_servers
  run_step 'port_check' check_ports
  run_step 'license_check' validate_license_key "${LICENSE_KEY}"

  run_step 'prepare_dir' run_cmd "${DRY_RUN}" mkdir -p "${INSTALL_DIR}"

  if [[ ! -d "${INSTALL_DIR}/.git" ]]; then
    run_step 'clone_repo' run_cmd "${DRY_RUN}" git clone --branch "${REPO_BRANCH}" "${REPO_URL}" "${INSTALL_DIR}"
  else
    print_warn "Repository already exists at ${INSTALL_DIR}, skipping clone."
  fi

  if [[ "${DRY_RUN}" == 'false' ]]; then
    run_step 'write_templates' write_templates "${INSTALL_DIR}" "${DOMAIN}" "${FORCE}"
    run_step 'bootstrap_app' bootstrap_app "${INSTALL_DIR}" "${DOMAIN}" "${DRY_RUN}"
  else
    print_info 'DRY-RUN: templates and bootstrap would run.'
  fi

  print_success 'NextGN installer workflow completed.'
  log_message 'INFO' 'NextGN installer completed successfully.'
}

main "$@"
