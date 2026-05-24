#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
source "${ROOT_DIR}/installer/lib/output.sh"
source "${ROOT_DIR}/installer/lib/config.sh"

reset_defaults() {
  DRY_RUN='false'; FORCE='false'; DOMAIN=''; INSTALL_DIR='/opt/nextgn-tracker'; REPO_URL=''; REPO_BRANCH='main'; LICENSE_KEY=''; ENABLE_TLS='false'; INSTALL_DOCKER='false'; SHOW_VERSION='false'
}

assert_eq() { [[ "$1" == "$2" ]] || { echo "assertion failed: expected '$2', got '$1'"; exit 1; }; }

run_parse() { reset_defaults; parse_args "$@"; }

run_parse --domain example.com --repo git@example/repo.git --branch dev --install-dir /srv/nextgn --license-key abcdefghijklmnop --dry-run --force --install-docker
assert_eq "$DOMAIN" 'example.com'
assert_eq "$REPO_URL" 'git@example/repo.git'
assert_eq "$REPO_BRANCH" 'dev'
assert_eq "$INSTALL_DIR" '/srv/nextgn'
assert_eq "$LICENSE_KEY" 'abcdefghijklmnop'
assert_eq "$DRY_RUN" 'true'
assert_eq "$FORCE" 'true'
assert_eq "$INSTALL_DOCKER" 'true'

reset_defaults
help_output="$( (parse_args --help) 2>&1 || true )"
[[ "$help_output" == *'Usage: nextgn-install.sh'* ]] || { echo 'help output missing usage'; exit 1; }

echo 'Argument parsing tests passed.'

reset_defaults
parse_args --version
assert_eq "$SHOW_VERSION" 'true'


reset_defaults
NEXTGN_INSTALL_DOCKER=true source "${ROOT_DIR}/installer/lib/config.sh"
parse_args --domain env.example.com --repo git@example/env.git
assert_eq "$INSTALL_DOCKER" 'true'
