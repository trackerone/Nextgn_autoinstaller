#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

write_templates() {
  local target_dir="$1"
  local domain="$2"
  local force="$3"

  mkdir -p "${target_dir}/deploy"

  copy_env_template "installer/templates/.env.example" "${target_dir}/.env"
  copy_template "installer/templates/docker-compose.prod.yml" "${target_dir}/deploy/docker-compose.prod.yml" "${force}"
  copy_template "installer/templates/nginx.conf" "${target_dir}/deploy/nginx.conf" "${force}"

  sed -i "s/__NEXTGN_DOMAIN__/${domain}/g" "${target_dir}/.env"
  sed -i 's/DB_HOST=mysql/DB_HOST=database/g' "${target_dir}/.env"
  sed -i "s/__NEXTGN_DOMAIN__/${domain}/g" "${target_dir}/deploy/nginx.conf"
}

copy_env_template() {
  local source_file="$1"
  local destination_file="$2"

  if [[ -e "${destination_file}" ]]; then
    print_warn "Preserving existing runtime environment and secrets: ${destination_file}"
    return 0
  fi

  cp "${source_file}" "${destination_file}"
  print_info "Template written: ${destination_file}"
}

read_env_value() {
  local env_file="$1"
  local key="$2"
  local line

  while IFS= read -r line || [[ -n "${line}" ]]; do
    if [[ "${line}" == "${key}="* ]]; then
      printf '%s' "${line#*=}"
      return 0
    fi
  done < "${env_file}"

  return 1
}

write_env_value() {
  local env_file="$1"
  local key="$2"
  local value="$3"
  local temp_file line
  local replaced='false'

  temp_file="$(mktemp "${env_file}.tmp.XXXXXX")"
  chmod 600 "${temp_file}"

  while IFS= read -r line || [[ -n "${line}" ]]; do
    if [[ "${line}" == "${key}="* ]]; then
      printf '%s=%s\n' "${key}" "${value}" >> "${temp_file}"
      replaced='true'
    else
      printf '%s\n' "${line}" >> "${temp_file}"
    fi
  done < "${env_file}"

  if [[ "${replaced}" == 'false' ]]; then
    printf '%s=%s\n' "${key}" "${value}" >> "${temp_file}"
  fi

  mv "${temp_file}" "${env_file}"
}

secret_needs_generation() {
  local value="$1"

  [[ -z "${value}" || "${value}" == 'change_me' || "${value}" == *replace-with-generated* ]]
}

prepare_runtime_secrets() {
  local target_dir="$1"
  local env_file="${target_dir}/.env"
  local mysql_root_secret="${target_dir}/.env.mysql-root"
  local app_key db_password mysql_root_password temp_file

  if ! command -v openssl >/dev/null 2>&1; then
    print_error 'OpenSSL is required to generate runtime secrets.'
    return 1
  fi

  if [[ ! -f "${env_file}" ]]; then
    print_error "Runtime environment file is missing: ${env_file}"
    return 1
  fi

  chmod 600 "${env_file}"

  app_key="$(read_env_value "${env_file}" 'APP_KEY' || true)"
  if secret_needs_generation "${app_key}"; then
    app_key="base64:$(openssl rand -base64 32 | tr -d '\n')"
    write_env_value "${env_file}" 'APP_KEY' "${app_key}"
    print_info 'Generated a new Laravel application key.'
  fi

  db_password="$(read_env_value "${env_file}" 'DB_PASSWORD' || true)"
  if secret_needs_generation "${db_password}"; then
    db_password="$(openssl rand -hex 32)"
    write_env_value "${env_file}" 'DB_PASSWORD' "${db_password}"
    print_info 'Generated a new MySQL application password.'
  fi

  mysql_root_password=''
  if [[ -f "${mysql_root_secret}" ]]; then
    mysql_root_password="$(tr -d '\r\n' < "${mysql_root_secret}")"
  fi

  if secret_needs_generation "${mysql_root_password}"; then
    mysql_root_password="$(openssl rand -hex 32)"
    temp_file="$(mktemp "${mysql_root_secret}.tmp.XXXXXX")"
    chmod 600 "${temp_file}"
    printf '%s\n' "${mysql_root_password}" > "${temp_file}"
    mv "${temp_file}" "${mysql_root_secret}"
    print_info 'Generated a new MySQL root password secret.'
  fi

  chmod 600 "${env_file}" "${mysql_root_secret}"
  print_success 'Runtime secrets are present with restricted file permissions.'
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
