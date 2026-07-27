#!/bin/bash
set -euo pipefail
export COPYFILE_DISABLE=1

YUNSH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${YUNSH_DIR}/build"
OUTPUT_DIR="${YUNSH_DIR}/output"
VERSION_CONF="${BUILD_DIR}/yunsh-version.conf"
VERSION="$(awk -F= '$1 == "VERSION" { print $2; exit }' "${VERSION_CONF}")"
OUTPUT="${OUTPUT_DIR}/YUNSH-OS-${VERSION}.ota.tar.gz"
STAGING="$(mktemp -d)"
trap 'rm -rf "${STAGING}"' EXIT

mkdir -p \
    "${STAGING}/payload/usr/bin" \
    "${STAGING}/payload/usr/share/yunsh/ui" \
    "${STAGING}/payload/usr/share/yunsh/icons" \
    "${STAGING}/payload/usr/share/yunsh/logo" \
    "${STAGING}/payload/etc/yunsh" \
    "${STAGING}/payload/etc/systemd/system"

cp "${YUNSH_DIR}"/ui/*.qml "${STAGING}/payload/usr/share/yunsh/ui/"
cp "${YUNSH_DIR}"/ui/icons/* "${STAGING}/payload/usr/share/yunsh/icons/"
cp "${YUNSH_DIR}"/logo/*.png "${STAGING}/payload/usr/share/yunsh/logo/"
cp "${VERSION_CONF}" "${STAGING}/payload/etc/yunsh/version.conf"

for source in \
    "${YUNSH_DIR}"/system/yunsh-* \
    "${YUNSH_DIR}"/boot/yunsh-firstboot.sh \
    "${YUNSH_DIR}"/boot/yunsh-iptables.sh; do
    [ -f "${source}" ] || continue
    case "${source}" in
        *.conf) continue ;;
    esac
    cp "${source}" "${STAGING}/payload/usr/bin/$(basename "${source}")"
done

for service in "${BUILD_DIR}"/yunsh-*.service; do
    [ -f "${service}" ] || continue
    cp "${service}" "${STAGING}/payload/etc/systemd/system/"
done

python3 - "${STAGING}" "${VERSION}" <<'PY'
import hashlib
import json
import os
import sys

root, version = sys.argv[1:]
payload = os.path.join(root, "payload")
files = {}
for current, _dirs, names in os.walk(payload):
    for name in sorted(names):
        path = os.path.join(current, name)
        relative = os.path.relpath(path, payload).replace(os.sep, "/")
        with open(path, "rb") as handle:
            files[relative] = hashlib.sha256(handle.read()).hexdigest()
with open(os.path.join(root, "manifest.json"), "w", encoding="utf-8") as handle:
    json.dump({
        "format": "yunsh-ota-v1",
        "version": version.lstrip("v"),
        "files": files,
    }, handle, indent=2, sort_keys=True)
PY

mkdir -p "${OUTPUT_DIR}"
tar -C "${STAGING}" -czf "${OUTPUT}" manifest.json payload
(
    cd "${OUTPUT_DIR}"
    shasum -a 256 "$(basename "${OUTPUT}")" > "$(basename "${OUTPUT}.sha256")"
)
echo "OTA bundle: ${OUTPUT}"
