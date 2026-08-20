#!/bin/bash
# YUNSH OS - First Boot Setup
# Installs system packages, configures services
# UI files pre-injected into image

export DEBIAN_FRONTEND=noninteractive
export DEBCONF_NONINTERACTIVE_SEEN=true

# Keep a persistent log and render the installer once on the local display VT.
# The service's journal remains the diagnostic channel. Do not also write to
# /dev/console: on Pi 5 that is the same visible VT as /dev/tty1 and produces
# two overlapping progress surfaces plus raw boot text.
mkdir -p /var/log
# The local firstboot surface is tty1.  Explicitly select it before drawing so
# a getty/serial-console handoff cannot leave the HDMI output on an empty VT.
# This is harmless on headless/serial boots where chvt is unavailable.
if [ -c /dev/tty1 ] && command -v chvt >/dev/null 2>&1; then
    chvt 1 >/dev/null 2>&1 || true
fi
exec > >(tee -a /var/log/yunsh-firstboot.log /dev/tty1) 2>&1
trap 'rc=$?; printf "[TRACE] firstboot exit rc=%s line=%s\n" "$rc" "$LINENO" >> /var/log/yunsh-firstboot.log' EXIT
trap 'printf "[TRACE] firstboot signal TERM line=%s\n" "$LINENO" >> /var/log/yunsh-firstboot.log; exit 143' TERM
trap 'printf "[TRACE] firstboot signal INT line=%s\n" "$LINENO" >> /var/log/yunsh-firstboot.log; exit 130' INT
# Firstboot writes progress to tty1 but never reads from a terminal. Do not let
# a getty/console handoff send it SIGHUP and leave the image half-installed.
trap '' HUP

# The image base may move between Debian releases. Never mix a hard-coded
# distribution suite into APT/network checks.
OS_CODENAME="$(
    . /etc/os-release 2>/dev/null || . /usr/lib/os-release 2>/dev/null || true
    printf '%s' "${VERSION_CODENAME:-${DEBIAN_CODENAME:-stable}}"
)"

# Raspberry Pi OS soft-blocks the onboard radio until a regulatory domain is
# selected. YUNSH OS currently ships for Tim's China deployment; keep the
# value overrideable for future regional images instead of leaving phy0 in
# country 00/DFS-UNSET where correct SSIDs and passwords can never connect.
WIFI_COUNTRY="${YUNSH_WIFI_COUNTRY:-CN}"
if [[ "$WIFI_COUNTRY" =~ ^[A-Z]{2}$ ]]; then
    mkdir -p /etc/yunsh
    printf 'COUNTRY=%s\n' "$WIFI_COUNTRY" > /etc/yunsh/wifi-country.conf
    raspi-config nonint do_wifi_country "$WIFI_COUNTRY" >/dev/null 2>&1 || true
    iw reg set "$WIFI_COUNTRY" >/dev/null 2>&1 || true
    rfkill unblock wifi >/dev/null 2>&1 || true
fi

touch /etc/yunsh/.firstboot_partial
sync

echo ""
echo "  +------------------------------------------+"
echo "  |  YUNSH OS - First Setup                  |"
echo "  +------------------------------------------+"

source /usr/bin/yunsh-install-progress.sh 2>/dev/null || true

TOTAL=22; CUR=0; CURRENT_PROGRESS=0; CURRENT_STATUS="Preparing first setup"
# Keep the visible milestone monotonic across an automatic retry or a power
# cycle. Previously a failed late package group restarted the script at 0%
# and the next run could visibly jump from (for example) 40% back to 24%.
# This is runtime-only state: a successful setup removes it and a clean image
# never contains it.
PROGRESS_STATE="/var/lib/yunsh/firstboot-progress"
mkdir -p "$(dirname "$PROGRESS_STATE")"
if [ -r "$PROGRESS_STATE" ]; then
    saved_progress="$(sed -n '1p' "$PROGRESS_STATE" 2>/dev/null || true)"
    if [[ "$saved_progress" =~ ^[0-9]+$ ]] && [ "$saved_progress" -ge 0 ] && [ "$saved_progress" -le 100 ]; then
        CURRENT_PROGRESS="$saved_progress"
    fi
fi
save_progress() {
    local temporary="${PROGRESS_STATE}.tmp.$$"
    printf '%s\n' "$CURRENT_PROGRESS" > "$temporary" 2>/dev/null || true
    mv -f "$temporary" "$PROGRESS_STATE" 2>/dev/null || true
}
FIRSTBOOT_APT_FAILED=0
pct() { CUR=$((CUR+1)); local P=$((CUR*100/TOTAL)); [ "$P" -gt "$1" ] && P=$1
    # The milestone arguments reflect the planned install stage.  A retry or
    # an optional package must never make the user-facing total appear to go
    # backwards (for example 40% -> 24%).
    [ "$P" -lt "$CURRENT_PROGRESS" ] && P="$CURRENT_PROGRESS"
    CURRENT_PROGRESS="$P"; CURRENT_STATUS="$2"
    save_progress
    if type draw_frame &>/dev/null 2>&1; then draw_frame "$P" "$2" "$CUR" "$TOTAL"
    else echo "  [$P%] $2"; fi
}

progress_detail() {
    local status="$1" detail="${2:-}"
    CURRENT_STATUS="$status"
    save_progress
    if type draw_frame &>/dev/null 2>&1; then
        draw_frame "$CURRENT_PROGRESS" "$status" "$CUR" "$TOTAL" "$detail"
    else
        echo "  [$CURRENT_PROGRESS%] $status${detail:+ — $detail}"
    fi
}

# The Linux service account exists before any package transaction or desktop
# startup. Activation later creates a separate YUNSH-local profile and never
# renames or removes this account.
if ! id -u yunsh >/dev/null 2>&1; then
    useradd -m -s /bin/bash -G sudo,adm,dialout yunsh 2>/dev/null || true
fi
if id -u yunsh >/dev/null 2>&1; then
    # A reused Raspberry Pi OS base can already contain a `yunsh` user.  Keep
    # the release contract identical in that case as well: fixed Linux login
    # name, administrative recovery groups, and the documented default
    # password until the user explicitly changes it.
    usermod -aG sudo,adm,dialout yunsh 2>/dev/null || true
fi
if ! id -u yunsh >/dev/null 2>&1 || ! echo "yunsh:yunsh123" | chpasswd 2>/dev/null; then
    echo "  [ERROR] Unable to create the Linux service account." >&2
    exit 1
fi

# Open the recovery channel before the network wait and before any large APT
# transaction.  If firstboot or the display stack later fails, the Pi must
# still be inspectable over SSH instead of becoming a ping-only device.
ssh-keygen -A 2>/dev/null || true
systemctl enable ssh.service >/dev/null 2>&1 || true
systemctl start ssh.service >/dev/null 2>&1 || true

# Raspberry Pi OS' stock user wizard races this installer on a fresh image.
# Besides holding graphical.target, it runs dpkg-reconfigure interactively and
# locks debconf while Qt is being installed.  The builder masks it, and this
# runtime guard repairs images made by an older builder or interrupted OTA.
unit_is_masked() {
    local unit="$1"
    local unit_path="/etc/systemd/system/${unit}"
    [ -L "$unit_path" ] && [ "$(readlink "$unit_path" 2>/dev/null || true)" = "/dev/null" ]
}
if ! unit_is_masked userconfig.service; then
    systemctl stop userconfig.service 2>/dev/null || true
    systemctl disable userconfig.service 2>/dev/null || true
    systemctl mask userconfig.service 2>/dev/null || true
fi
# NetworkManager owns networking in YUNSH OS.  Do not wait two minutes for the
# deliberately unused systemd-networkd daemon on every boot.
if ! unit_is_masked systemd-networkd-wait-online.service; then
    systemctl disable systemd-networkd-wait-online.service 2>/dev/null || true
    systemctl mask systemd-networkd-wait-online.service 2>/dev/null || true
fi

# ───── Wait for network (up to about 120s) ──
echo -n "  [+] Waiting for network"
WAIT=0
TIMEOUT=24
network_ready() {
    curl -fsI --connect-timeout 2 --max-time 4 \
        "https://deb.debian.org/debian/dists/${OS_CODENAME}/InRelease" &>/dev/null ||
    curl -fsI --connect-timeout 2 --max-time 4 \
        https://deb.debian.org/debian/README &>/dev/null ||
    curl -fsI --connect-timeout 2 --max-time 4 \
        "https://mirrors.tuna.tsinghua.edu.cn/debian/dists/${OS_CODENAME}/InRelease" &>/dev/null
}

APT_OPTIONS=(
    -o Acquire::Retries=3
    -o Acquire::http::Timeout=15
    -o Acquire::https::Timeout=15
    -o Acquire::ftp::Timeout=15
    -o DPkg::Lock::Timeout=60
)

# A dpkg-deb child can occasionally stop making progress on a real Pi SD card
# while the parent apt transaction remains alive.  An unbounded transaction
# leaves firstboot looking frozen forever (the UI percentage cannot advance
# until apt returns).  Keep a generous per-command limit for slow SD cards,
# then tear down only the package-manager processes and let the existing
# repair/retry path continue.  The limit is overrideable for diagnostics.
APT_COMMAND_TIMEOUT="${YUNSH_APT_COMMAND_TIMEOUT:-900}"

apt_timeout() {
    local label="$1"
    shift
    if command -v timeout >/dev/null 2>&1; then
        timeout --foreground "${APT_COMMAND_TIMEOUT}s" "$@"
    else
        # coreutils/timeout is present on the supported Raspberry Pi OS base,
        # but keep a safe compatibility path for older development images.
        echo "  [WARN] timeout helper unavailable for ${label}; running apt normally" |
            tee -a /var/log/yunsh-apt.log
        "$@"
    fi
}

stop_stalled_package_processes() {
    local signal="$1" pid comm
    while read -r pid comm; do
        [ -n "$pid" ] || continue
        case "$comm" in
            apt|apt-get|dpkg|dpkg-deb|dpkg-query)
                [ "$pid" = "$$" ] || kill -"$signal" "$pid" 2>/dev/null || true
                ;;
        esac
    done < <(ps -eo pid=,comm= 2>/dev/null || true)
}

recover_stalled_package_processes() {
    echo "  [WARN] Timed out package transaction; stopping stale apt/dpkg processes" |
        tee -a /var/log/yunsh-apt.log
    stop_stalled_package_processes TERM
    sleep 3
    stop_stalled_package_processes KILL
    sleep 1
}

wait_for_network() {
    local tries="${1:-18}" i=0
    while [ "$i" -lt "$tries" ]; do
        network_ready && return 0
        i=$((i + 1))
        sleep 5
    done
    return 1
}

# Package installation can replace or reconfigure the network stack. Recover
# it inside firstboot instead of waiting forever for APT or requiring a power
# cycle. Starting NetworkManager is safe once its package exists; older base
# images can temporarily fall back to their original network service.
recover_network() {
    network_ready && return 0
    progress_detail "Restoring network connection..." "Automatic recovery"
    apt_services_on 2>/dev/null || true
    if command -v nmcli >/dev/null 2>&1; then
        systemctl enable NetworkManager 2>/dev/null || true
        systemctl restart NetworkManager 2>/dev/null || true
        nmcli networking on 2>/dev/null || true
        nmcli connection reload 2>/dev/null || true
    fi
    systemctl restart systemd-networkd 2>/dev/null || true
    systemctl restart dhcpcd 2>/dev/null || true
    if wait_for_network 18; then
        apt_services_off 2>/dev/null || true
        return 0
    fi
    apt_services_off 2>/dev/null || true
    return 1
}
while ! network_ready; do
    WAIT=$((WAIT+1))
    if [ $WAIT -ge $TIMEOUT ]; then
        echo " [TIMEOUT]"
        echo "  [ERROR] First setup needs an Internet connection."
        echo "  Connect Ethernet, then reboot to retry."
        exit 1
    fi
    [ $((WAIT % 12)) -eq 0 ] && echo -n $'\n  [+] Waiting for network'
    echo -n "."
    sleep 5
done
echo " [OK]"

# Package post-install scripts may try to start LXC/Waydroid, Weston, or
# hardware services while dpkg is still unpacking.  On a first boot that can
# deadlock the transaction (especially in a Pi emulator with no GPU/zram).
# Temporarily block service starts; systemd will start the enabled units after
# the package transaction and the reboot.
APT_POLICY_RC=0
APT_POLICY_BACKUP="/var/lib/yunsh/policy-rc.d.firstboot"
apt_services_off() {
    mkdir -p /var/lib/yunsh
    # Recover from a power loss or forced termination during an earlier
    # firstboot. Never preserve our own temporary policy as the administrator's
    # original policy, or all later service starts remain disabled.
    if [ -e /usr/sbin/policy-rc.d ] &&
       grep -q '^# YUNSH_FIRSTBOOT_POLICY$' /usr/sbin/policy-rc.d 2>/dev/null; then
        if [ -e "$APT_POLICY_BACKUP" ]; then
            mv -f "$APT_POLICY_BACKUP" /usr/sbin/policy-rc.d
        else
            rm -f /usr/sbin/policy-rc.d
        fi
    fi
    rm -f "$APT_POLICY_BACKUP"
    if [ -e /usr/sbin/policy-rc.d ]; then
        cp -a /usr/sbin/policy-rc.d "$APT_POLICY_BACKUP" 2>/dev/null || true
    fi
    cat > /usr/sbin/policy-rc.d <<'POLICY'
#!/bin/sh
# YUNSH_FIRSTBOOT_POLICY
exit 101
POLICY
    chmod 0755 /usr/sbin/policy-rc.d
    APT_POLICY_RC=1
}
apt_services_on() {
    [ "$APT_POLICY_RC" -eq 1 ] || return 0
    if [ -e "$APT_POLICY_BACKUP" ]; then
        mv -f "$APT_POLICY_BACKUP" /usr/sbin/policy-rc.d
    else
        rm -f /usr/sbin/policy-rc.d
    fi
    APT_POLICY_RC=0
}

firstboot_exit() {
    local rc=$?
    apt_services_on || true
    printf '[TRACE] firstboot exit rc=%s line=%s\n' \
        "$rc" "${BASH_LINENO[0]:-${LINENO}}" >> /var/log/yunsh-firstboot.log
    trap - EXIT
    exit "$rc"
}
trap firstboot_exit EXIT
apt_services_off

# The Pi 5 kernel modules are injected as a matched ABI set.  macOS builds do
# not have a native depmod, so regenerate the dependency index on the target
# before NetworkManager starts; without it brcmfmac exists on disk but Wi-Fi
# is reported as WIFI-HW missing and no wlan0 is created.
if [ -x /sbin/depmod ]; then
    /sbin/depmod -a "$(uname -r)" >>/var/log/yunsh-kernel-modules.log 2>&1 || true
fi
if [ -x /sbin/modprobe ]; then
    /sbin/modprobe brcmfmac >>/var/log/yunsh-kernel-modules.log 2>&1 || true
fi

# Debian images may start apt-daily/cloud-init package jobs in parallel with
# firstboot. Stop the scheduled jobs and wait for any transient dpkg/debconf
# lock before taking ownership of the package database.
systemctl stop apt-daily.service apt-daily-upgrade.service unattended-upgrades.service 2>/dev/null || true
for lock in /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock /var/cache/debconf/config.dat; do
    WAIT_LOCK=0
    while command -v fuser >/dev/null 2>&1 && fuser "$lock" >/dev/null 2>&1; do
        WAIT_LOCK=$((WAIT_LOCK + 1))
        [ "$WAIT_LOCK" -ge 60 ] && break
        sleep 1
    done
done

apt_repair() {
    # A power loss or a terminated firstboot can leave packages unpacked but
    # not configured.  Repair that state before retrying the next package
    # group; otherwise every later apt invocation fails immediately and the
    # desktop marker is never written.
    apt_timeout "dpkg repair" dpkg --configure -a >>/var/log/yunsh-apt.log 2>&1 || true
    apt_timeout "apt repair" apt-get "${APT_OPTIONS[@]}" -f install -yqq --no-install-recommends >>/var/log/yunsh-apt.log 2>&1 || true
}

apt_download_manifest() {
    local manifest="$1"; shift
    : > "$manifest"
    apt_timeout "${manifest} URI calculation" apt-get "${APT_OPTIONS[@]}" --print-uris -y --no-install-recommends install "$@" \
        2>>/var/log/yunsh-apt.log |
        awk '$1 ~ /^\047/ && $3 ~ /^[0-9]+$/ { print $2 "\t" $3 }' > "$manifest"
}

downloaded_bytes() {
    local manifest="$1" filename expected path actual total=0
    while IFS=$'\t' read -r filename expected; do
        [ -n "$filename" ] || continue
        path="/var/cache/apt/archives/$filename"
        [ -f "$path" ] || path="/var/cache/apt/archives/partial/$filename"
        if [ -f "$path" ]; then
            actual="$(stat -c%s "$path" 2>/dev/null || echo 0)"
            [ "$actual" -gt "$expected" ] 2>/dev/null && actual="$expected"
            total=$((total + actual))
        fi
    done < "$manifest"
    printf '%s' "$total"
}

format_mb() {
    awk -v bytes="${1:-0}" 'BEGIN { printf "%.1f", bytes / 1048576 }'
}

download_apt_group() {
    local name="$1"; shift
    local manifest="/run/yunsh-apt-download-${$}.tsv"
    local total downloaded pid rc total_mb downloaded_mb
    apt_download_manifest "$manifest" "$@"
    total="$(awk -F '\t' '{ total += $2 } END { printf "%.0f", total }' "$manifest")"
    [ -n "$total" ] || total=0
    if [ "$total" -le 0 ]; then
        progress_detail "Download complete: $name" "Already cached or installed"
        rm -f "$manifest"
        return 0
    fi

    total_mb="$(format_mb "$total")"
    apt_timeout "${name} download" apt-get "${APT_OPTIONS[@]}" --download-only -y --no-install-recommends install "$@" \
        >>/var/log/yunsh-apt.log 2>&1 &
    pid=$!
    while kill -0 "$pid" 2>/dev/null; do
        downloaded="$(downloaded_bytes "$manifest")"
        downloaded_mb="$(format_mb "$downloaded")"
        progress_detail "Downloading: $name" "本包 ${downloaded_mb} MB / ${total_mb} MB · 总安装进度 ${CURRENT_PROGRESS}%"
        sleep 2
    done
    wait "$pid"; rc=$?
    if [ "$rc" -eq 124 ]; then
        echo "  [ERROR] Package download timed out: $name" | tee -a /var/log/yunsh-apt.log
        recover_stalled_package_processes
    fi
    downloaded="$(downloaded_bytes "$manifest")"
    progress_detail "Downloading: $name" "本包 $(format_mb "$downloaded") MB / ${total_mb} MB · 总安装进度 ${CURRENT_PROGRESS}%"
    rm -f "$manifest"
    return "$rc"
}

install_apt() {
    local step="$1" name="$2"; shift 2
    pct "$step" "Installing: $name"
    local attempt=1
    local installed=1
    local apt_rc=0
    while [ "$attempt" -le 3 ]; do
        if ! network_ready && ! recover_network; then
            echo "  [WARN] Network unavailable before package group: $name" | tee -a /var/log/yunsh-apt.log
        fi
        if download_apt_group "$name" "$@"; then
            progress_detail "Unpacking and configuring: $name" "Downloaded packages are being installed"
        fi
        if apt_timeout "${name} install" apt-get "${APT_OPTIONS[@]}" --no-download install -yqq --no-install-recommends "$@" >>/var/log/yunsh-apt.log 2>&1; then
            installed=0
            break
        else
            apt_rc=$?
        fi
        echo "  [WARN] Package group failed (attempt $attempt/3): $name" | tee -a /var/log/yunsh-apt.log
        # timeout(1) returns 124.  Clean up the child dpkg/deb processes before
        # repair so the next retry cannot inherit the old deadlock or lock.
        if [ "$apt_rc" -eq 124 ]; then
            recover_stalled_package_processes
        fi
        apt_repair
        sleep $((attempt * 5))
        attempt=$((attempt + 1))
    done
    if [ "$installed" -ne 0 ]; then
        echo "  [ERROR] Package group did not complete: $name" | tee -a /var/log/yunsh-apt.log
        FIRSTBOOT_APT_FAILED=1
    fi
    apt-get clean -qq >>/var/log/yunsh-apt.log 2>&1 || true
}

# OpenXR is optional. Repository package names vary across Raspberry Pi OS
# bases, so install candidates only when available and never make the desktop
# depend on the XR loader/runtime.
install_optional_apt() {
    local step="$1" name="$2"; shift 2
    local available=() package previous_failed="${FIRSTBOOT_APT_FAILED:-0}"
    for package in "$@"; do
        if apt-cache show "$package" >/dev/null 2>&1; then
            available+=("$package")
        fi
    done
    if [ "${#available[@]}" -eq 0 ]; then
        pct "$step" "$name" "repository package unavailable; XR probe remains enabled"
        return 0
    fi
    install_apt "$step" "$name" "${available[@]}"
    # A failed optional group must not invalidate the core firstboot marker.
    if [ "$previous_failed" -eq 0 ]; then
        FIRSTBOOT_APT_FAILED=0
    fi
}

# Do not call an installation successful merely because dpkg has unpacked the
# requested packages.  The previous flow wrote .packages_installed and
# rebooted even when sshd or the desktop launch prerequisites were not usable;
# that produced a perfectly alive kernel with a black screen and no SSH port.
# Keep the marker absent on failure so systemd retries firstboot and the
# on-device progress/log remains available for diagnosis.
validate_pre_reboot() {
    local qml_runner=""
    echo ""
    echo "  [+] Validating reboot handoff..."

    if [ "$FIRSTBOOT_APT_FAILED" -ne 0 ]; then
        echo "  [ERROR] One or more package groups did not complete."
        return 1
    fi

    if [ ! -x /usr/bin/yunsh-ui-launcher ]; then
        echo "  [ERROR] Desktop launcher is missing."
        return 1
    fi
    command -v weston >/dev/null 2>&1 || {
        echo "  [ERROR] Weston is not installed."
        return 1
    }
    if [ -x /usr/lib/qt6/bin/qml ]; then
        qml_runner=/usr/lib/qt6/bin/qml
    elif [ -x /usr/lib/qt6/bin/qmlscene ]; then
        qml_runner=/usr/lib/qt6/bin/qmlscene
    else
        qml_runner="$(command -v qml6 || command -v qml || true)"
    fi
    if [ -z "$qml_runner" ]; then
        echo "  [ERROR] Qt QML runtime is not installed."
        return 1
    fi

    systemctl daemon-reload || return 1
    if ! systemctl enable ssh.service >/dev/null 2>&1; then
        echo "  [ERROR] SSH service could not be enabled."
        return 1
    fi
    # Start and verify SSH before writing the completion marker.  This is a
    # local check; it does not depend on a DHCP lease or the user's current
    # Wi-Fi address.
    if ! systemctl start ssh.service >/dev/null 2>&1; then
        echo "  [ERROR] SSH service could not be started."
        return 1
    fi
    if ! systemctl is-active --quiet ssh.service; then
        echo "  [ERROR] SSH service is not active after start."
        return 1
    fi
    if ! systemctl enable yunsh-os.service >/dev/null 2>&1; then
        echo "  [ERROR] Desktop service could not be enabled."
        return 1
    fi
    if ! systemctl is-enabled --quiet yunsh-os.service; then
        echo "  [ERROR] Desktop service is not enabled for the next boot."
        return 1
    fi

    echo "  [OK] SSH service enabled and active"
    echo "  [OK] Desktop launcher, Weston, and Qt QML runtime present"
    echo "  [OK] Desktop service enabled for post-reboot startup"
    return 0
}

# Record a KMS failure for diagnostics. Never rewrite cmdline.txt here: adding
# a VC4/V3D blacklist on Pi 5 can remove both DRM and the only framebuffer,
# turning a recoverable graphics failure into a no-display boot.
record_display_failure() {
    if [ -e /dev/dri/card0 ] ||
       ! dmesg 2>/dev/null | grep -Eq 'vc4.*(Couldn.t get|Couldn.t stop)|Failed to get (V3D|clock)'; then
        return 0
    fi
    touch /etc/yunsh/.display-recovery
    echo "  [WARN] Pi KMS failed; preserving boot configuration and SSH diagnostics." |
        tee -a /var/log/yunsh-apt.log
}

# ───── Firewall & SSH Security Setup ────────────
setup_firewall() {
    local FIREWALL_DONE="/etc/yunsh/.firewall_configured"
    local SSH_DONE="/etc/yunsh/.ssh_hardened"
    local BOOT_MNT="/boot/firmware"

    # ── Firewall ──
    if [ ! -f "$FIREWALL_DONE" ]; then
        echo "  [+] Installing firewall rules..."
        # Prefer the rootfs copy; use the boot copy as a recovery source.
        if [ -f "$BOOT_MNT/yunsh-iptables.sh" ]; then
            cp "$BOOT_MNT/yunsh-iptables.sh" /usr/bin/yunsh-iptables.sh
            chmod +x /usr/bin/yunsh-iptables.sh
        fi

        if [ -x /usr/bin/yunsh-iptables.sh ]; then

            cat > /etc/systemd/system/yunsh-firewall.service << 'UNIT'
[Unit]
Description=YUNSH OS Firewall (iptables)
Before=network-pre.target
Wants=network-pre.target
DefaultDependencies=no

[Service]
Type=oneshot
ExecStart=/usr/bin/yunsh-iptables.sh
RemainAfterExit=yes
StandardOutput=journal

[Install]
WantedBy=multi-user.target
UNIT

            systemctl daemon-reload
            if systemctl enable yunsh-firewall.service; then
                if systemctl start yunsh-firewall.service; then
                    touch "$FIREWALL_DONE"
                    echo "  [OK] Firewall configured and enabled"
                else
                    echo "  [WARN] Firewall will retry at the next boot"
                fi
            else
                echo "  [WARN] Firewall service could not be enabled"
            fi
        else
            echo "  [WARN] yunsh-iptables.sh not found, firewall not configured"
        fi
    else
        echo "  [SKIP] Firewall already configured"
    fi

    # ── SSH Hardening ──
    if [ ! -f "$SSH_DONE" ]; then
        echo "  [+] Hardening SSH configuration..."
        mkdir -p /etc/ssh/sshd_config.d
        cat > /etc/ssh/sshd_config.d/yunsh.conf << 'SSH'
# YUNSH OS - SSH Server Hardening
Port 22
Protocol 2
MaxAuthTries 3
ClientAliveInterval 120
ClientAliveCountMax 3
PermitRootLogin prohibit-password
PasswordAuthentication yes
X11Forwarding no
SSH
        chmod 644 /etc/ssh/sshd_config.d/yunsh.conf

        # Remove old-style permit-root section if present in sshd_config
        sed -i '/^PermitRootLogin/d' /etc/ssh/sshd_config 2>/dev/null || true

        systemctl restart sshd || systemctl restart ssh 2>/dev/null || true
        echo "  [OK] SSH hardening applied and sshd restarted"
        touch "$SSH_DONE"
    else
        echo "  [SKIP] SSH already hardened"
    fi
}

# Wait for NTP (max 30s)
for i in $(seq 1 30); do
    timedatectl show -p NTPSynchronized 2>/dev/null | grep -q "yes" && break
    sleep 1
done

pct 3 "Updating package lists..."
# Keep the first package-list refresh under the same bounded/retry policy as
# every later apt transaction.  The previous bare apt-get could wait forever
# on a dead mirror or a half-open connection, leaving the visible installer at
# one percentage until a power cycle.  A timed failure exits firstboot cleanly;
# the existing partial-install marker makes the next boot retry safely.
APT_UPDATE_OK=0
for APT_UPDATE_ATTEMPT in 1 2; do
    if apt_timeout "package list update (attempt ${APT_UPDATE_ATTEMPT})" \
        apt-get "${APT_OPTIONS[@]}" update -qq >>/var/log/yunsh-apt.log 2>&1; then
        APT_UPDATE_OK=1
        break
    fi
    recover_stalled_package_processes
    [ "$APT_UPDATE_ATTEMPT" -lt 2 ] && sleep 10
done
if [ "$APT_UPDATE_OK" -ne 1 ]; then
    echo "  [ERROR] Package list update failed or timed out; firstboot will retry on reboot." |
        tee -a /var/log/yunsh-apt.log
    exit 1
fi

# Install packages
# Do not replace the boot-critical Pi 5 kernel/firmware during firstboot.  The
# base image already carries the tested firmware layer; upgrading it while the
# system is online can leave the running kernel and firmware KMS hand-off out
# of sync and make vc4/v3d fail to create /dev/dri/card0 after reboot.  Kernel
# updates belong in a separately validated OTA, never in the first desktop
# installation transaction.
pct 6 "Checking Raspberry Pi kernel and firmware..."
for boot_package in linux-image-rpi-2712 raspi-firmware raspi-utils-core; do
    if ! dpkg-query -W -f='${Status}' "$boot_package" 2>/dev/null |
        grep -q "install ok installed"; then
        echo "  [WARN] Boot package is not installed yet: $boot_package" |
            tee -a /var/log/yunsh-apt.log
    fi
done
install_apt 8 "Qt6 framework" qt6-base-dev qt6-declarative-dev libqt6svg6 qt6-svg-plugins libqt6opengl6 qt6-base-dev-tools qt6-qmltooling-plugins qml-qt6 qmlscene-qt6 qml6-module-qtqml qml6-module-qtqml-workerscript qml6-module-qtquick qml6-module-qtquick-controls qml6-module-qtquick-layouts qml6-module-qtquick-window qml6-module-qtquick-virtualkeyboard qml6-module-qt-labs-qmlmodels qml6-module-qt-labs-folderlistmodel qml6-module-qtquick-shapes qml6-module-qtquick-templates
install_apt 14 "Python environment" python3-cryptography python3-pip python3-smbus2
install_apt 20 "WebEngine" qt6-webengine-dev libqt6webenginequick6 qml6-module-qtwebengine
# Keep LXC/Waydroid out of the boot-critical transaction.  Its postinst can
# require kernel cgroup/namespaces that are unavailable in emulators and it
# is already prepared asynchronously by yunsh-android-setup.service.
install_apt 24 "Android display runtime" python3-dbus python3-gi weston libwayland-client0 qml6-module-qtwayland-compositor qt6-wayland
install_apt 32 "Network & BT" network-manager wpasupplicant bluez
# NetworkManager is needed by the final OS, but restarting an already-active
# manager deliberately drops the very Wi-Fi/Ethernet link still carrying the
# remaining packages. That was the reproducible mid-install stall which often
# recovered only after a power cycle. Preserve the live process and connection;
# start it only when the package installation left it inactive.
apt_services_on
progress_detail "Activating NetworkManager..." "Keeping first-boot downloads online"
systemctl enable NetworkManager 2>/dev/null || true
if ! systemctl is-active --quiet NetworkManager 2>/dev/null; then
    systemctl start NetworkManager 2>/dev/null || true
fi
nmcli networking on 2>/dev/null || true
nmcli connection reload 2>/dev/null || true
if ! wait_for_network 18 && ! recover_network; then
    echo "  [ERROR] NetworkManager handoff failed; firstboot will retry automatically." | tee -a /var/log/yunsh-apt.log
    exit 1
fi
apt_services_off
install_apt 38 "System tools" openssh-server avahi-daemon avahi-utils openssl iptables i2c-tools curl wget git unzip python3-pil psmisc util-linux
install_apt 44 "Chinese input and emoji" fonts-noto-cjk fonts-noto-color-emoji fcitx5 fcitx5-chinese-addons fcitx5-frontend-qt6 python3-pam
# Install the userspace Bluetooth audio path during first boot when the base
# repository provides it. A2DP is optional hardware support and must never
# prevent the core desktop/activation marker from being written.
install_optional_apt 50 "Bluetooth audio speakers" pulseaudio pulseaudio-module-bluetooth
# Screen capture, recording, and OCR are optional and can contend with
# cloud-init's debconf database on a fresh image. Prepare all of them
# asynchronously with yunsh-media-setup.service after the desktop marker.
pct 53 "Scheduling screen capture and recording..."
# wf-recorder is also installed asynchronously by yunsh-media-setup.service.
# Raspberry Pi 5 uses the BCM2712 VideoCore VII through the DRM/KMS + V3D
# stack. Keep both EGL/OpenGL (Qt Quick/Weston) and Vulkan (Waydroid and
# future spatial compositor work) in the first-boot transaction, rather than
# silently falling back to an incomplete software graphics stack.
# Mesa's software/EGL pieces are part of the core check below, but optional
# utilities/Vulkan packages vary across the Raspberry Pi and generic ARM64
# repositories. Do not make a repository-specific Vulkan utility failure look
# like a first-boot or display failure; the optional pieces can be retried
# after the desktop is reachable.
install_optional_apt 56 "Pi 5 graphics runtime" mesa-utils libgl1-mesa-dri libegl1 mesa-vulkan-drivers
install_optional_apt 57 "OpenXR loader and runtime packages" libopenxr-loader1 libopenxr-dev openxr-utils openxr-tools monado monado-service

# Waydroid remains a core component, but its repository and Android image are
# external network dependencies. They must never block activation or desktop
# startup. yunsh-android-setup.service prepares it in the background and
# retries safely after this first-boot transaction has completed.
pct 58 "Scheduling Android runtime setup..."
apt_services_on
mkdir -p /var/lib/yunsh \
    /var/lib/yunsh/space-inbox \
    /var/lib/yunsh/media \
    /var/lib/yunsh/orbit/voice \
    /run/yunsh
printf '{"state":"pending","progress":0,"message":"Android setup is queued"}\n' \
    > /var/lib/yunsh/android-setup.json

pct 62 "Checking desktop runtime..."

pct 68 "Starting core services..."
systemctl enable NetworkManager bluetooth ssh 2>/dev/null || true
systemctl start NetworkManager bluetooth 2>/dev/null || true
systemctl disable dhcpcd 2>/dev/null || true
systemctl stop dhcpcd 2>/dev/null || true

pct 74 "Configuring YUNSH OS..."
mkdir -p /etc/yunsh

pct 78 "Configuring firewall & SSH..."
setup_firewall

pct 84 "Enabling YUNSH services..."
systemctl enable yunsh-os yunsh-local-api yunsh-network yunsh-bluetooth yunsh-update yunsh-link-ble yunsh-glasses-bridge yunsh-spaced yunsh-screen-relay \
    yunsh-appd yunsh-android-setup yunsh-terminal yunsh-headtracking yunsh-powerd \
    fstrim.timer 2>/dev/null || true

pct 86 "Creating default user..."
usermod -a -G sudo,adm,dialout yunsh 2>/dev/null || true
ssh-keygen -A 2>/dev/null || true
echo "yunsh-v1" > /etc/hostname
hostname yunsh-v1 2>/dev/null || true
if grep -qE '^[[:space:]]*127\.0\.1\.1[[:space:]]+' /etc/hosts 2>/dev/null; then
    sed -i -E 's/^[[:space:]]*127\.0\.1\.1[[:space:]]+.*/127.0.1.1 yunsh-v1/' /etc/hosts
else
    printf '\n127.0.1.1 yunsh-v1\n' >> /etc/hosts
fi

pct 92 "Preparing Android application store..."
# The Tencent App Store APK is embedded in the 4.0 full image and installed by
# the independent post-boot Android store service. This check only verifies
# that the controller was embedded; it never starts Android during firstboot.
[ -x /usr/bin/yunsh-android ] || {
    echo "  [ERROR] Android application controller is missing."
    exit 1
}

# Package groups have already completed with retries above. Do not run an
# unbounded final apt repair here: a background debconf lock could otherwise
# prevent the desktop marker from ever being written. The exact core package
# status check below is the authoritative gate.

pct 98 "Cleaning up..."
record_display_failure
CORE_PACKAGES="linux-image-rpi-2712 raspi-firmware raspi-utils-core qml-qt6 qt6-svg-plugins libqt6opengl6 qml6-module-qtqml qml6-module-qtqml-workerscript qml6-module-qtquick qml6-module-qtquick-controls qml6-module-qtquick-layouts qml6-module-qtquick-virtualkeyboard qml6-module-qtquick-templates qml6-module-qt-labs-qmlmodels qml6-module-qt-labs-folderlistmodel qml6-module-qtquick-shapes qml6-module-qtwebengine qt6-wayland weston network-manager wpasupplicant bluez openssh-server avahi-daemon avahi-utils openssl iptables i2c-tools curl wget git unzip python3-pil python3-cryptography python3-smbus2 python3-dbus python3-gi python3-pam libegl1 libgl1-mesa-dri psmisc util-linux fonts-noto-cjk fonts-noto-color-emoji fcitx5 fcitx5-chinese-addons fcitx5-frontend-qt6"
CORE_MISSING=""
for package in $CORE_PACKAGES; do
    dpkg-query -W -f='${Status}' "$package" 2>/dev/null |
        grep -q "install ok installed" || CORE_MISSING="$CORE_MISSING $package"
done
if { [ ! -x /usr/lib/qt6/bin/qml ] && \
      ! command -v qml6 >/dev/null 2>&1 && \
      ! command -v qml >/dev/null 2>&1; } || [ -n "$CORE_MISSING" ]; then
    echo ""
    echo "  [ERROR] Required desktop packages are missing:$CORE_MISSING"
    echo "  DPKG details are in /var/log/yunsh-apt.log; reboot to retry."
    exit 1
fi

if ! validate_pre_reboot; then
    echo "  [ERROR] Reboot handoff validation failed; installation will retry without marking completion."
    exit 1
fi

pct 100 "Setup complete! Rebooting..."
rm -f /etc/yunsh/.firstboot_partial 2>/dev/null || true
touch /etc/yunsh/.packages_installed
rm -f "$PROGRESS_STATE" "${PROGRESS_STATE}.tmp.$$" 2>/dev/null || true
rm -f /usr/bin/yunsh-firstboot.sh
sync
sleep 2
reboot
