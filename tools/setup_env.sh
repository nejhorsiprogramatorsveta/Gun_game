#!/usr/bin/env bash
# Project-local dev environment (the Godot equivalent of a venv):
# downloads the pinned Godot version into .tools/ so nothing is installed system-wide
# and everyone (and CI) uses the exact same engine version.
#
# Usage:  tools/setup_env.sh                  # editor/engine only
#         tools/setup_env.sh --with-templates # + export templates (large, only for local exports)
set -euo pipefail

GODOT_VERSION="4.7.2"
GODOT_TAG="${GODOT_VERSION}-stable"
BASE_URL="https://github.com/godotengine/godot/releases/download/${GODOT_TAG}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TOOLS_DIR="${ROOT}/.tools"
mkdir -p "${TOOLS_DIR}"

case "$(uname -s)" in
  Darwin) ASSET="Godot_v${GODOT_TAG}_macos.universal.zip" ;;
  Linux)  ASSET="Godot_v${GODOT_TAG}_linux.x86_64.zip" ;;
  *) echo "Unsupported OS. On Windows download Godot ${GODOT_TAG} manually from ${BASE_URL}" >&2; exit 1 ;;
esac

download_verified() {
  local file="$1"
  if [[ -f "${TOOLS_DIR}/${file}" ]]; then
    echo "Already downloaded: ${file}"
  else
    echo "Downloading ${file} ..."
    curl -fL --progress-bar -o "${TOOLS_DIR}/${file}.part" "${BASE_URL}/${file}"
    mv "${TOOLS_DIR}/${file}.part" "${TOOLS_DIR}/${file}"
  fi
  local expected
  expected="$(grep " ${file}\$" "${TOOLS_DIR}/SHA512-SUMS.txt" | awk '{print $1}')"
  local actual
  actual="$(shasum -a 512 "${TOOLS_DIR}/${file}" | awk '{print $1}')"
  if [[ -z "${expected}" || "${expected}" != "${actual}" ]]; then
    echo "Checksum mismatch for ${file}, deleting it. Run the script again." >&2
    rm -f "${TOOLS_DIR}/${file}"
    exit 1
  fi
  echo "Checksum OK: ${file}"
}

curl -fsSL -o "${TOOLS_DIR}/SHA512-SUMS.txt" "${BASE_URL}/SHA512-SUMS.txt"

download_verified "${ASSET}"
rm -rf "${TOOLS_DIR}/godot"
mkdir -p "${TOOLS_DIR}/godot"
unzip -q "${TOOLS_DIR}/${ASSET}" -d "${TOOLS_DIR}/godot"

if [[ "${1:-}" == "--with-templates" ]]; then
  TEMPLATES="Godot_v${GODOT_TAG}_export_templates.tpz"
  download_verified "${TEMPLATES}"
  case "$(uname -s)" in
    Darwin) TPL_DIR="${HOME}/Library/Application Support/Godot/export_templates/${GODOT_VERSION}.stable" ;;
    Linux)  TPL_DIR="${HOME}/.local/share/godot/export_templates/${GODOT_VERSION}.stable" ;;
  esac
  mkdir -p "${TPL_DIR}"
  unzip -q -o -j "${TOOLS_DIR}/${TEMPLATES}" -d "${TPL_DIR}"
  echo "Export templates installed to: ${TPL_DIR}"
fi

echo
echo "Done. Run Godot via:  tools/godot   (e.g. tools/godot --version)"
