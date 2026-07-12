#!/usr/bin/env python3
"""
YUNSH OS — FAT32 Boot Partition Modifier
Direct byte-level manipulation of FAT32 partition image.
No hdiutil, no mount, no mtools needed.
"""

import os, re, shutil, struct, sys

YUNSH_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BUILD_DIR = os.path.join(YUNSH_DIR, "build")
OUTPUT_DIR = os.path.join(YUNSH_DIR, "output")
OUTPUT_IMG = os.path.join(OUTPUT_DIR, "YUNSH-OS-v1.0.1.img")
BOOT_IMG = os.path.join(BUILD_DIR, "boot-partition.img")

# FAT32 geometry from the RPi OS boot partition
BYTES_PER_SEC = 512
SEC_PER_CLUSTER = 1
RESERVED_SEC = 32
NUM_FATS = 2
SEC_PER_FAT = 8066
DATA_START_SEC = RESERVED_SEC + NUM_FATS * SEC_PER_FAT
DATA_START = DATA_START_SEC * BYTES_PER_SEC
FAT_START = RESERVED_SEC * BYTES_PER_SEC
SECOND_FAT_START = FAT_START + SEC_PER_FAT * BYTES_PER_SEC
CLUSTER_SIZE = BYTES_PER_SEC * SEC_PER_CLUSTER


def parse_mbr(img_path):
    """Parse MBR partition table to get boot partition offset."""
    with open(img_path, 'rb') as f:
        mbr = f.read(512)
    boot_start = struct.unpack_from('<I', mbr, 454)[0]
    boot_size = struct.unpack_from('<I', mbr, 458)[0]
    return boot_start, boot_size


def extract_boot_partition(img_path, boot_start, boot_size):
    """Extract boot partition from image."""
    with open(img_path, 'rb') as f_in:
        f_in.seek(boot_start * BYTES_PER_SEC)
        data = f_in.read(boot_size * BYTES_PER_SEC)
    return bytearray(data)


def write_boot_partition(img_path, boot_start, boot_data):
    """Write boot partition back to image."""
    with open(img_path, 'r+b') as f_out:
        f_out.seek(boot_start * BYTES_PER_SEC)
        f_out.write(bytes(boot_data))
    print(f"  ✓ Written {len(boot_data)} bytes back to image")


def find_file_in_fat(data, filename):
    """Find a file in the FAT32 root directory, return (offset, size, cluster)."""
    # Search root directory for filename
    dir_start = DATA_START
    dir_end = dir_start + CLUSTER_SIZE  # Root directory is 1 cluster
    
    i = dir_start
    while i < dir_end:
        entry = data[i:i+32]
        if entry[0] == 0:
            break
        if entry[0] == 0xE5:
            i += 32
            continue
        if entry[11] & 0x0F == 0x0F:  # LFN
            i += 32
            continue
        if entry[11] & 0x10:  # Directory
            i += 32
            continue
        
        # Compare short name
        name = entry[0:8].decode('ascii', errors='replace').rstrip()
        ext = entry[8:11].decode('ascii', errors='replace').rstrip()
        short_name = f"{name}.{ext}" if ext else name
        
        if short_name.upper() == filename.upper() or short_name.rstrip().upper() == filename.upper():
            size = struct.unpack_from('<I', entry, 28)[0]
            clus_low = struct.unpack_from('<H', entry, 26)[0]
            clus_high = struct.unpack_from('<H', entry, 20)[0]
            cluster = (clus_high << 16) | clus_low
            return (i, size, cluster)
        i += 32
    return None


def read_cluster_chain(data, start_cluster, size):
    """Read data from a cluster chain."""
    result = bytearray()
    cluster = start_cluster
    while cluster >= 2 and cluster < 0x0FFFFFF8 and len(result) < size:
        sector_in_data = (cluster - 2) * SEC_PER_CLUSTER
        offset = DATA_START + sector_in_data * BYTES_PER_SEC
        chunk = data[offset:offset + CLUSTER_SIZE]
        result.extend(chunk)
        # Read FAT entry for next cluster
        fat_entry = struct.unpack_from('<I', data, FAT_START + cluster * 4)[0]
        cluster = fat_entry & 0x0FFFFFFF
        # Handle EOC
        if cluster >= 0x0FFFFFF0:
            break
    return bytes(result[:size])


def find_config_range(data):
    """Find config.txt content range by looking for unique markers."""
    markers = [
        b"gpu_mem=", b"arm_64bit=", b"hdmi_group=", b"disable_overscan=",
        b"dtoverlay=vc4-kms-v3d"
    ]
    for marker in markers:
        idx = data.find(marker)
        if idx > 0:
            # Find start (previous newline or null)
            start = max(data.rfind(b'\n', max(0, idx - 200), idx),
                       data.rfind(b'\0', max(0, idx - 200), idx)) + 1
            # Find end (next null boundary or .dtb extension)
            end = data.find(b'\0\0', idx)
            if end > idx:
                # Trim trailing spaces
                end = max(data.rfind(b'\n', 0, end), data.rfind(b'\0', 0, end))
                if end > idx:
                    return start, end
            # Try finding end at next file marker
            dtb_idx = data.find(b'.dtb', idx, idx + 5000)
            if dtb_idx > idx:
                end = data.rfind(b'\n', idx, dtb_idx)
                if end > idx:
                    return start, end + 1
            return start, idx + 500
    return None, None


def find_cmdline_range(data):
    """Find cmdline.txt (single-line file starting with console=tty)."""
    idx = data.find(b"console=tty")
    if idx < 0:
        return None, None
    start = max(0, idx - 10)  # some margin before
    # cmdline is a single line, find end
    end = data.find(b'\n', idx)
    if end < 0:
        end = data.find(b'\0\0', idx)
    if end < 0:
        end = idx + 500
    return start, end


def modify_config(data):
    """Modify config.txt in boot partition data."""
    start, end = find_config_range(data)
    if start is None:
        print("  ⚠ Could not find config.txt")
        return False
    
    config_raw = data[start:end+1]
    config_text = config_raw.decode('utf-8', errors='replace') if isinstance(config_raw, (bytes, bytearray)) else config_raw
    
    # Parse lines
    lines = config_text.split('\n')
    new_lines = []
    for line in lines:
        stripped = line.strip()
        # Remove problematic lines
        if stripped.startswith('kernel_address='):
            continue
        if stripped.startswith('dtoverlay=vc4-fkms-v3d'):
            continue
        if stripped.startswith('arm_freq='):
            continue
        if stripped.startswith('gpu_freq='):
            continue
        if stripped.startswith('force_turbo='):
            continue
        new_lines.append(line)
    
    # Add YUNSH section
    new_lines.append('# === YUNSH OS Settings ===')
    new_lines.append('arm_64bit=1')
    new_lines.append('[pi5]')
    new_lines.append('dtoverlay=vc4-kms-v3d')
    new_lines.append('disable_splash=1')
    new_lines.append('framebuffer_width=1920')
    new_lines.append('framebuffer_height=1080')
    new_lines.append('framebuffer_depth=32')
    new_lines.append('disable_overscan=1')
    new_lines.append('[all]')
    new_lines.append('dtparam=i2c_arm=on')
    new_lines.append('')
    
    new_text = '\n'.join(new_lines)
    new_data = new_text.encode('utf-8')
    
    old_len = end - start + 1
    if len(new_data) > old_len:
        print(f"  ⚠ New config too large ({len(new_data)} > {old_len})")
        new_data = new_data[:old_len]
    elif len(new_data) < old_len:
        # Pad with spaces (harmless in config.txt)
        new_data = new_data.ljust(old_len, b' ')
    
    data[start:start + len(new_data)] = new_data
    print(f"  ✓ config.txt modified ({len(new_data)} bytes)")
    return True


def modify_cmdline(data):
    """Modify cmdline.txt."""
    start, end = find_cmdline_range(data)
    if start is None:
        print("  ⚠ Could not find cmdline.txt")
        return False
    
    old_text = bytes(data[start:end+1]).decode('utf-8', errors='replace').strip()
    
    # Remove unwanted flags
    for flag in ['quiet', 'logo.nologo', 'splash', 'consoleblank']:
        old_text = re.sub(r'\s+' + re.escape(flag) + r'(?:=[^\s]*)?', '', old_text)
    
    # Add our flags
    new_text = old_text + ' quiet logo.nologo consoleblank=0 cma=256M video=HDMI-A-1:1920x1080M@60'
    new_data = new_text.encode('utf-8')
    
    old_len = end - start + 1
    if len(new_data) > old_len:
        new_data = new_data[:old_len]
    elif len(new_data) < old_len:
        new_data = new_data.ljust(old_len, b' ')
    
    data[start:start + len(new_data)] = new_data
    print(f"  ✓ cmdline.txt modified")
    return True


def copy_files_to_boot(data, files):
    """Copy files into the boot partition by finding free FAT space."""
    # Find the first free directory entry
    dir_start = DATA_START
    dir_end = dir_start + CLUSTER_SIZE
    
    copied = []
    free_slot = None
    
    # Scan root directory for free slots
    for entry_off in range(dir_start, dir_end, 32):
        if data[entry_off] == 0 or data[entry_off] == 0xE5:
            free_slot = entry_off
            break
    
    if free_slot is None:
        print("  ⚠ No free directory entries")
        return copied
    
    # Find free clusters by scanning FAT
    free_clusters = []
    for cluster in range(2, 10000):
        entry_off = FAT_START + cluster * 4
        if entry_off + 4 > len(data):
            break
        fat_entry = struct.unpack_from('<I', data, entry_off)[0]
        if (fat_entry & 0x0FFFFFFF) == 0:
            free_clusters.append(cluster)
    
    print(f"  Free directory slots starting at: {free_slot}")
    print(f"  Free clusters available: {len(free_clusters)}")
    
    # Nothing to worry about — big FAT32 partition has tons of free space
    
    for src_path, dest_name in files:
        if not os.path.isfile(src_path):
            print(f"  ⚠ {dest_name}: source not found")
            continue
        
        with open(src_path, 'rb') as f:
            file_data = f.read()
        
        size = len(file_data)
        num_clusters = max(1, (size + CLUSTER_SIZE - 1) // CLUSTER_SIZE)
        
        if len(free_clusters) < num_clusters:
            print(f"  ⚠ {dest_name}: not enough free space (need {num_clusters} clusters)")
            continue
        
        allocated = free_clusters[:num_clusters]
        free_clusters = free_clusters[num_clusters:]
        
        # Write data to clusters
        clus_sector = DATA_START_SEC + (allocated[0] - 2) * SEC_PER_CLUSTER
        dest_off = clus_sector * BYTES_PER_SEC
        data[dest_off:dest_off + size] = file_data
        
        # Link clusters in FAT
        for i, c in enumerate(allocated):
            next_c = allocated[i + 1] if i < len(allocated) - 1 else 0x0FFFFFF8
            struct.pack_into('<I', data, FAT_START + c * 4, next_c)
            # Mirror to second FAT
            struct.pack_into('<I', data, SECOND_FAT_START + c * 4, next_c)
        
        # Write directory entry
        name_part = dest_name.upper()
        short_name = dest_name[:8].ljust(8, ' ')
        ext_part = ""
        if '.' in dest_name:
            base, ext_part = os.path.splitext(dest_name)
            short_name = base[:8].ljust(8, ' ')
            ext_part = ext_part.lstrip('.')[:3].ljust(3, ' ')
        
        entry = bytearray(32)
        entry[0:8] = short_name.encode('ascii', errors='replace')
        entry[8:11] = ext_part.encode('ascii', errors='replace')
        entry[11] = 0x20  # Archive attribute
        struct.pack_into('<H', entry, 26, allocated[0] & 0xFFFF)
        struct.pack_into('<H', entry, 20, (allocated[0] >> 16) & 0xFFFF)
        struct.pack_into('<I', entry, 28, size)
        # Date/time stamps
        struct.pack_into('<H', entry, 14, 0xAE92)
        struct.pack_into('<H', entry, 16, 0xAE92)
        struct.pack_into('<H', entry, 22, 0x4D21)
        struct.pack_into('<H', entry, 24, 0x4D21)
        
        data[free_slot:free_slot + 32] = bytes(entry)
        free_slot += 32
        
        copied.append(dest_name)
        print(f"  ✓ {dest_name} ({size} bytes, {num_clusters} clusters)")
    
    return copied


def main():
    print("=== YUNSH OS Boot Partition Modifier ===\n")
    
    if not os.path.exists(OUTPUT_IMG):
        # Need to create from base
        base = os.path.join(BUILD_DIR, "raspios-lite.img")
        if not os.path.exists(base):
            print(f"ERROR: Base image not found at {base}")
            sys.exit(1)
        print(f"Creating working copy from base...")
        shutil.copy2(base, OUTPUT_IMG)
        print(f"  ✓ {OUTPUT_IMG}")
    
    # Parse MBR
    boot_start, boot_size = parse_mbr(OUTPUT_IMG)
    print(f"Boot partition: sector {boot_start}, size {boot_size} ({boot_size * 512 / 1024 / 1024:.0f} MB)")
    
    # Extract boot partition
    print(f"\nExtracting boot partition...")
    data = extract_boot_partition(OUTPUT_IMG, boot_start, boot_size)
    print(f"  ✓ {len(data)} bytes")
    
    # Modify config.txt
    print(f"\nModifying config.txt...")
    modify_config(data)
    
    # Modify cmdline.txt
    print(f"\nModifying cmdline.txt...")
    modify_cmdline(data)
    
    # Copy YUNSH files
    print(f"\nCopying YUNSH boot files...")
    files = []
    for f in ["yunsh-firstboot.sh", "yunsh-iptables.sh", "yunsh-ssh-config.conf"]:
        path = os.path.join(YUNSH_DIR, "boot", f)
        if os.path.isfile(path):
            files.append((path, f))
    
    splash_dir = os.path.join(BUILD_DIR, "splash")
    if os.path.isdir(splash_dir):
        for f in sorted(os.listdir(splash_dir)):
            path = os.path.join(splash_dir, f)
            if os.path.isfile(path):
                files.append((path, f))
    
    copied = copy_files_to_boot(data, files)
    
    # Write boot partition back
    print(f"\nWriting boot partition back...")
    write_boot_partition(OUTPUT_IMG, boot_start, data)
    
    print(f"\n✅ Boot partition done — {len(copied)} files copied: {', '.join(copied)}")


if __name__ == "__main__":
    main()
