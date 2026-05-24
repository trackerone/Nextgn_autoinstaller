#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

VERSION="$(tr -d '[:space:]' < VERSION)"
if [[ -z "${VERSION}" ]]; then
  echo 'VERSION is empty.' >&2
  exit 1
fi

OUT_DIR="${ROOT_DIR}/dist"
RELEASE_DIR="${OUT_DIR}/nextgn-installer-v${VERSION}"
mkdir -p "${OUT_DIR}"
rm -rf "${RELEASE_DIR}"
mkdir -p "${RELEASE_DIR}"

cp -a installer docs scripts tests README.md VERSION "${RELEASE_DIR}/"
if [[ -f LICENSE ]]; then cp -a LICENSE "${RELEASE_DIR}/"; fi

git_commit="$(git rev-parse --short=12 HEAD)"
build_timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

TAR_FILE="${OUT_DIR}/nextgn-installer-v${VERSION}.tar.gz"
ZIP_FILE="${OUT_DIR}/nextgn-installer-v${VERSION}.zip"
MANIFEST_FILE="${OUT_DIR}/release-manifest.json"
CHECKSUMS_FILE="${OUT_DIR}/SHA256SUMS"

rm -f "${TAR_FILE}" "${ZIP_FILE}" "${MANIFEST_FILE}" "${CHECKSUMS_FILE}"

tar --sort=name --mtime='UTC 1970-01-01' --owner=0 --group=0 --numeric-owner -czf "${TAR_FILE}" -C "${OUT_DIR}" "nextgn-installer-v${VERSION}"
(
  cd "${OUT_DIR}"
  zip -r -X "nextgn-installer-v${VERSION}.zip" "nextgn-installer-v${VERSION}" >/dev/null
)

(
  cd "${OUT_DIR}"
  sha256sum "nextgn-installer-v${VERSION}.tar.gz" "nextgn-installer-v${VERSION}.zip" > "${CHECKSUMS_FILE##*/}"
)

cat > "${MANIFEST_FILE}" <<JSON
{
  "version": "${VERSION}",
  "build_timestamp": "${build_timestamp}",
  "git_commit": "${git_commit}",
  "artifacts": [
    {
      "name": "$(basename "${TAR_FILE}")",
      "sha256": "$(sha256sum "${TAR_FILE}" | awk '{print $1}')"
    },
    {
      "name": "$(basename "${ZIP_FILE}")",
      "sha256": "$(sha256sum "${ZIP_FILE}" | awk '{print $1}')"
    }
  ]
}
JSON

echo "Release artifacts generated in ${OUT_DIR}"
