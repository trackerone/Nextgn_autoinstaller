#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

write_templates() {
  local target_dir="$1"
  local domain="$2"
  local force="$3"

  mkdir -p "${target_dir}/deploy"

  copy_template "installer/templates/.env.example" "${target_dir}/.env" "${force}"
  copy_template "installer/templates/docker-compose.prod.yml" "${target_dir}/deploy/docker-compose.prod.yml" "${force}"
  copy_template "installer/templates/nginx.conf" "${target_dir}/deploy/nginx.conf" "${force}"

  sed -i "s/__NEXTGN_DOMAIN__/${domain}/g" "${target_dir}/.env"
  sed -i 's/DB_HOST=mysql/DB_HOST=database/g' "${target_dir}/.env"
  sed -i "s/__NEXTGN_DOMAIN__/${domain}/g" "${target_dir}/deploy/nginx.conf"
}

copy_template() {
  local source_file="$1"
  local destination_file="$2"
  local force="$3"

  if [[ -e "${destination_file}" && "${force}" != 'true' ]]; then
    print_warn "Skipping existing file: ${destination_file} (use --force to overwrite)"
    return 0
  fi

  cp "${source_file}" "${destination_file}"
  print_info "Template written: ${destination_file}"
}
