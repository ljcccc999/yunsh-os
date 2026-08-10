#!/bin/bash
# YUNSH OS — safe macOS SD-card flasher
#
# Double-click the Desktop copy or run this file from Terminal. The flasher:
#   1. verifies the compressed image and its SHA-256 checksum;
#   2. only offers external physical disks and never selects one by default;
#   3. checks that the destination is large enough;
#   4. writes the image without requiring pv;
#   5. reads the image bytes back and verifies their SHA-256 hash.

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION_CONF="${SCRIPT_DIR}/../build/yunsh-version.conf"
DEFAULT_VERSION="v3.0.4"
if [ -f "$VERSION_CONF" ]; then
    DEFAULT_VERSION="$(awk -F= '$1 == "VERSION" {print $2; exit}' "$VERSION_CONF")"
fi
VERSION="${YUNSH_VERSION:-$DEFAULT_VERSION}"
IMAGE_NAME="YUNSH-OS-${VERSION}.img.xz"

RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
CYAN=$'\033[0;36m'
RESET=$'\033[0m'

pause_before_exit() {
    if [ -t 0 ]; then
        printf '\n按 Enter 关闭...'
        read -r _unused || true
    fi
}

fail() {
    printf '\n%s❌ %b%s\n' "$RED" "$1" "$RESET" >&2
    pause_before_exit
    exit 1
}

unexpected_error() {
    local line="$1"
    printf '\n%s❌ 烧录在第 %s 行失败。SD 卡未通过最终校验，请勿用于启动。%s\n' \
        "$RED" "$line" "$RESET" >&2
    pause_before_exit
}
trap 'unexpected_error "$LINENO"' ERR

require_command() {
    command -v "$1" >/dev/null 2>&1 ||
        fail "缺少 macOS 命令：$1"
}

for command_name in diskutil plutil xz shasum awk sed grep sudo dd sync; do
    require_command "$command_name"
done

find_image() {
    local candidate
    if [ -n "${YUNSH_IMAGE:-}" ]; then
        [ -f "$YUNSH_IMAGE" ] && {
            printf '%s\n' "$YUNSH_IMAGE"
            return 0
        }
        return 1
    fi

    for candidate in \
        "${SCRIPT_DIR}/${IMAGE_NAME}" \
        "${SCRIPT_DIR}/../output/${IMAGE_NAME}" \
        "${HOME}/Desktop/${IMAGE_NAME}"; do
        [ -f "$candidate" ] && {
            printf '%s\n' "$candidate"
            return 0
        }
    done
    return 1
}

IMAGE_XZ="$(find_image)" ||
    fail "找不到 ${IMAGE_NAME}。请把镜像和烧录脚本放在桌面。"
CHECKSUM_FILE="${YUNSH_CHECKSUM_FILE:-${IMAGE_XZ}.sha256}"

printf '%s\n' "============================================"
printf '  YUNSH OS %s 安全烧录工具\n' "$VERSION"
printf '%s\n\n' "============================================"
printf '镜像：%s\n' "$IMAGE_XZ"
printf '大小：%s\n\n' "$(du -h "$IMAGE_XZ" | awk '{print $1}')"

EXPECTED_SHA="${YUNSH_EXPECTED_SHA:-}"
if [ -z "$EXPECTED_SHA" ]; then
    [ -f "$CHECKSUM_FILE" ] ||
        fail "缺少校验文件：${CHECKSUM_FILE}"
    EXPECTED_SHA="$(awk 'NR == 1 {print tolower($1)}' "$CHECKSUM_FILE")"
fi
[[ "$EXPECTED_SHA" =~ ^[0-9a-f]{64}$ ]] ||
    fail "SHA-256 校验值格式不正确。"

printf '正在验证压缩镜像 SHA-256...\n'
ACTUAL_SHA="$(shasum -a 256 "$IMAGE_XZ" | awk '{print tolower($1)}')"
[ "$ACTUAL_SHA" = "$EXPECTED_SHA" ] ||
    fail "SHA-256 不匹配，镜像可能损坏。\n期望：${EXPECTED_SHA}\n实际：${ACTUAL_SHA}"

printf '正在检查 xz 数据完整性...\n'
xz -t "$IMAGE_XZ"

UNCOMPRESSED_BYTES="$(
    xz -l --robot "$IMAGE_XZ" |
        awk -F '\t' '$1 == "totals" {print $5; exit}'
)"
[[ "$UNCOMPRESSED_BYTES" =~ ^[0-9]+$ ]] ||
    fail "无法读取镜像解压后的大小。"

printf '正在计算写后校验值...\n'
SOURCE_RAW_SHA="$(
    xz -dc "$IMAGE_XZ" |
        shasum -a 256 |
        awk '{print tolower($1)}'
)"
[[ "$SOURCE_RAW_SHA" =~ ^[0-9a-f]{64}$ ]] ||
    fail "无法计算解压镜像的校验值。"
printf '%s✅ 镜像完整，解压大小 %.2f GiB。%s\n\n' \
    "$GREEN" "$(awk -v n="$UNCOMPRESSED_BYTES" 'BEGIN {print n/1073741824}')" "$RESET"

if [ "${1:-}" = "--check" ]; then
    trap - ERR
    printf '%s✅ 镜像校验模式完成；未访问或写入任何磁盘。%s\n' \
        "$GREEN" "$RESET"
    exit 0
fi

EXTERNAL_DISKS="$(
    diskutil list external physical 2>/dev/null |
        awk '/^\/dev\/disk[0-9]+/ {print $1}'
)"
[ -n "$EXTERNAL_DISKS" ] ||
    fail "没有检测到外置物理磁盘。请插入 SD 卡后重试。"

printf '%s可烧录的外置物理磁盘：%s\n' "$CYAN" "$RESET"
disk_index=0
while IFS= read -r disk_path; do
    [ -n "$disk_path" ] || continue
    disk_index=$((disk_index + 1))
    disk_summary="$(
        diskutil info "$disk_path" 2>/dev/null |
            awk -F: '
                /^[[:space:]]*Device \/ Media Name:/ {
                    name=$2; sub(/^[[:space:]]+/, "", name)
                }
                /^[[:space:]]*Disk Size:/ {
                    size=$2; sub(/^[[:space:]]+/, "", size)
                }
                END {
                    if (name == "") name="External disk"
                    if (size == "") size="size unknown"
                    printf "%s — %s", name, size
                }'
    )"
    printf '  [%d] %s  %s\n' "$disk_index" "$disk_path" "$disk_summary"
done <<< "$EXTERNAL_DISKS"

printf '\n请输入上面的编号或磁盘名（例如 1 或 disk4；没有默认值）：'
read -r DEVICE_INPUT
[ -n "$DEVICE_INPUT" ] || fail "未选择磁盘，已安全取消。"

if [[ "$DEVICE_INPUT" =~ ^[0-9]+$ ]] &&
   [ "$DEVICE_INPUT" -ge 1 ] &&
   [ "$DEVICE_INPUT" -le "$disk_index" ]; then
    SELECTED_DISK="$(
        printf '%s\n' "$EXTERNAL_DISKS" |
            awk -v row="$DEVICE_INPUT" 'NR == row {print; exit}'
    )"
else
    SELECTED_DISK="$DEVICE_INPUT"
fi

SELECTED_DISK="${SELECTED_DISK#/dev/}"
SELECTED_DISK="${SELECTED_DISK#r}"
[[ "$SELECTED_DISK" =~ ^disk[0-9]+$ ]] ||
    fail "磁盘名无效：${DEVICE_INPUT}"

DISK_DEVICE="/dev/${SELECTED_DISK}"
RAW_DEVICE="/dev/r${SELECTED_DISK}"

printf '%s\n' "$EXTERNAL_DISKS" | grep -qx "$DISK_DEVICE" ||
    fail "${DISK_DEVICE} 不在外置物理磁盘列表中，已拒绝烧录。"
[ -e "$DISK_DEVICE" ] && [ -e "$RAW_DEVICE" ] ||
    fail "${DISK_DEVICE} 已断开。"

DISK_INFO="$(diskutil info "$DISK_DEVICE" 2>/dev/null)" ||
    fail "无法读取 ${DISK_DEVICE} 的信息。"
printf '%s\n' "$DISK_INFO" | grep -Eq \
    '^[[:space:]]*(Device Location:[[:space:]]*External|Internal:[[:space:]]*No)' ||
    fail "${DISK_DEVICE} 不是外置磁盘。"
printf '%s\n' "$DISK_INFO" | grep -Eq \
    '^[[:space:]]*Whole:[[:space:]]*Yes' ||
    fail "${DISK_DEVICE} 不是整块磁盘，不能烧录分区。"

TARGET_BYTES="$(
    diskutil info -plist "$DISK_DEVICE" 2>/dev/null |
        plutil -extract TotalSize raw - 2>/dev/null || true
)"
if ! [[ "$TARGET_BYTES" =~ ^[0-9]+$ ]]; then
    TARGET_BYTES="$(
        printf '%s\n' "$DISK_INFO" |
            sed -nE 's/.*Disk Size:.*\(([0-9]+) Bytes\).*/\1/p' |
            head -1
    )"
fi
[[ "$TARGET_BYTES" =~ ^[0-9]+$ ]] ||
    fail "无法确认目标磁盘容量。"
[ "$TARGET_BYTES" -ge "$UNCOMPRESSED_BYTES" ] ||
    fail "目标磁盘容量不足，至少需要 ${UNCOMPRESSED_BYTES} 字节。"

printf '\n%s⚠️  即将永久擦除整块 %s%s\n' "$YELLOW" "$DISK_DEVICE" "$RESET"
printf '%s\n' "$DISK_INFO" |
    awk -F: '
        /^[[:space:]]*(Device \/ Media Name|Disk Size|Protocol):/ {
            key=$1; value=$2
            sub(/^[[:space:]]+/, "", key)
            sub(/^[[:space:]]+/, "", value)
            printf "  %s: %s\n", key, value
        }'
printf '请输入 ERASE %s 继续：' "$SELECTED_DISK"
read -r CONFIRM
[ "$CONFIRM" = "ERASE ${SELECTED_DISK}" ] ||
    fail "确认文字不匹配，已安全取消。"

printf '\n正在请求管理员权限…\n'
if ! sudo -v; then
    fail "管理员密码验证失败，未对 SD 卡执行任何写入。"
fi
# Every subsequent privileged operation is non-interactive. This prevents a
# Finder-launched script from appearing to freeze behind a second hidden sudo
# password prompt after the user has already authenticated once.
sudo -n true || fail "管理员权限没有保持，未对 SD 卡执行任何写入。请重新运行脚本。"

printf '正在卸载 %s...\n' "$DISK_DEVICE"
sudo -n diskutil unmountDisk "$DISK_DEVICE" >/dev/null ||
    fail "无法卸载 ${DISK_DEVICE}。请关闭正在使用 SD 卡的程序。"

DD_PROGRESS=()
if dd status=progress if=/dev/zero of=/dev/null count=0 >/dev/null 2>&1; then
    DD_PROGRESS=(status=progress)
fi

printf '\n🔥 正在写入，请勿拔出 SD 卡。\n'
if command -v pv >/dev/null 2>&1; then
    xz -dc "$IMAGE_XZ" |
        pv -s "$UNCOMPRESSED_BYTES" |
        sudo -n dd of="$RAW_DEVICE" bs=4m "${DD_PROGRESS[@]}"
else
    if [ "${#DD_PROGRESS[@]}" -gt 0 ]; then
        printf '未安装 pv；将显示 dd 实时进度。\n'
    else
        printf '未安装 pv；写入仍可正常进行。可按 Control-T 查看 dd 进度。\n'
    fi
    xz -dc "$IMAGE_XZ" |
        sudo -n dd of="$RAW_DEVICE" bs=4m "${DD_PROGRESS[@]}"
fi

printf '\n正在同步写入...\n'
sync

# Writing a new partition map can make macOS Disk Arbitration notice the
# volumes again. Unmount once more before raw verification so filesystem
# metadata cannot be changed while the image bytes are being read back.
printf '正在准备安全读回校验...\n'
sudo -n diskutil unmountDisk "$DISK_DEVICE" >/dev/null ||
    fail "写入完成，但无法在校验前卸载 ${DISK_DEVICE}。请关闭正在使用 SD 卡的程序后重试。"

if [ $((UNCOMPRESSED_BYTES % 4194304)) -eq 0 ]; then
    VERIFY_BLOCKS=$((UNCOMPRESSED_BYTES / 4194304))
    VERIFY_BS="4m"
elif [ $((UNCOMPRESSED_BYTES % 1048576)) -eq 0 ]; then
    VERIFY_BLOCKS=$((UNCOMPRESSED_BYTES / 1048576))
    VERIFY_BS="1m"
else
    [ $((UNCOMPRESSED_BYTES % 512)) -eq 0 ] ||
        fail "镜像大小不是 512 字节对齐，拒绝进行不完整校验。"
    VERIFY_BLOCKS=$((UNCOMPRESSED_BYTES / 512))
    VERIFY_BS="512"
fi

read_device_sha() {
    sudo -n dd if="$RAW_DEVICE" bs="$VERIFY_BS" count="$VERIFY_BLOCKS" 2>/dev/null |
        shasum -a 256 |
        awk '{print tolower($1)}'
}

printf '正在逐字节读回校验（约需数分钟）...\n'
DEVICE_RAW_SHA="$(read_device_sha)"

if [ "$DEVICE_RAW_SHA" != "$SOURCE_RAW_SHA" ]; then
    printf '%s⚠️  首次读回不一致，正在进行第二次独立读回诊断…%s\n' \
        "$YELLOW" "$RESET"
    DEVICE_RAW_SHA_RETRY="$(read_device_sha)"
    diskutil eject "$DISK_DEVICE" >/dev/null 2>&1 || true
    if [ "$DEVICE_RAW_SHA_RETRY" != "$DEVICE_RAW_SHA" ]; then
        fail "两次读回结果不同，SD 卡、读卡器或连接不稳定。请勿使用本次烧录结果。\n期望：${SOURCE_RAW_SHA}\n首次：${DEVICE_RAW_SHA}\n再次：${DEVICE_RAW_SHA_RETRY}"
    fi
    fail "两次读回结果稳定，但与镜像不同。可能是写入失败或磁盘内容被系统改写；不能仅据此断定 SD 卡损坏。\n期望：${SOURCE_RAW_SHA}\n读回：${DEVICE_RAW_SHA}"
fi

diskutil eject "$DISK_DEVICE" >/dev/null ||
    fail "写入已验证，但自动弹出失败；请在访达中手动推出。"

trap - ERR
printf '\n%s============================================%s\n' "$GREEN" "$RESET"
printf '%s  ✅ 烧录与写后校验全部通过%s\n' "$GREEN" "$RESET"
printf '%s============================================%s\n' "$GREEN" "$RESET"
printf '现在可以拔出 SD 卡，插入 Raspberry Pi 5 启动。\n'
pause_before_exit
