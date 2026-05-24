#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

LOG_FILE="${LOG_FILE:-/var/log/nextgn-installer.log}"
LOG_FILE_ENABLED=1
LOG_FILE_WARNING_EMITTED=0

warn_log_file_unavailable() {
  if [[ "${LOG_FILE_WARNING_EMITTED}" -eq 0 ]]; then
    printf 'Warning: unable to write installer log file at %s; continuing without file logging.\n' "${LOG_FILE}" >&2
    LOG_FILE_WARNING_EMITTED=1
  fi
}

init_logging() {
  local log_dir

  LOG_FILE_ENABLED=1
  log_dir="$(dirname -- "${LOG_FILE}")"

  if [[ ! -d "${log_dir}" ]]; then
    if ! mkdir -p -- "${log_dir}" 2>/dev/null; then
      LOG_FILE_ENABLED=0
      warn_log_file_unavailable
      return 0
    fi
  fi

  if [[ ! -e "${LOG_FILE}" ]] && ! touch -- "${LOG_FILE}" 2>/dev/null; then
    LOG_FILE_ENABLED=0
    warn_log_file_unavailable
    return 0
  fi

  if [[ ! -w "${LOG_FILE}" ]]; then
    LOG_FILE_ENABLED=0
    warn_log_file_unavailable
    return 0
  fi

  chmod 0640 "${LOG_FILE}" || true
}

log_message() {
  local level="$1"
  shift
  local message="$*"
  local timestamp

  timestamp="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"

  if [[ "${LOG_FILE_ENABLED}" -eq 1 ]]; then
    if ! printf '%s [%s] %s\n' "${timestamp}" "${level}" "${message}" >> "${LOG_FILE}" 2>/dev/null; then
      LOG_FILE_ENABLED=0
      warn_log_file_unavailable
    fi
  fi
}
