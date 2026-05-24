#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

if [[ -t 1 ]]; then
  COLOR_RED='\033[0;31m'
  COLOR_GREEN='\033[0;32m'
  COLOR_YELLOW='\033[0;33m'
  COLOR_BLUE='\033[0;34m'
  COLOR_RESET='\033[0m'
else
  COLOR_RED=''
  COLOR_GREEN=''
  COLOR_YELLOW=''
  COLOR_BLUE=''
  COLOR_RESET=''
fi

ts_prefix() {
  date -u +'%Y-%m-%dT%H:%M:%SZ'
}

print_info() {
  printf '%s %b[INFO]%b %s\n' "$(ts_prefix)" "${COLOR_BLUE}" "${COLOR_RESET}" "$*"
}

print_warn() {
  printf '%s %b[WARN]%b %s\n' "$(ts_prefix)" "${COLOR_YELLOW}" "${COLOR_RESET}" "$*"
}

print_error() {
  printf '%s %b[ERROR]%b %s\n' "$(ts_prefix)" "${COLOR_RED}" "${COLOR_RESET}" "$*" >&2
}

print_success() {
  printf '%s %b[SUCCESS]%b %s\n' "$(ts_prefix)" "${COLOR_GREEN}" "${COLOR_RESET}" "$*"
}
