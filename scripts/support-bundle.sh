#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

OUT_DIR="${1:-/tmp}"
TS="$(date -u +'%Y%m%dT%H%M%SZ')"
WORK_DIR="$(mktemp -d)"
BUNDLE="${OUT_DIR}/nextgn-support-${TS}.tar.gz"
STATE_FILE="${STATE_FILE:-/var/lib/nextgn-installer/state}"
LOG_FILE="${LOG_FILE:-/var/log/nextgn-installer.log}"
RELEASE_VERSION="$(cat VERSION 2>/dev/null || echo unknown)"

cleanup(){ rm -rf "${WORK_DIR}"; }
trap cleanup EXIT

redact_env() {
  local env_file="$1"
  sed -E 's/(PASSWORD|SECRET|KEY|TOKEN|LICENSE)[^=]*=.*/\1=***REDACTED***/I' "${env_file}"
}

{ docker compose ps || true; } >"${WORK_DIR}/docker-compose-ps.txt"
{ docker ps --format '{{.Names}}' | xargs -r -I{} sh -c 'echo "[{}]"; docker inspect --format "{{json .State.Health}}" {} 2>/dev/null || echo null' || true; } >"${WORK_DIR}/container-health.txt"
[[ -f "${LOG_FILE}" ]] && cp "${LOG_FILE}" "${WORK_DIR}/installer.log"
[[ -f ".env" ]] && redact_env ".env" >"${WORK_DIR}/env-summary.redacted"
[[ -f "${STATE_FILE}" ]] && cp "${STATE_FILE}" "${WORK_DIR}/installer-state.txt"
printf 'version=%s\nutc=%s\n' "${RELEASE_VERSION}" "${TS}" >"${WORK_DIR}/release-info.txt"

tar -C "${WORK_DIR}" -czf "${BUNDLE}" .
echo "Support bundle created: ${BUNDLE}"
