#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

export NEXTGN_UNATTENDED=true
export NEXTGN_DOMAIN=example.test
export NEXTGN_INSTALL_DIR="${TMP_DIR}/install"
export NEXTGN_ENABLE_TLS=false
export LOG_FILE="${TMP_DIR}/installer.log"
export STATE_DIR="${TMP_DIR}/state"
export STATE_FILE="${STATE_DIR}/state"
export LOCK_FILE="${TMP_DIR}/nextgn-installer.lock"
export NEXTGN_VERIFY_TIMEOUT_SECONDS=1
export NEXTGN_VERIFY_RETRY_INTERVAL_SECONDS=1

mkdir -p "${TMP_DIR}/bin"
cat > "${TMP_DIR}/bin/git" <<'GIT'
#!/usr/bin/env bash
set -Eeuo pipefail
if [[ "$1" == "clone" ]]; then
  target="${@: -1}"
  mkdir -p "${target}/installer/templates" "${target}/deploy" "${target}/storage" "${target}/bootstrap/cache"
  cp installer/templates/.env.example "${target}/installer/templates/.env.example"
  cp installer/templates/docker-compose.prod.yml "${target}/installer/templates/docker-compose.prod.yml"
  cp installer/templates/nginx.conf "${target}/installer/templates/nginx.conf"
  cp installer/templates/.env.example "${target}/.env.example"
  exit 0
fi
exec /usr/bin/git "$@"
GIT
cat > "${TMP_DIR}/bin/docker" <<'DOCKER'
#!/usr/bin/env bash
set -Eeuo pipefail
if [[ "$1" == "info" ]]; then exit 0; fi
if [[ "$1" == "version" ]]; then echo "24.0.5"; exit 0; fi
if [[ "$1" == "compose" && "$2" == "version" ]]; then
  if [[ "${3:-}" == "--short" ]]; then echo "2.20.2"; else echo "Docker Compose version v2.20.2"; fi
  exit 0
fi
if [[ "$1" == "compose" && "$2" == "-f" && "$4" == "config" ]]; then exit 0; fi
if [[ "$1" == "compose" ]]; then exit 0; fi
exit 0
DOCKER
cat > "${TMP_DIR}/bin/sudo" <<'SUDO'
#!/usr/bin/env bash
exit 0
SUDO
chmod +x "${TMP_DIR}/bin/"*
export PATH="${TMP_DIR}/bin:/usr/bin:/bin"

run_installer() {
  bash "${ROOT_DIR}/installer/nextgn-install.sh" --repo https://example.invalid/repo.git --dry-run
}

# unattended dry-run should be non-interactive and emit summary
run_installer >"${TMP_DIR}/dryrun.out" 2>&1
if grep -Eqi 'select|prompt|enter value' "${TMP_DIR}/dryrun.out"; then
  echo "Unexpected interactive prompt text in unattended mode." >&2
  exit 1
fi
grep -q 'Install summary:' "${TMP_DIR}/dryrun.out"

# limited real execution writes templates + state and supports resume
bash "${ROOT_DIR}/installer/nextgn-install.sh" --repo https://example.invalid/repo.git --force >"${TMP_DIR}/realrun1.out" 2>&1
grep -q 'Template written:' "${TMP_DIR}/realrun1.out"
[[ -f "${NEXTGN_INSTALL_DIR}/deploy/docker-compose.prod.yml" ]]
grep -q 'Install summary:' "${TMP_DIR}/realrun1.out"

# compose validation
if command -v docker >/dev/null 2>&1; then
  docker compose -f "${NEXTGN_INSTALL_DIR}/deploy/docker-compose.prod.yml" config >/dev/null
fi

# nginx validation: placeholders replaced and domain present
grep -q 'example.test' "${NEXTGN_INSTALL_DIR}/deploy/nginx.conf"
if command -v nginx >/dev/null 2>&1; then
  nginx -t -c "${NEXTGN_INSTALL_DIR}/deploy/nginx.conf" -p "${NEXTGN_INSTALL_DIR}" >/dev/null 2>&1 || true
fi
if grep -q '__NEXTGN_DOMAIN__' "${NEXTGN_INSTALL_DIR}/deploy/nginx.conf"; then
  echo "nginx placeholder not replaced" >&2
  exit 1
fi

# resume simulation
bash "${ROOT_DIR}/installer/nextgn-install.sh" --repo https://example.invalid/repo.git >"${TMP_DIR}/realrun2.out" 2>&1
grep -q 'Existing install state found; resume mode enabled.' "${TMP_DIR}/realrun2.out"
grep -q 'Skipping completed step:' "${TMP_DIR}/realrun2.out"

# failure simulations
bash "${ROOT_DIR}/installer/nextgn-install.sh" --repo https://example.invalid/repo.git --domain invalid_domain --dry-run >"${TMP_DIR}/invalid-domain.out" 2>&1 || true
grep -q 'Invalid domain format' "${TMP_DIR}/invalid-domain.out"

PATH="/usr/bin:/bin" bash "${ROOT_DIR}/installer/nextgn-install.sh" --repo https://example.invalid/repo.git --dry-run >"${TMP_DIR}/missing-docker.out" 2>&1 || true
grep -q 'Docker is not installed.' "${TMP_DIR}/missing-docker.out"

NEXTGN_INSTALL_DIR="/proc/nextgn-test" bash "${ROOT_DIR}/installer/nextgn-install.sh" --repo https://example.invalid/repo.git --force >"${TMP_DIR}/unwritable.out" 2>&1 || true
grep -Eqi 'Permission denied|Read-only|No such file|failed' "${TMP_DIR}/unwritable.out"

echo "APP_KEY=secret-value" > "${ROOT_DIR}/.env"
# support bundle validation
STATE_FILE="${STATE_FILE}" LOG_FILE="${LOG_FILE}" bash "${ROOT_DIR}/scripts/support-bundle.sh" "${TMP_DIR}" >"${TMP_DIR}/bundle.out"
bundle_path="$(awk -F': ' '/Support bundle created/{print $2}' "${TMP_DIR}/bundle.out")"
[[ -f "${bundle_path}" ]]
tar -tzf "${bundle_path}" | grep -q 'release-info.txt'
tar -xOzf "${bundle_path}" ./env-summary.redacted | grep -q 'APP_KEY=***REDACTED***'
rm -f "${ROOT_DIR}/.env"

echo 'Install simulation tests passed.'
