#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

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

help_out="$(bash "${ROOT_DIR}/scripts/validate-vps-install.sh" --help)"
[[ "${help_out}" == *'Usage: validate-vps-install.sh'* ]]

if bash "${ROOT_DIR}/scripts/validate-vps-install.sh" --domain tracker.example.com >/dev/null 2>&1; then
  echo 'expected missing --install-dir to fail' >&2
  exit 1
fi

bash "${ROOT_DIR}/scripts/validate-vps-install.sh" --domain tracker.example.com --install-dir "${TMP_DIR}/install" --output-dir "${TMP_DIR}/out" || true
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

rm -f "${TMP_DIR}/install/deploy/docker-compose.prod.yml"
if bash "${ROOT_DIR}/scripts/validate-vps-install.sh" --domain tracker.example.com --install-dir "${TMP_DIR}/install" --output-dir "${TMP_DIR}/out2" --json-only; then
  echo 'expected missing compose file to fail' >&2
  exit 1
fi
[[ -f "${TMP_DIR}/out2/validation-report.json" ]]
[[ ! -f "${TMP_DIR}/out2/validation-report.txt" ]]
grep -q '"status":"fail"' "${TMP_DIR}/out2/validation-report.json"
grep -q 'docker-compose.prod.yml exists' "${TMP_DIR}/out2/validation-report.json"

echo 'Validate VPS tests passed.'
