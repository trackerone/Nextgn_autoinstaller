#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

run_check() {
  local label="$1"
  shift
  echo "==> ${label}"
  "$@"
}

run_check 'Self test' ./scripts/self-test.sh
run_check 'Shell tests' bash -c 'for test_file in tests/*.sh; do bash "${test_file}"; done'
run_check 'Release build' ./scripts/release.sh
run_check 'Release artifact verification' ./scripts/verify-release.sh

if [[ -n "$(git status --porcelain dist)" ]]; then
  echo 'Release artifacts were generated/updated under dist/.'
fi

echo 'Release readiness checks passed.'
