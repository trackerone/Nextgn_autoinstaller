#!/usr/bin/env bash

set -Eeuo pipefail
IFS=$'\n\t'

DRY_RUN='false'
FORCE='false'
DOMAIN=''
INSTALL_DIR='/opt/nextgn-tracker'
REPO_URL=''
REPO_BRANCH='main'
LICENSE_KEY=''
ENABLE_TLS='false'

show_help() {
  cat <<'HELP'
Usage: nextgn-install.sh [options]

Options:
  --domain <fqdn>
  --repo <git_url>
  --branch <branch>
  --install-dir <path>
  --license-key <key>
  --enable-tls
  --force
  --dry-run
  --help
HELP
}

require_value() {
  local flag="$1"
  local val="${2:-}"
  if [[ -z "${val}" || "${val}" == --* ]]; then
    print_error "${flag} requires a value."
    exit 1
  fi
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --domain) require_value "$1" "${2:-}"; DOMAIN="$2"; shift 2 ;;
      --install-dir|--app-dir) require_value "$1" "${2:-}"; INSTALL_DIR="$2"; shift 2 ;;
      --repo) require_value "$1" "${2:-}"; REPO_URL="$2"; shift 2 ;;
      --branch) require_value "$1" "${2:-}"; REPO_BRANCH="$2"; shift 2 ;;
      --license-key) require_value "$1" "${2:-}"; LICENSE_KEY="$2"; shift 2 ;;
      --enable-tls) ENABLE_TLS='true'; shift ;;
      --force) FORCE='true'; shift ;;
      --dry-run) DRY_RUN='true'; shift ;;
      --help) show_help; exit 0 ;;
      *) print_error "Unknown argument: $1"; show_help; exit 1 ;;
    esac
  done

  [[ -n "${DOMAIN}" ]] || { print_error '--domain is required.'; exit 1; }
  [[ -n "${REPO_URL}" ]] || { print_error '--repo is required.'; exit 1; }

  if [[ "${ENABLE_TLS}" == 'true' ]] && [[ ! "${DOMAIN}" =~ ^[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
    print_error '--enable-tls requires a valid --domain value.'
    exit 1
  fi
}
