#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
source "${ROOT_DIR}/installer/lib/output.sh"
source "${ROOT_DIR}/installer/lib/config.sh"
source "${ROOT_DIR}/installer/lib/checks.sh"

reset_defaults() {
  DRY_RUN='false'; FORCE='false'; DOMAIN=''; INSTALL_DIR='/opt/nextgn-tracker'; REPO_URL=''; REPO_BRANCH='main'; LICENSE_KEY=''; ENABLE_TLS='false'; LOCAL_INSTALL='false'; INSTALL_DOCKER='false'; CREATE_ADMIN='false'; ADMIN_NAME=''; ADMIN_EMAIL=''; ADMIN_PASSWORD=''; ADMIN_PASSWORD_FILE=''; SHOW_VERSION='false'
}

assert_eq() { [[ "$1" == "$2" ]] || { echo "assertion failed: expected '$2', got '$1'"; exit 1; }; }
assert_contains() { [[ "$1" == *"$2"* ]] || { echo "assertion failed: missing '$2'"; exit 1; }; }
assert_file_contains() { grep -Fq -- "$2" "$1" || { echo "assertion failed: ${1} missing '$2'"; exit 1; }; }

run_parse() { reset_defaults; parse_args "$@"; }

run_parse --local --domain nextgn.local --repo git@example/repo.git
assert_eq "$LOCAL_INSTALL" 'true'
assert_eq "$ENABLE_TLS" 'false'

for host in nextgn.local nextgn.test localhost 192.168.1.50 10.0.0.25 172.16.4.10; do
  run_parse --local --domain "$host" --repo git@example/repo.git
  assert_eq "$DOMAIN" "$host"
  assert_eq "$LOCAL_INSTALL" 'true'
done

reset_defaults
if (parse_args --local --enable-tls --domain nextgn.local --repo git@example/repo.git) >/tmp/nextgn-local-tls.out 2>&1; then
  echo '--local --enable-tls should fail'
  exit 1
fi
assert_contains "$(cat /tmp/nextgn-local-tls.out)" '--local cannot be combined with --enable-tls'

reset_defaults
if (parse_args --local --domain tracker.example.com --repo git@example/repo.git) >/tmp/nextgn-local-domain.out 2>&1; then
  echo '--local with public-looking domain should fail'
  exit 1
fi
assert_contains "$(cat /tmp/nextgn-local-domain.out)" '--local requires localhost, a LAN IP address, or a .local/.test host'

reset_defaults
NEXTGN_LOCAL_INSTALL=true source "${ROOT_DIR}/installer/lib/config.sh"
parse_args --domain localhost --repo git@example/env.git
assert_eq "$LOCAL_INSTALL" 'true'

help_output="$( (parse_args --help) 2>&1 || true )"
assert_contains "$help_output" '--local'
assert_contains "$help_output" 'NEXTGN_LOCAL_INSTALL'

if (check_domain_dns localhost) >/tmp/nextgn-normal-dns.out 2>&1; then
  echo 'normal DNS check should reject localhost'
  exit 1
fi
assert_contains "$(cat /tmp/nextgn-normal-dns.out)" 'Invalid domain format: localhost'

assert_file_contains "${ROOT_DIR}/installer/nextgn-install.sh" 'Local install mode enabled: public DNS validation skipped.'
assert_file_contains "${ROOT_DIR}/installer/nextgn-install.sh" "run_step 'domain_check' check_domain_dns"

echo 'Local install mode tests passed.'
