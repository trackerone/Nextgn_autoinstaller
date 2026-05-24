#!/usr/bin/env bash

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
cd "${REPO_ROOT}" || exit 1

# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/output.sh"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/logging.sh"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/strict.sh"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/runner.sh"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/config.sh"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/checks.sh"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/license.sh"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/templates.sh"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/tls.sh"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/verify.sh"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/admin.sh"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/summary.sh"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/version.sh"

main() {
  setup_error_trap
  trap 'print_recovery_guidance; release_install_lock' EXIT
  parse_args "$@"

  local installer_version
  installer_version="$(get_installer_version "${REPO_ROOT}/VERSION")"
  [[ "${SHOW_VERSION}" == 'true' ]] && { printf 'NextGN Installer v%s\n' "${installer_version}"; exit 0; }

  print_startup_banner "${installer_version}" "${DRY_RUN}"
  init_logging
  print_and_log 'INFO' 'NextGN installer started.'
  acquire_install_lock "${DRY_RUN}"
  init_state "${FORCE}" "${DRY_RUN}"

  record_phase 'preflight'
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
    print_and_log 'WARN' "Repository already exists at ${INSTALL_DIR}, skipping clone."
  fi

  if [[ "${DRY_RUN}" == 'false' ]]; then
    record_phase 'templates'; run_step 'write_templates' write_templates "${INSTALL_DIR}" "${DOMAIN}" "${FORCE}"
    record_phase 'containers'; run_step 'bootstrap_app' bootstrap_app "${INSTALL_DIR}" "${DOMAIN}" "${DRY_RUN}"
    if [[ "${ENABLE_TLS}" == 'true' ]]; then run_step 'tls_setup' setup_tls "${INSTALL_DIR}" "${DOMAIN}" "${DRY_RUN}" "${FORCE}"; fi
    record_phase 'migrations'
    record_phase 'verification'; run_step 'verify_installation' verify_installation "${INSTALL_DIR}" "${DOMAIN}" "${ENABLE_TLS}" "${DRY_RUN}"
    run_step 'admin_bootstrap_placeholder' bootstrap_admin_placeholder "${INSTALL_DIR}" "${DRY_RUN}"
  else
    print_and_log 'INFO' 'DRY-RUN: templates and bootstrap would run.'
  fi

  print_install_summary "${DOMAIN}" "${INSTALL_DIR}" "${ENABLE_TLS}" "${installer_version}"
  print_and_log 'SUCCESS' 'NextGN installer workflow completed.'
  release_install_lock
}

main "$@"
