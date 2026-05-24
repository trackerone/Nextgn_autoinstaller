#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

VERSION="$(tr -d '[:space:]' < VERSION)"
OUT_DIR="${ROOT_DIR}/dist"
PREFIX="nextgn-installer-v${VERSION}"
TAR_FILE="${OUT_DIR}/${PREFIX}.tar.gz"
ZIP_FILE="${OUT_DIR}/${PREFIX}.zip"
CHECKSUMS_FILE="${OUT_DIR}/SHA256SUMS"
MANIFEST_FILE="${OUT_DIR}/release-manifest.json"

for file in "${TAR_FILE}" "${ZIP_FILE}" "${CHECKSUMS_FILE}" "${MANIFEST_FILE}"; do
  [[ -f "${file}" ]] || { echo "Missing release file: ${file}" >&2; exit 1; }
done

required_paths=(
  "${PREFIX}/installer/"
  "${PREFIX}/docs/"
  "${PREFIX}/README.md"
  "${PREFIX}/VERSION"
)
[[ -f LICENSE ]] && required_paths+=("${PREFIX}/LICENSE")

for path in "${required_paths[@]}"; do
  tar -tzf "${TAR_FILE}" | sed 's#^\./##' | grep -Fxq "${path}" || { echo "Missing in tar: ${path}" >&2; exit 1; }
  unzip -Z1 "${ZIP_FILE}" | sed 's#^\./##' | grep -Fxq "${path}" || { echo "Missing in zip: ${path}" >&2; exit 1; }
done

( cd "${OUT_DIR}" && sha256sum --check "${CHECKSUMS_FILE##*/}" )

manifest_version="$(sed -n 's/.*"version": "\([^"]*\)".*/\1/p' "${MANIFEST_FILE}" | head -n1)"
[[ "${manifest_version}" == "${VERSION}" ]] || { echo 'Manifest version mismatch.' >&2; exit 1; }

tar_version="$(tar -xOf "${TAR_FILE}" "${PREFIX}/VERSION" | tr -d '[:space:]')"
zip_version="$(unzip -p "${ZIP_FILE}" "${PREFIX}/VERSION" | tr -d '[:space:]')"
[[ "${tar_version}" == "${VERSION}" ]] || { echo 'Tar VERSION mismatch.' >&2; exit 1; }
[[ "${zip_version}" == "${VERSION}" ]] || { echo 'Zip VERSION mismatch.' >&2; exit 1; }

echo 'Release validation passed.'
