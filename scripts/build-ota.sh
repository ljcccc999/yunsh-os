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

# Keep OTA paths identical to the paths used by the full image builder.  Source
# filenames such as yunsh-appd.py are intentionally installed without their
# development suffix, because systemd invokes /usr/bin/yunsh-appd.
install_runtime() {
    local source="$1"
    local destination="$2"
    [ -f "${source}" ] || {
        echo "ERROR: required OTA source missing: ${source}" >&2
        exit 1
    }
    cp "${source}" "${STAGING}/payload/usr/bin/${destination}"
    chmod 0755 "${STAGING}/payload/usr/bin/${destination}"
}

install_runtime "${YUNSH_DIR}/system/yunsh-update-daemon.py" "yunsh-update-daemon"
install_runtime "${YUNSH_DIR}/system/yunsh-updater.py" "yunsh-updater"
install_runtime "${YUNSH_DIR}/system/yunsh-network-daemon.py" "yunsh-network-daemon"
install_runtime "${YUNSH_DIR}/system/yunsh-bluetooth-daemon.py" "yunsh-bluetooth-daemon"
install_runtime "${YUNSH_DIR}/system/yunsh-link-ble.py" "yunsh-link-ble"
install_runtime "${YUNSH_DIR}/system/yunsh-glasses-bridge.py" "yunsh-glasses-bridge"
install_runtime "${YUNSH_DIR}/system/yunsh-headtracking" "yunsh-headtracking"
install_runtime "${YUNSH_DIR}/system/yunsh-bno085-reader" "yunsh-bno085-reader"
install_runtime "${YUNSH_DIR}/system/yunsh-headtracking-sim" "yunsh-headtracking-sim"
install_runtime "${YUNSH_DIR}/system/yunsh-screenshotd" "yunsh-screenshotd"
install_runtime "${YUNSH_DIR}/system/yunsh-factory-reset" "yunsh-factory-reset"
install_runtime "${YUNSH_DIR}/system/yunsh-install-progress.sh" "yunsh-install-progress.sh"
install_runtime "${YUNSH_DIR}/system/yunsh-inputd" "yunsh-inputd"
install_runtime "${YUNSH_DIR}/system/yunsh-powerd" "yunsh-powerd"
install_runtime "${YUNSH_DIR}/system/yunsh-activation-helper" "yunsh-activation-helper"
install_runtime "${YUNSH_DIR}/system/yunsh-appd.py" "yunsh-appd"
install_runtime "${YUNSH_DIR}/system/yunsh-android" "yunsh-android"
install_runtime "${YUNSH_DIR}/system/yunsh-terminal.py" "yunsh-terminal"
install_runtime "${YUNSH_DIR}/system/yunsh-disk-helper" "yunsh-disk-helper"
install_runtime "${YUNSH_DIR}/system/yunsh-splash" "yunsh-splash"
install_runtime "${YUNSH_DIR}/boot/yunsh-firstboot.sh" "yunsh-firstboot.sh"
install_runtime "${YUNSH_DIR}/boot/yunsh-iptables.sh" "yunsh-iptables.sh"

required_services=(
    yunsh-os yunsh-firstboot yunsh-local-api yunsh-network yunsh-bluetooth
    yunsh-update yunsh-link-ble yunsh-glasses-bridge yunsh-appd
    yunsh-android-setup yunsh-terminal yunsh-headtracking yunsh-powerd yunsh-splash
)
for service_name in "${required_services[@]}"; do
    service="${BUILD_DIR}/${service_name}.service"
    [ -f "${service}" ] || {
        echo "ERROR: build service is missing: ${service}; run scripts/build-no-hdiutil.sh first" >&2
        exit 1
    }
done

for service in "${BUILD_DIR}"/yunsh-*.service; do
    [ -f "${service}" ] || continue
    cp "${service}" "${STAGING}/payload/etc/systemd/system/"
    chmod 0644 "${STAGING}/payload/etc/systemd/system/$(basename "${service}")"
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
