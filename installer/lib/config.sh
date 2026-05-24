#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

DRY_RUN='false'
FORCE='false'
DOMAIN=''
APP_DIR='/opt/nextgn-tracker'
REPO_URL=''
REPO_BRANCH='main'
LICENSE_KEY=''

show_help() {
  cat <<'HELP'
Usage: nextgn-install.sh [options]

Options:
  --domain <fqdn>
  --app-dir <path>
  --repo <git_url>
  --branch <branch>
  --license-key <key>
  --force
  --dry-run
  --help
HELP
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --domain) DOMAIN="$2"; shift 2 ;;
      --app-dir) APP_DIR="$2"; shift 2 ;;
      --repo) REPO_URL="$2"; shift 2 ;;
      --branch) REPO_BRANCH="$2"; shift 2 ;;
      --license-key) LICENSE_KEY="$2"; shift 2 ;;
      --force) FORCE='true'; shift ;;
      --dry-run) DRY_RUN='true'; shift ;;
      --help) show_help; exit 0 ;;
      *) print_error "Unknown argument: $1"; show_help; exit 1 ;;
    esac
  done

  if [[ -z "${DOMAIN}" ]]; then
    print_error '--domain is required.'
    exit 1
  fi

  if [[ -z "${REPO_URL}" ]]; then
    print_error '--repo is required.'
    exit 1
  fi
}
