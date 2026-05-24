#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT
CURRENT_STEP='initializing'

redact_sensitive() {
  sed -E \
    -e 's/([Pp][Aa][Ss][Ss][Ww][Oo][Rr][Dd]|[Tt][Oo][Kk][Ee][Nn]|[Ll][Ii][Cc][Ee][Nn][Ss][Ee]|[Aa][Pp][Pp]_[Kk][Ee][Yy]|[Kk][Ee][Yy])=([^[:space:]]+)/\1=<redacted>/g' \
    -e 's/("([Pp]assword|[Tt]oken|[Ll]icense|[Kk]ey)"[[:space:]]*:[[:space:]]*")[^"]+/\1<redacted>/g'
}

dump_diagnostics() {
  echo '--- VPS test diagnostics ---' >&2
  echo "TMP_DIR=${TMP_DIR}" >&2
  echo "OUT_DIR=${TMP_DIR}/out" >&2
  echo "OUT2_DIR=${TMP_DIR}/out2" >&2
  for artifact in \
    "${TMP_DIR}/out/validation-report.txt" \
    "${TMP_DIR}/out/validation-report.json" \
    "${TMP_DIR}/out/stdout.log" \
    "${TMP_DIR}/out/stderr.log" \
    "${TMP_DIR}/out2/validation-report.txt" \
    "${TMP_DIR}/out2/validation-report.json" \
    "${TMP_DIR}/out2/stdout.log" \
    "${TMP_DIR}/out2/stderr.log"; do
    if [[ -f "${artifact}" ]]; then
      echo "--- ${artifact} ---" >&2
      redact_sensitive <"${artifact}" >&2
    fi
  done
}
trap 'echo "ERROR: step ${CURRENT_STEP} failed at line ${LINENO}: ${BASH_COMMAND}" >&2; dump_diagnostics; exit 1' ERR

mkdir -p "${TMP_DIR}/bin" "${TMP_DIR}/install/deploy" "${TMP_DIR}/out"
cat > "${TMP_DIR}/install/.env" <<'ENV'
NEXTGN_CREATE_ADMIN=true
NEXTGN_ADMIN_BOOTSTRAPPED=true
APP_KEY=super-secret
ENV
cat > "${TMP_DIR}/install/deploy/docker-compose.prod.yml" <<'YAML'
services: {}
YAML
cat > "${TMP_DIR}/install/deploy/nginx.conf" <<'NGINX'
server {}
NGINX

cat > "${TMP_DIR}/bin/docker" <<'DOCKER'
#!/usr/bin/env bash
if [[ "$1" == "--version" ]]; then echo 'Docker version 25.0.0'; exit 0; fi
if [[ "$1" == "compose" && "$2" == "version" ]]; then echo 'Docker Compose version v2.30.0'; exit 0; fi
if [[ "$1" == "compose" && "$2" == "-f" && "$4" == "config" ]]; then exit 0; fi
if [[ "$1" == "compose" && "$2" == "-f" && "$4" == "ps" && "${5:-}" == "-a" ]]; then echo 'NAME'; echo 'nextgn-app'; exit 0; fi
if [[ "$1" == "compose" && "$2" == "-f" && "$4" == "ps" && "$5" == "--status" ]]; then echo 'NAME'; [[ "$7" == "app" || "$7" == "queue" || "$7" == "scheduler" ]] && echo "nextgn-$7"; exit 0; fi
if [[ "$1" == "compose" && "$2" == "-f" && "$4" == "ps" && "$5" == "-q" ]]; then echo "cid-$6"; exit 0; fi
if [[ "$1" == "inspect" ]]; then echo 'healthy'; exit 0; fi
if [[ "$1" == "compose" && "$2" == "-f" && "$4" == "exec" ]]; then exit 0; fi
exit 0
DOCKER
cat > "${TMP_DIR}/bin/systemctl" <<'SYSTEMCTL'
#!/usr/bin/env bash
echo active
SYSTEMCTL
cat > "${TMP_DIR}/bin/curl" <<'CURL'
#!/usr/bin/env bash
if [[ "$*" == *'api.ipify.org'* ]]; then echo '203.0.113.10'; exit 0; fi
exit 0
CURL
cat > "${TMP_DIR}/bin/getent" <<'GETENT'
#!/usr/bin/env bash
echo '203.0.113.10 STREAM tracker.example.com'
GETENT
cat > "${TMP_DIR}/bin/hostnamectl" <<'H'
#!/usr/bin/env bash
echo 'vps-1'
H
chmod +x "${TMP_DIR}/bin/"*

export PATH="${TMP_DIR}/bin:/usr/bin:/bin"

CURRENT_STEP='help output'
echo '[VPS-TEST] help output'
help_out="$(bash "${ROOT_DIR}/scripts/validate-vps-install.sh" --help)"
[[ "${help_out}" == *'Usage: validate-vps-install.sh'* ]]

CURRENT_STEP='missing required args'
echo '[VPS-TEST] missing required args'
if bash "${ROOT_DIR}/scripts/validate-vps-install.sh" --domain tracker.example.com >/dev/null 2>&1; then
  echo 'expected missing --install-dir to fail' >&2
  exit 1
fi

CURRENT_STEP='report generation'
echo '[VPS-TEST] report generation'
bash "${ROOT_DIR}/scripts/validate-vps-install.sh" --domain tracker.example.com --install-dir "${TMP_DIR}/install" --output-dir "${TMP_DIR}/out" >"${TMP_DIR}/out/stdout.log" 2>"${TMP_DIR}/out/stderr.log"
[[ -f "${TMP_DIR}/out/validation-report.json" ]]
[[ -f "${TMP_DIR}/out/validation-report.txt" ]]
grep -Eq '"final_status": "(pass|warn|fail)"' "${TMP_DIR}/out/validation-report.json"
grep -q 'OS version' "${TMP_DIR}/out/validation-report.txt"

# warn/fail aggregation coverage
grep -q '"status":"warn"' "${TMP_DIR}/out/validation-report.json"
if grep -q 'super-secret' "${TMP_DIR}/out/validation-report.json"; then
  echo 'secret leaked in json report' >&2
  exit 1
fi

CURRENT_STEP='missing compose file failure'
echo '[VPS-TEST] missing compose file failure'
rm -f "${TMP_DIR}/install/deploy/docker-compose.prod.yml"
mkdir -p "${TMP_DIR}/out2"
if bash "${ROOT_DIR}/scripts/validate-vps-install.sh" --domain tracker.example.com --install-dir "${TMP_DIR}/install" --output-dir "${TMP_DIR}/out2" --json-only >"${TMP_DIR}/out2/stdout.log" 2>"${TMP_DIR}/out2/stderr.log"; then
  echo 'expected missing compose file to fail' >&2
  exit 1
fi
[[ -f "${TMP_DIR}/out2/validation-report.json" ]]
[[ ! -f "${TMP_DIR}/out2/validation-report.txt" ]]
grep -q '"status":"fail"' "${TMP_DIR}/out2/validation-report.json"
grep -q 'docker-compose.prod.yml exists' "${TMP_DIR}/out2/validation-report.json"

echo 'Validate VPS tests passed.'
