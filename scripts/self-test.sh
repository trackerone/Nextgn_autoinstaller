#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

required_cmds=(bash docker git curl sed awk tar)
for cmd in "${required_cmds[@]}"; do
  command -v "${cmd}" >/dev/null || { echo "Missing command: ${cmd}"; exit 1; }
done

for f in installer/templates/.env.example installer/templates/docker-compose.prod.yml installer/templates/nginx.conf VERSION; do
  [[ -f "$f" ]] || { echo "Missing required file: $f"; exit 1; }
done

[[ -s VERSION ]] || { echo 'VERSION file is empty.'; exit 1; }
[[ -d installer/lib && -d tests && -d scripts ]] || { echo 'Expected repo structure missing.'; exit 1; }

echo 'Self-test passed.'
