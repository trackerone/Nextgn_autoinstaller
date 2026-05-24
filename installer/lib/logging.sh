#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

LOG_FILE='/var/log/nextgn-installer.log'

init_logging() {
  if [[ ! -e "${LOG_FILE}" ]]; then
    touch "${LOG_FILE}"
  fi

  chmod 0640 "${LOG_FILE}" || true
}

log_message() {
  local level="$1"
  shift
  local message="$*"
  local timestamp

  timestamp="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
  printf '%s [%s] %s\n' "${timestamp}" "${level}" "${message}" >> "${LOG_FILE}"
}
