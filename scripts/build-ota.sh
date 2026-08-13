#!/bin/bash
set -euo pipefail
export COPYFILE_DISABLE=1

YUNSH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${YUNSH_DIR}/build"
OUTPUT_DIR="${YUNSH_DIR}/output"
VERSION_CONF="${BUILD_DIR}/yunsh-version.conf"
VERSION="${YUNSH_OTA_VERSION:-$(awk -F= '$1 == "VERSION" { print $2; exit }' "${VERSION_CONF}")}"
BUILD_ID="${YUNSH_BUILD_ID:-$(date +%Y.%m.%d)}"
OTA_FORMAT="${YUNSH_OTA_FORMAT:-delta}"
OUTPUT="${OUTPUT_DIR}/YUNSH-OS-${VERSION}.ota.tar.gz"
# OTA compatibility is explicit metadata, not an implicit assumption. 4.0.1 is
# the legacy bridge whose updater understands the delta contract. The bridge
# itself is generated with YUNSH_OTA_FORMAT=legacy; normal 4.x releases use
# the delta format below.
OTA_MIN_BASE_VERSION="${YUNSH_OTA_MIN_BASE_VERSION:-4.0.1}"
OTA_MAX_BASE_VERSION="${YUNSH_OTA_MAX_BASE_VERSION:-4.99.99}"
OTA_UPGRADE_CLASS="${YUNSH_OTA_UPGRADE_CLASS:-same-major}"
MANIFEST_OUTPUT="${OUTPUT_DIR}/YUNSH-OS-${VERSION}.ota.manifest.json"
CHUNKS_OUTPUT="${OUTPUT_DIR}/YUNSH-OS-${VERSION}.ota.chunks"
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
printf 'VERSION=%s\nBUILD=%s\n' "${VERSION}" "${BUILD_ID}" \
    > "${STAGING}/payload/etc/yunsh/version.conf"
# Keep the first upgrade from v3.0.4 compatible with its older allow-list.
# The new update daemon migrates the preserved config after that reboot.

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
install_runtime "${YUNSH_DIR}/system/yunsh-spaced.py" "yunsh-spaced"
install_runtime "${YUNSH_DIR}/system/yunsh-screen-relayd.py" "yunsh-screen-relayd"
install_runtime "${YUNSH_DIR}/system/yunsh-glasses-bridge.py" "yunsh-glasses-bridge"
install_runtime "${YUNSH_DIR}/system/yunsh-headtracking" "yunsh-headtracking"
install_runtime "${YUNSH_DIR}/system/yunsh-bno085-reader" "yunsh-bno085-reader"
install_runtime "${YUNSH_DIR}/system/yunsh-headtracking-sim" "yunsh-headtracking-sim"
install_runtime "${YUNSH_DIR}/system/yunsh-screenshotd" "yunsh-screenshotd"
install_runtime "${YUNSH_DIR}/system/yunsh-recordingd" "yunsh-recordingd"
install_runtime "${YUNSH_DIR}/system/yunsh-visiond" "yunsh-visiond"
install_runtime "${YUNSH_DIR}/system/yunsh-media-setup" "yunsh-media-setup"
install_runtime "${YUNSH_DIR}/system/yunsh-grow-root" "yunsh-grow-root"
install_runtime "${YUNSH_DIR}/system/yunsh-time-sync" "yunsh-time-sync"
install_runtime "${YUNSH_DIR}/system/yunsh-openxr" "yunsh-openxr"
install_runtime "${YUNSH_DIR}/system/yunsh-openxr-run" "yunsh-openxr-run"
install_runtime "${YUNSH_DIR}/system/yunsh-factory-reset" "yunsh-factory-reset"
install_runtime "${YUNSH_DIR}/system/yunsh-install-progress.sh" "yunsh-install-progress.sh"
install_runtime "${YUNSH_DIR}/system/yunsh-ui-launcher" "yunsh-ui-launcher"
install_runtime "${YUNSH_DIR}/system/yunsh-inputd" "yunsh-inputd"
install_runtime "${YUNSH_DIR}/system/yunsh-keyinject" "yunsh-keyinject"
install_runtime "${YUNSH_DIR}/system/yunsh-powerd" "yunsh-powerd"
install_runtime "${YUNSH_DIR}/system/yunsh-activation-helper" "yunsh-activation-helper"
install_runtime "${YUNSH_DIR}/system/yunsh-appd.py" "yunsh-appd"
install_runtime "${YUNSH_DIR}/system/yunsh-android" "yunsh-android"
install_runtime "${YUNSH_DIR}/system/yunsh-terminal.py" "yunsh-terminal"
install_runtime "${YUNSH_DIR}/system/yunsh-disk-helper" "yunsh-disk-helper"
install_runtime "${YUNSH_DIR}/system/yunsh-splash" "yunsh-splash"
install_runtime "${YUNSH_DIR}/system/orbitd.py" "orbitd"
install_runtime "${YUNSH_DIR}/system/orbit-voice-setup" "orbit-voice-setup"
install_runtime "${YUNSH_DIR}/boot/yunsh-firstboot.sh" "yunsh-firstboot.sh"
install_runtime "${YUNSH_DIR}/boot/yunsh-iptables.sh" "yunsh-iptables.sh"
# The v4.0 updater has a narrower allow-list. These files already exist on a
# v4.0 installation, so omit them from the legacy bridge and let the new
# updater carry them in the subsequent delta manifest.
if [ "${OTA_FORMAT}" != "legacy" ]; then
    cp "${YUNSH_DIR}/yunsh-openxr.conf" "${STAGING}/payload/etc/yunsh/openxr.conf"
    cp "${YUNSH_DIR}/yunsh-android.conf" "${STAGING}/payload/etc/yunsh/android.conf"
fi

required_services=(
    yunsh-os yunsh-firstboot yunsh-grow-root yunsh-local-api yunsh-spaced yunsh-screen-relay yunsh-network yunsh-bluetooth
    yunsh-update yunsh-link-ble yunsh-glasses-bridge yunsh-appd
    yunsh-android-setup yunsh-terminal yunsh-headtracking yunsh-powerd yunsh-splash
    orbit orbit-voice-setup yunsh-media-setup yunsh-time-sync yunsh-openxr yunsh-vision yunsh-android-store
)
for service_name in "${required_services[@]}"; do
    service="${BUILD_DIR}/${service_name}.service"
    if [ ! -f "${service}" ] && [ -f "${YUNSH_DIR}/${service_name}.service" ]; then
        service="${YUNSH_DIR}/${service_name}.service"
    fi
    [ -f "${service}" ] || {
        echo "ERROR: build service is missing: ${service}; run scripts/build-no-hdiutil.sh first" >&2
        exit 1
    }
    cp "${service}" "${STAGING}/payload/etc/systemd/system/${service_name}.service"
    chmod 0644 "${STAGING}/payload/etc/systemd/system/${service_name}.service"
done

for service in "${BUILD_DIR}"/yunsh-*.service; do
    [ -f "${service}" ] || continue
    cp "${service}" "${STAGING}/payload/etc/systemd/system/"
    chmod 0644 "${STAGING}/payload/etc/systemd/system/$(basename "${service}")"
done
for service in "${BUILD_DIR}"/orbit*.service; do
    [ -f "${service}" ] || continue
    cp "${service}" "${STAGING}/payload/etc/systemd/system/"
    chmod 0644 "${STAGING}/payload/etc/systemd/system/$(basename "${service}")"
done

python3 - "${STAGING}" "${VERSION}" "${BUILD_ID}" "${OTA_MIN_BASE_VERSION}" "${OTA_MAX_BASE_VERSION}" "${OTA_UPGRADE_CLASS}" "${OTA_FORMAT}" "${CHUNKS_OUTPUT}" "${MANIFEST_OUTPUT}" <<'PY'
import hashlib
import json
import os
import sys

root, version, build, min_base, max_base, upgrade_class, ota_format, chunks_path, manifest_path = sys.argv[1:]
payload = os.path.join(root, "payload")
if ota_format == "legacy":
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
            "build": build,
            "files": files,
        }, handle, indent=2, sort_keys=True)
    raise SystemExit(0)
chunk_size = 1024 * 1024
files = {}
chunks = {}
with open(chunks_path, "wb") as chunk_store:
    for current, _dirs, names in os.walk(payload):
        for name in sorted(names):
            path = os.path.join(current, name)
            relative = os.path.relpath(path, payload).replace(os.sep, "/")
            file_chunks = []
            file_hash = hashlib.sha256()
            size = 0
            with open(path, "rb") as handle:
                while True:
                    data = handle.read(chunk_size)
                    if not data:
                        break
                    file_hash.update(data)
                    size += len(data)
                    digest = hashlib.sha256(data).hexdigest()
                    if digest not in chunks:
                        offset = chunk_store.tell()
                        chunk_store.write(data)
                        chunks[digest] = {"offset": offset, "length": len(data)}
                    file_chunks.append({"sha256": digest, **chunks[digest]})
            files[relative] = {
                "size": size,
                "sha256": file_hash.hexdigest(),
                "mode": os.stat(path).st_mode & 0o7777,
                "chunks": file_chunks,
            }

chunk_store_size = os.path.getsize(chunks_path)
chunk_store_hash = hashlib.sha256()
with open(chunks_path, "rb") as handle:
    for data in iter(lambda: handle.read(1024 * 1024), b""):
        chunk_store_hash.update(data)

manifest = {
    "format": "yunsh-ota-delta-v1",
    "version": version.lstrip("v"),
    "build": build,
    "min_base_version": min_base,
    "max_base_version": max_base,
    "upgrade_class": upgrade_class,
    "chunk_size": chunk_size,
    "chunk_store_size": chunk_store_size,
    "chunk_store_sha256": chunk_store_hash.hexdigest(),
    "files": files,
}
with open(manifest_path, "w", encoding="utf-8") as handle:
    json.dump(manifest, handle, indent=2, sort_keys=True)
PY

mkdir -p "${OUTPUT_DIR}"
if [ "${OTA_FORMAT}" = "legacy" ]; then
    tar -C "${STAGING}" -czf "${OUTPUT}" manifest.json payload
    (
        cd "${OUTPUT_DIR}"
        shasum -a 256 "$(basename "${OUTPUT}")" > "$(basename "${OUTPUT}.sha256")"
    )
    echo "Legacy OTA bridge: ${OUTPUT}"
    exit 0
fi
(
    cd "${OUTPUT_DIR}"
    shasum -a 256 "$(basename "${MANIFEST_OUTPUT}")" > "$(basename "${MANIFEST_OUTPUT}.sha256")"
    shasum -a 256 "$(basename "${CHUNKS_OUTPUT}")" > "$(basename "${CHUNKS_OUTPUT}.sha256")"
)
echo "OTA manifest: ${MANIFEST_OUTPUT}"
echo "OTA chunk store: ${CHUNKS_OUTPUT}"
