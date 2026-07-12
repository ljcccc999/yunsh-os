#!/bin/bash
# YUNSH OS — Simple Boot Partition Injector
# Uses Python for direct image manipulation (no hdiutil/mount needed)

set -e

YUNSH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${YUNSH_DIR}/build"
OUTPUT_DIR="${YUNSH_DIR}/output"
OUTPUT_IMG="${OUTPUT_DIR}/YUNSH-OS-v1.0.1.img"
BOOT_IMG="${BUILD_DIR}/boot-partition.img"

echo "=== YUNSH OS — Boot Partition Injector ==="

# Parse partition layout
eval $(python3 << 'PYEOF'
import struct
with open("'"${OUTPUT_IMG}"'", "rb") as f:
    mbr = f.read(512)
boot_start = struct.unpack_from("<I", mbr, 454)[0]
boot_size = struct.unpack_from("<I", mbr, 458)[0]
print(f"BOOT_START={boot_start}")
print(f"BOOT_SIZE={boot_size}")
PYEOF
)
echo "Boot partition: sector $BOOT_START, size $BOOT_SIZE sectors"

# Extract boot partition
echo "Extracting boot partition..."
dd if="${OUTPUT_IMG}" of="${BOOT_IMG}" bs=512 \
   skip=$BOOT_START count=$BOOT_SIZE 2>/dev/null
echo "  Extracted: $((BOOT_SIZE * 512)) bytes"

# ─── Step 1: Modify config.txt via byte search ─────────
echo ""
echo "→ Finding and modifying config.txt..."

python3 << 'PYEOF'
import re

boot_img = """${BOOT_IMG}"""
yunsh_dir = """${YUNSH_DIR}"""

with open(boot_img, 'rb') as f:
    data = f.read()

# Search for config.txt content markers
# config.txt starts after a FAT directory entry pointing to it
# Look for known strings: "arm_64bit", "gpu_mem", "hdmi_group"

# Find "arm_64bit=1" as a marker
idx = data.find(b"arm_64bit=1")
if idx > 0:
    # Find start of line (previous newline or start of relevant area)
    start = data.rfind(b"\n", 0, idx)
    if start < 0: start = 0
    # Find end of config (next file or EOF)
    end = data.find(b"\n# === YUNSH", idx)  # find appended section from previous build
    if end < 0:
        end = data.find(b"\n[pi4]", idx)
    if end < 0:
        end = data.find(b"\ndtoverlay=vc4-fkms-v3d", idx)
    if end < 0:
        # Find a boundary marker (like another file start)
        end = data.find(b"\0\0", idx)
        if end < 0: end = len(data)
    
    config_region = data[start:end].decode('utf-8', errors='replace')
    print(f"  Found config.txt at offset {start}-{end} ({end-start} bytes)")
    print(f"  First 100 chars: {config_region[:100]!r}")
    
    # Remove unwanted lines
    config_region = re.sub(r'^kernel_address=.*\n?', '', config_region, flags=re.MULTILINE)
    config_region = re.sub(r'^dtoverlay=vc4-fkms-v3d.*\n?', '', config_region, flags=re.MULTILINE)
    config_region = re.sub(r'^arm_freq=.*\n?', '', config_region, flags=re.MULTILINE)
    config_region = re.sub(r'^gpu_freq=.*\n?', '', config_region, flags=re.MULTILINE)
    config_region = re.sub(r'^force_turbo=.*\n?', '', config_region, flags=re.MULTILINE)
    
    # Add YUNSH section
    config_region += "\n# === YUNSH OS Settings ===\n"
    config_region += "arm_64bit=1\n"
    config_region += "[pi5]\ndtoverlay=vc4-kms-v3d\ndisable_splash=1\n"
    config_region += "framebuffer_width=1920\nframebuffer_height=1080\n"
    config_region += "framebuffer_depth=32\ndisable_overscan=1\n"
    config_region += "[all]\ndtparam=i2c_arm=on\n"
    
    # Pad or truncate to original size
    new_data = config_region.encode('utf-8')
    if len(new_data) > (end - start):
        print(f"  ⚠ New config larger than original ({len(new_data)} > {end-start}), truncating")
        new_data = new_data[:end-start]
    elif len(new_data) < (end - start):
        # Pad with spaces (safe in config.txt)
        print(f"  Padding with spaces: {end-start - len(new_data)} bytes")
        new_data = new_data.ljust(end-start, b' ')
    
    # Write back
    with open(boot_img, 'r+b') as f:
        f.seek(start)
        f.write(new_data)
    print(f"  ✓ config.txt updated ({len(new_data)} bytes)")
else:
    print("  ⚠ Could not find config.txt content")
    # Try searching for other markers
    markers = [b"gpu_mem=", b"hdmi_group=", b"disable_overscan="]
    for m in markers:
        idx = data.find(m)
        if idx >= 0:
            print(f"  Found marker '{m.decode()}' at offset {idx}")
            break
    if idx < 0:
        print("  No config markers found — boot partition may be empty")

# ─── Step 2: Modify cmdline.txt ───────────────────────
print()
print("→ Modifying cmdline.txt...")
idx = data.find(b"console=tty")
if idx > 0:
    start = max(0, data.rfind(b"\n", 0, idx))
    end = data.find(b"\n", idx)
    if end < 0: end = start + 512
    
    cmdline = data[start:end].decode('utf-8', errors='replace').strip()
    # Remove old flags
    for flag in [" quiet", " logo.nologo", " splash", " consoleblank="]:
        cmdline = re.sub(flag + r'[^\s]*', '', cmdline)
    # Remove split args with =
    cmdline = re.sub(r' consoleblank=[0-9]*', '', cmdline)
    cmdline += " quiet logo.nologo consoleblank=0 cma=256M video=HDMI-A-1:1920x1080M@60"
    
    new_cmdline = cmdline.encode('utf-8')
    if len(new_cmdline) > (end - start):
        new_cmdline = new_cmdline[:end-start]
    elif len(new_cmdline) < (end - start):
        new_cmdline = new_cmdline.ljust(end-start, b' ')
    
    with open(boot_img, 'r+b') as f:
        f.seek(start)
        f.write(new_cmdline)
    print(f"  ✓ cmdline.txt updated")
else:
    print("  ⚠ Could not find cmdline.txt")

PYEOF

# ─── Step 3: Copy YUNSH boot files ─────────────────────
echo ""
echo "→ Copying YUNSH boot files..."
# Use Python to inject files at the cluster level (simple approach: append to image)
python3 << 'PYEOF'
import struct, os

boot_img = """${BOOT_IMG}"""
yunsh_dir = """${YUNSH_DIR}"""

# Source files
splash_dir = os.path.join(yunsh_dir, "build", "splash")
boot_dir = os.path.join(yunsh_dir, "boot")

files_to_copy = []

# Script files
for f in ["yunsh-firstboot.sh", "yunsh-iptables.sh", "yunsh-ssh-config.conf"]:
    path = os.path.join(boot_dir, f)
    if os.path.isfile(path):
        files_to_copy.append((path, f))

# Splash files
if os.path.isdir(splash_dir):
    for f in sorted(os.listdir(splash_dir)):
        path = os.path.join(splash_dir, f)
        if os.path.isfile(path):
            files_to_copy.append((path, f))

print(f"  Found {len(files_to_copy)} files to copy")

# Read boot image
with open(boot_img, 'rb') as f:
    img_data = bytearray(f.read())

# For each file, find a directory entry slot and write data
# Simple approach: find 32-byte-aligned zeros (free directory entries)
# and write directory entries + allocate clusters

# The data region starts after reserved + FAT sectors
# From the BPB: reserved=32, num_fats=2, sec_per_fat=8066
# data_region_sector = 32 + 2*8066 = 16164
DATA_START = 16164 * 512  # bytes
FAT_SIZE = 8066 * 512     # bytes per FAT

def find_free_dir_entry(data):
    """Find a free 32-byte directory entry slot."""
    # Root directory starts at DATA_START (cluster 2)
    dir_start = DATA_START
    dir_end = dir_start + 512  # 1 sector for root (sec_per_cluster=1)
    i = dir_start
    while i < dir_end:
        if data[i] == 0 or data[i] == 0xE5:
            return i
        i += 32
    return None

def find_free_clusters(data, num_clusters):
    """Find N free clusters in FAT and mark them."""
    clusters = []
    fat_start = 32 * 512  # reserved sectors start at byte 32*512
    for sector in range(num_clusters):
        for c in range(2, 100000):
            offset = fat_start + c * 4
            if offset + 4 > len(data):
                break
            entry = struct.unpack_from('<I', data, offset)[0]
            if entry == 0:
                clusters.append(c)
                # Mark as EOF in first FAT
                struct.pack_into('<I', data, offset, 0x0FFFFFF8)
                # Mirror to second FAT
                second_fat_start = fat_start + FAT_SIZE
                struct.pack_into('<I', data, second_fat_start + c * 4, 0x0FFFFFF8)
                break
    return clusters

def write_directory_entry(data, entry_offset, short_name, start_cluster, file_size):
    """Write a 32-byte FAT directory entry."""
    name = short_name[:8].ljust(8, ' ') if len(short_name) > 8 else short_name.ljust(8)
    ext = ""
    if '.' in short_name:
        name_part, ext_part = os.path.splitext(short_name)
        name = name_part[:8].ljust(8, ' ')
        ext = ext_part.lstrip('.')[:3].ljust(3, ' ')
    
    entry = bytearray(32)
    entry[0:8] = name.upper().encode('ascii', errors='replace')
    entry[8:11] = ext.upper().encode('ascii', errors='replace')
    entry[11] = 0x20  # Archive
    struct.pack_into('<H', entry, 26, start_cluster & 0xFFFF)
    struct.pack_into('<H', entry, 20, (start_cluster >> 16) & 0xFFFF)
    struct.pack_into('<I', entry, 28, file_size)
    # Set timestamp
    struct.pack_into('<H', entry, 22, 0x4D21)  # date
    struct.pack_into('<H', entry, 14, 0xAE92)  # time
    
    data[entry_offset:entry_offset + 32] = bytes(entry)

# Copy each file
for src_path, dest_name in files_to_copy:
    with open(src_path, 'rb') as f:
        file_data = f.read()
    
    # Find free directory entry
    entry_offset = find_free_dir_entry(img_data)
    if entry_offset is None:
        print(f"  ⚠ No free directory entry for {dest_name}")
        continue
    
    # Allocate clusters
    cluster_size = 512  # 1 sector per cluster
    num_clusters = max(1, (len(file_data) + cluster_size - 1) // cluster_size)
    clusters = find_free_clusters(img_data, num_clusters)
    
    if len(clusters) < num_clusters:
        print(f"  ⚠ Not enough free space for {dest_name}")
        continue
    
    # Write file data
    data_start = DATA_START + (clusters[0] - 2) * cluster_size
    img_data[data_start:data_start + len(file_data)] = file_data
    
    # Write directory entry
    write_directory_entry(img_data, entry_offset, dest_name, clusters[0], len(file_data))
    print(f"  ✓ {dest_name} ({len(file_data)} bytes, cluster {clusters[0]})")

# Write modified image back
with open(boot_img, 'wb') as f:
    f.write(bytes(img_data))

print("  ✓ Files written to boot partition")
PYEOF

# ─── Step 4: Write boot partition back ──────────────────
echo ""
echo "→ Writing boot partition back to output image..."
dd if="${BOOT_IMG}" of="${OUTPUT_IMG}" bs=512 \
   seek=$BOOT_START count=$BOOT_SIZE conv=notrunc 2>/dev/null
echo "  ✓ Boot partition written back"

echo ""
echo "✅ Boot partition injection complete"
