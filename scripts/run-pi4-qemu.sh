#!/bin/bash
# Reusable Pi-4-like ARM64 software boot harness.
# QEMU's generic virt machine is not a Raspberry Pi 4 board model; this only
# exercises the ARM64 kernel, rootfs, systemd and first-boot state machine.
# The optional GPU argument is represented by an empty Bash array when the
# serial-only test is selected.  Bash versions used on macOS treat expanding
# that array under `set -u` as an unbound-variable error, so keep nounset out
# of this small harness and let the explicit input checks below provide the
# useful failures.
set -eo pipefail

VM_DIR="${YUNSH_VM_DIR:-/private/tmp/yunsh-pi4-vm}"
BASE_RAW="${YUNSH_BASE_RAW:?set YUNSH_BASE_RAW to a decompressed YUNSH image}"
KERNEL="${YUNSH_KERNEL:-/private/tmp/yunsh-kernel/generic-kernel}"
INITRD="${YUNSH_INITRD:-/private/tmp/yunsh-kernel/generic-initrd}"
DISK="${YUNSH_DISK:-$VM_DIR/pi4-like.qcow2}"
SERIAL="${YUNSH_SERIAL:-$VM_DIR/serial.log}"
MONITOR="${YUNSH_MONITOR:-$VM_DIR/monitor.sock}"
SSH_PORT="${YUNSH_SSH_PORT:-2222}"

mkdir -p "$VM_DIR"
if [ ! -e "$DISK" ]; then
    qemu-img create -f qcow2 -F raw -b "$BASE_RAW" "$DISK" >/dev/null
fi

GPU_ARGS=()
if [ "${YUNSH_QEMU_GPU:-0}" = 1 ]; then
    GPU_ARGS=(-device virtio-gpu-pci)
fi
# The generic `virt` machine has no usable pointer device by default.  A
# tablet reports absolute coordinates, so the host cursor can interact with
# the QML UI without depending on a PS/2/USB controller being present.
INPUT_ARGS=(-device virtio-tablet-pci -device virtio-keyboard-pci)
QEMU_DISPLAY="${YUNSH_QEMU_DISPLAY:-none}"
if [ "$QEMU_DISPLAY" = cocoa ]; then
    # Keep the host pointer visible and usable while the Cocoa window is open.
    # QEMU's default grab mode can make the Mac appear frozen after the first
    # click; Ctrl-Alt-G remains available as the manual toggle.
    QEMU_DISPLAY="cocoa,full-grab=off,show-cursor=on"
fi

exec qemu-system-aarch64 \
    -machine virt -cpu cortex-a72 -smp 4 -m 4096 \
    -kernel "$KERNEL" -initrd "$INITRD" \
    -append 'root=/dev/vda2 rw rootwait console=ttyAMA0,115200 systemd.mask=boot-firmware.mount systemd.mask=cloud-init-local.service systemd.mask=cloud-init-network.service systemd.mask=cloud-config.service systemd.mask=cloud-final.service systemd.mask=cloud-init.target systemd.mask=regenerate_ssh_host_keys.service systemd.mask=yunsh-firewall.service systemd.mask=apparmor.service systemd.mask=systemd-sysctl.service systemd.mask=nftables.service systemd.mask=keyboard-setup.service' \
    -drive "if=none,file=$DISK,format=qcow2,id=hd" -device virtio-blk-pci,drive=hd \
    -netdev user,id=net0,hostfwd=tcp::${SSH_PORT}-:22 -device virtio-net-pci,netdev=net0 \
    -device virtio-rng-pci "${INPUT_ARGS[@]}" "${GPU_ARGS[@]}" -display "$QEMU_DISPLAY" \
    -serial "file:$SERIAL" -monitor "unix:$MONITOR,server,nowait"
