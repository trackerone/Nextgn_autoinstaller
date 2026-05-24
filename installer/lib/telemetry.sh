#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

NEXTGN_TELEMETRY_ENABLED="${NEXTGN_TELEMETRY_ENABLED:-false}"

telemetry_emit() {
  local event_name="$1"
  shift || true

  if [[ "${NEXTGN_TELEMETRY_ENABLED}" != 'true' ]]; then
    return 0
  fi

  # TODO: Telemetry transport intentionally unimplemented. Keep local/no-op until explicit approval.
  log_message 'INFO' "Telemetry event queued (disabled transport): ${event_name} $*"
}
