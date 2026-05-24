#!/usr/bin/env bash

set -Eeuo pipefail
IFS=$'\n\t'

get_installer_version() {
  local version_file="$1"

  if [[ ! -f "${version_file}" ]]; then
    print_error "VERSION file not found: ${version_file}"
    exit 1
  fi

  local version
  version="$(<"${version_file}")"
  version="${version//$'\r'/}"
  version="${version//$'\n'/}"

  if [[ -z "${version}" ]]; then
    print_error 'VERSION file is empty.'
    exit 1
  fi

  printf '%s\n' "${version}"
}

print_startup_banner() {
  local version="$1" dry_run="$2"
  local dry_run_status='disabled'

  if [[ "${dry_run}" == 'true' ]]; then
    dry_run_status='enabled'
  fi

  echo
  printf 'NextGN Installer\n'
  printf 'Version: %s\n' "${version}"
  printf 'Dry-run: %s\n' "${dry_run_status}"
  echo
}
