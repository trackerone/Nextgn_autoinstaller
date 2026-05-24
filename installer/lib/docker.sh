#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

should_install_docker() {
  [[ "${INSTALL_DOCKER:-false}" == 'true' ]]
}

docker_is_installed() {
  if [[ "${NEXTGN_TEST_DOCKER_MISSING:-false}" == 'true' ]] && ! should_install_docker; then
    return 1
  fi
  command -v docker >/dev/null 2>&1
}

docker_daemon_running() {
  docker info >/dev/null 2>&1
}

docker_compose_available() {
  docker compose version >/dev/null 2>&1
}

ensure_supported_ubuntu_for_docker() {
  local os_id='' version_id=''
  if [[ -r /etc/os-release ]]; then
    # shellcheck source=/dev/null
    . /etc/os-release
    os_id="${ID:-}"
    version_id="${VERSION_ID:-}"
  fi

  if [[ "${os_id}" != 'ubuntu' ]] || [[ "${version_id}" != '22.04' && "${version_id}" != '24.04' ]]; then
    print_error "Docker provisioning supports only Ubuntu 22.04/24.04. Detected: ${os_id} ${version_id}."
    return 1
  fi
}

install_docker_packages() {
  ensure_supported_ubuntu_for_docker || return 1
  print_info 'Docker provisioning enabled. Installing/repairing Docker packages from official Docker repository.'

  run_cmd "${DRY_RUN}" apt-get update
  run_cmd "${DRY_RUN}" apt-get install -y ca-certificates curl gnupg lsb-release
  run_cmd "${DRY_RUN}" install -m 0755 -d /etc/apt/keyrings
  run_cmd "${DRY_RUN}" bash -lc 'curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg'
  run_cmd "${DRY_RUN}" chmod a+r /etc/apt/keyrings/docker.gpg
  docker_arch="$(dpkg --print-architecture)"
  # shellcheck source=/dev/null
  ubuntu_codename="$(. /etc/os-release && printf '%s' "${VERSION_CODENAME}")"
  run_cmd "${DRY_RUN}" bash -lc "echo 'deb [arch=${docker_arch} signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${ubuntu_codename} stable' > /etc/apt/sources.list.d/docker.list"
  run_cmd "${DRY_RUN}" apt-get update
  run_cmd "${DRY_RUN}" apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
}

ensure_docker_service() {
  run_cmd "${DRY_RUN}" systemctl enable docker
  run_cmd "${DRY_RUN}" systemctl start docker
}

provision_docker_if_requested() {
  if ! should_install_docker; then
    return 1
  fi

  if docker_is_installed && docker_daemon_running && docker_compose_available; then
    print_success 'Docker is already installed and healthy. Provisioning skipped.'
    return 0
  fi

  if ! docker_is_installed; then
    print_warn 'Docker is not installed. Provisioning Docker because --install-docker/NEXTGN_INSTALL_DOCKER=true was provided.'
    install_docker_packages
  elif ! docker_compose_available; then
    print_warn 'Docker Compose plugin is missing/unhealthy. Attempting repair via docker-compose-plugin package.'
    run_cmd "${DRY_RUN}" apt-get update
    run_cmd "${DRY_RUN}" apt-get install -y docker-compose-plugin
  fi

  if docker_is_installed && ! docker_daemon_running; then
    print_warn 'Docker daemon is not running. Attempting to enable/start service.'
    ensure_docker_service
  fi

  if [[ "${DRY_RUN}" == 'true' ]]; then
    run_cmd "${DRY_RUN}" docker info
    run_cmd "${DRY_RUN}" docker compose version
    print_success 'DRY-RUN: Docker provisioning steps planned.'
    return 0
  fi

  docker info >/dev/null 2>&1 || { print_error 'Docker provisioning failed: docker info is still failing.'; return 1; }
  docker compose version >/dev/null 2>&1 || { print_error 'Docker provisioning failed: docker compose version is still failing.'; return 1; }
  print_success 'Docker provisioning completed and verified.'
}
