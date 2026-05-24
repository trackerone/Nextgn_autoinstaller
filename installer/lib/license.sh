#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

validate_license_key() {
  local license_key="$1"

  if [[ -z "${license_key}" ]]; then
    print_warn 'No license key provided. Continuing in unlicensed placeholder mode.'
    return 0
  fi

  # TODO: Replace with production license service call.
  if [[ "${license_key}" =~ ^[A-Za-z0-9_-]{16,}$ ]]; then
    print_success 'License key format accepted by placeholder validator.'
    return 0
  fi

  print_error 'License key format rejected by placeholder validator.'
  return 1
}
