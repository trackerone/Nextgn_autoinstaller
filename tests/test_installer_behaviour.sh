#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
source "${ROOT_DIR}/installer/lib/output.sh"
source "${ROOT_DIR}/installer/lib/logging.sh"
source "${ROOT_DIR}/installer/lib/runner.sh"
source "${ROOT_DIR}/installer/lib/templates.sh"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

# template placeholder substitution
mkdir -p "${tmp_dir}/project/installer/templates"
cp "${ROOT_DIR}/installer/templates/.env.example" "${tmp_dir}/project/installer/templates/.env.example"
cp "${ROOT_DIR}/installer/templates/docker-compose.prod.yml" "${tmp_dir}/project/installer/templates/docker-compose.prod.yml"
cp "${ROOT_DIR}/installer/templates/nginx.conf" "${tmp_dir}/project/installer/templates/nginx.conf"
(
  cd "${tmp_dir}/project"
  write_templates "${tmp_dir}/project/output" "example.com" 'false'
)
grep -q 'APP_URL=https://example.com' "${tmp_dir}/project/output/.env"
grep -q 'server_name example.com;' "${tmp_dir}/project/output/deploy/nginx.conf"

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
