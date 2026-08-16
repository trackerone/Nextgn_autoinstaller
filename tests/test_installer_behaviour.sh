#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

LOG_FILE="${tmp_dir}/nextgn-installer.log"
export LOG_FILE

source "${ROOT_DIR}/installer/lib/output.sh"
source "${ROOT_DIR}/installer/lib/logging.sh"
source "${ROOT_DIR}/installer/lib/runner.sh"
source "${ROOT_DIR}/installer/lib/templates.sh"

# template placeholder substitution
mkdir -p "${tmp_dir}/project/installer/templates"
cp "${ROOT_DIR}/installer/templates/.env.example" "${tmp_dir}/project/installer/templates/.env.example"
cp "${ROOT_DIR}/installer/templates/docker-compose.prod.yml" "${tmp_dir}/project/installer/templates/docker-compose.prod.yml"
cp "${ROOT_DIR}/installer/templates/nginx.conf" "${tmp_dir}/project/installer/templates/nginx.conf"
(
  cd "${tmp_dir}/project"
  write_templates "${tmp_dir}/project/output" "example.com" 'false'
)
secret_output="$(prepare_runtime_secrets "${tmp_dir}/project/output")"
grep -q 'APP_URL=https://example.com' "${tmp_dir}/project/output/.env"
grep -q 'server_name example.com;' "${tmp_dir}/project/output/deploy/nginx.conf"

# runtime secrets are strong, restricted, non-leaking, and stable on resume
env_file="${tmp_dir}/project/output/.env"
mysql_root_secret="${tmp_dir}/project/output/.env.mysql-root"
app_key="$(read_env_value "${env_file}" 'APP_KEY')"
db_password="$(read_env_value "${env_file}" 'DB_PASSWORD')"
mysql_root_password="$(tr -d '\r\n' < "${mysql_root_secret}")"

[[ "${app_key}" =~ ^base64:[A-Za-z0-9+/]{43}=$ ]]
[[ "${db_password}" =~ ^[a-f0-9]{64}$ ]]
[[ "${mysql_root_password}" =~ ^[a-f0-9]{64}$ ]]
[[ "${db_password}" != "${mysql_root_password}" ]]
[[ "$(stat -c '%a' "${env_file}")" == '600' ]]
[[ "$(stat -c '%a' "${mysql_root_secret}")" == '600' ]]

if grep -Fq "${app_key}" <<<"${secret_output}" || grep -Fq "${db_password}" <<<"${secret_output}" || grep -Fq "${mysql_root_password}" <<<"${secret_output}"; then
  echo 'Generated runtime secret leaked in installer output.' >&2
  exit 1
fi

prepare_runtime_secrets "${tmp_dir}/project/output" >/dev/null
[[ "$(read_env_value "${env_file}" 'APP_KEY')" == "${app_key}" ]]
[[ "$(read_env_value "${env_file}" 'DB_PASSWORD')" == "${db_password}" ]]
[[ "$(tr -d '\r\n' < "${mysql_root_secret}")" == "${mysql_root_password}" ]]

(
  cd "${tmp_dir}/project"
  write_templates "${tmp_dir}/project/output" 'forced.example.com' 'true' >/dev/null
)
prepare_runtime_secrets "${tmp_dir}/project/output" >/dev/null
[[ "$(read_env_value "${env_file}" 'APP_KEY')" == "${app_key}" ]]
[[ "$(read_env_value "${env_file}" 'DB_PASSWORD')" == "${db_password}" ]]
[[ "$(tr -d '\r\n' < "${mysql_root_secret}")" == "${mysql_root_password}" ]]

# production image and internal port contract
compose_file="${tmp_dir}/project/output/deploy/docker-compose.prod.yml"
nginx_file="${tmp_dir}/project/output/deploy/nginx.conf"
[[ "$(grep -c '^    image: nextgn-tracker:local$' "${compose_file}")" -eq 3 ]]
grep -q 'context: \.\.' "${compose_file}"
grep -q 'dockerfile: Dockerfile' "${compose_file}"
grep -q 'proxy_pass http://app:10000;' "${nginx_file}"
grep -Fq "MYSQL_DATABASE: '\${DB_DATABASE:?DB_DATABASE must be set}'" "${compose_file}"
grep -Fq "MYSQL_USER: '\${DB_USERNAME:?DB_USERNAME must be set}'" "${compose_file}"
grep -Fq "MYSQL_PASSWORD: '\${DB_PASSWORD:?DB_PASSWORD must be set}'" "${compose_file}"
grep -q 'MYSQL_ROOT_PASSWORD_FILE: /run/secrets/mysql_root_password' "${compose_file}"
grep -q 'file: ../.env.mysql-root' "${compose_file}"
if grep -q 'ghcr.io/your-org\|proxy_pass http://app:8000\|change_me' "${compose_file}" "${nginx_file}" "${env_file}"; then
  echo 'Generated deployment still contains a placeholder value or stale app port.' >&2
  exit 1
fi

bootstrap_output="$(bootstrap_app "${tmp_dir}/project/output" 'example.com' 'true')"
grep -q 'docker compose -f deploy/docker-compose.prod.yml build --pull app' <<<"${bootstrap_output}"
if grep -q 'docker compose -f deploy/docker-compose.prod.yml pull' <<<"${bootstrap_output}"; then
  echo 'Bootstrap must not pull the locally built application image.' >&2
  exit 1
fi
if grep -q 'key:generate' <<<"${bootstrap_output}"; then
  echo 'Bootstrap must use the persistent pre-generated APP_KEY.' >&2
  exit 1
fi

# state resume behavior + force overwrite behavior
STATE_DIR="${tmp_dir}/state"
STATE_FILE="${tmp_dir}/state/state"
init_state 'false' 'false'
[[ -f "${STATE_FILE}" ]]
echo 'step_one' >>"${STATE_FILE}"
init_state 'false' 'false'
grep -Eq '^step_one$' "${STATE_FILE}"
init_state 'true' 'false'
if grep -Eq '^step_one$' "${STATE_FILE}"; then
  echo 'Expected force init_state to clear previous state.' >&2
  exit 1
fi

# dry-run does not mutate files
test_file="${tmp_dir}/dry-run.txt"
run_cmd 'true' bash -lc "echo changed > '${test_file}'"
[[ ! -f "${test_file}" ]]

echo 'Installer behavior tests passed.'
