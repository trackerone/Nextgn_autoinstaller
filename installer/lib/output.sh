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

print_info() {
  printf '%b[INFO]%b %s\n' "${COLOR_BLUE}" "${COLOR_RESET}" "$*"
}

print_warn() {
  printf '%b[WARN]%b %s\n' "${COLOR_YELLOW}" "${COLOR_RESET}" "$*"
}

print_error() {
  printf '%b[ERROR]%b %s\n' "${COLOR_RED}" "${COLOR_RESET}" "$*" >&2
}

print_success() {
  printf '%b[OK]%b %s\n' "${COLOR_GREEN}" "${COLOR_RESET}" "$*"
}
