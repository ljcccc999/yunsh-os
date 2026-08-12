#!/bin/bash
# Download and verify the current official Waydroid arm64 VANILLA/MAINLINE
# image pair for offline injection into a YUNSH OS image.
#
# This is a build-host step. It does not modify a running Raspberry Pi and it
# never marks Android ready unless both extracted images pass verification.

set -euo pipefail

YUNSH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="${YUNSH_ANDROID_PRELOAD_DIR:-${YUNSH_DIR}/build/android-runtime/images}"
DOWNLOAD_DIR="${YUNSH_ANDROID_DOWNLOAD_DIR:-${YUNSH_DIR}/build/android-runtime/downloads}"
SYSTEM_INDEX="${YUNSH_WAYDROID_SYSTEM_INDEX:-https://ota.waydro.id/system/lineage/waydroid_arm64/VANILLA.json}"
VENDOR_INDEX="${YUNSH_WAYDROID_VENDOR_INDEX:-https://ota.waydro.id/vendor/waydroid_arm64/MAINLINE.json}"

mkdir -p "$OUTPUT_DIR" "$DOWNLOAD_DIR"

read_index_value() {
    local url="$1" key="$2"
    curl -fsSL --connect-timeout 20 --max-time 60 "$url" |
        python3 -c 'import json,sys; d=json.load(sys.stdin)["response"][0]; print(d[sys.argv[1]])' "$key"
}

download_and_extract() {
    local index="$1" expected_name="$2" output_name="$3"
    local url sha archive temp
    url="$(read_index_value "$index" url)"
    sha="$(read_index_value "$index" id)"
    archive="${DOWNLOAD_DIR}/${expected_name}"
    temp="${OUTPUT_DIR}/.${output_name}.tmp"

    if [ ! -f "$archive" ]; then
        echo "Downloading ${expected_name}..."
        curl -fL -C - --retry 3 --connect-timeout 30 --max-time 7200 \
            -o "${archive}.part" "$url"
        mv "${archive}.part" "$archive"
    fi
    actual="$(shasum -a 256 "$archive" | awk '{print $1}')"
    [ "$actual" = "$sha" ] || {
        echo "ERROR: checksum mismatch for ${archive}" >&2
        echo "expected ${sha}, got ${actual}" >&2
        exit 1
    }
    rm -f "$temp"
    unzip -p "$archive" "$output_name" > "$temp"
    test -s "$temp"
    mv "$temp" "${OUTPUT_DIR}/${output_name}"
    echo "Prepared ${OUTPUT_DIR}/${output_name}"
}

system_archive="$(read_index_value "$SYSTEM_INDEX" filename)"
vendor_archive="$(read_index_value "$VENDOR_INDEX" filename)"
download_and_extract "$SYSTEM_INDEX" "$system_archive" system.img
download_and_extract "$VENDOR_INDEX" "$vendor_archive" vendor.img

echo "Offline Waydroid arm64 preload is ready:"
ls -lh "${OUTPUT_DIR}/system.img" "${OUTPUT_DIR}/vendor.img"
