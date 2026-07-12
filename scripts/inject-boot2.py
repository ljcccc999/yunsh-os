#!/usr/bin/env python3
"""
YUNSH OS — Boot Partition Modifier v2
Properly handles FAT32 directory entry size updates.
"""
import os, struct, shutil

YUNSH_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BUILD_DIR = os.path.join(YUNSH_DIR, "build")
OUTPUT_DIR = os.path.join(YUNSH_DIR, "output")
OUTPUT_IMG = os.path.join(OUTPUT_DIR, "YUNSH-OS-v1.0.1.img")

# Read base image to find boot partition
with open(OUTPUT_IMG, "rb") as f:
    mbr = f.read(512)

boot_lba = struct.unpack_from("<I", mbr, 454)[0]
boot_sectors = struct.unpack_from("<I", mbr, 458)[0]
BOOT_OFF = boot_lba * 512
BOOT_SIZE = boot_sectors * 512

print(f"Boot partition: LBA {boot_lba}, size {BOOT_SIZE} bytes ({BOOT_SIZE//1024//1024} MB)")

# Read full boot partition
with open(OUTPUT_IMG, "rb") as f:
    f.seek(BOOT_OFF)
    boot = f.read(BOOT_SIZE)
    img_data = bytearray(boot)

def find_file_in_fat32(data, filename_8_3):
    """Find a FAT32 file entry and return (offset, cluster, size) or None."""
    # Parse FAT32 BPB
    bytes_per_sec = struct.unpack_from("<H", data, 11)[0]
    sec_per_cluster = data[13]
    reserved_sec = struct.unpack_from("<H", data, 14)[0]
    num_fats = data[16]
    sec_per_fat = struct.unpack_from("<I", data, 36)[0]
    root_cluster = struct.unpack_from("<I", data, 44)[0]
    
    FAT_OFF = reserved_sec * bytes_per_sec
    DATA_OFF = (reserved_sec + num_fats * sec_per_fat) * bytes_per_sec
    CLUSTER_SIZE = sec_per_cluster * bytes_per_sec
    
    # Read FAT to follow root directory cluster chain
    def read_fat_entry(cluster):
        fat_entry_off = FAT_OFF + cluster * 4
        return struct.unpack_from("<I", data, fat_entry_off)[0] & 0x0FFFFFFF
    
    # Read a cluster
    def read_cluster(cluster):
        if cluster < 2:
            return None
        cluster_off = DATA_OFF + (cluster - 2) * CLUSTER_SIZE
        if cluster_off + CLUSTER_SIZE > len(data):
            return None
        return data[cluster_off:cluster_off + CLUSTER_SIZE]
    
    # Follow root directory
    cluster = root_cluster
    name_upper = filename_8_3.upper()
    
    while 2 <= cluster < 0x0FFFFFF8:
        cluster_data = read_cluster(cluster)
        if cluster_data is None:
            break
        
        for entry_off in range(0, len(cluster_data), 32):
            entry = cluster_data[entry_off:entry_off + 32]
            if entry[0] == 0:
                break  # End of directory
            if entry[0] == 0xE5:
                continue  # Deleted entry
            if entry[11] & 0x0F == 0x0F:
                continue  # Long file name entry
            
            # Check 8.3 name
            name = entry[0:8].decode('ascii', errors='replace').rstrip()
            ext = entry[8:11].decode('ascii', errors='replace').rstrip()
            full_name = (name + '.' + ext).upper() if ext else name.upper()
            
            if full_name == name_upper:
                entry_abs_off = DATA_OFF + (cluster - 2) * CLUSTER_SIZE + entry_off
                file_size = struct.unpack_from("<I", entry, 28)[0]
                cluster_hi = struct.unpack_from("<H", entry, 20)[0]
                cluster_lo = struct.unpack_from("<H", entry, 26)[0]
                file_cluster = (cluster_hi << 16) | cluster_lo
                file_data_off = DATA_OFF + (file_cluster - 2) * CLUSTER_SIZE
                return (entry_abs_off, file_cluster, file_size, file_data_off)
        
        cluster = read_fat_entry(cluster)
    
    return None

def write_file_content(data, file_info, new_content):
    """Write file content, updating the FAT entry size."""
    entry_off, cluster, old_size, data_off = file_info
    
    # Read current directory entry to get old size
    old_size_from_entry = struct.unpack_from("<I", data, entry_off + 28)[0]
    new_size = len(new_content)
    
    print(f"  Old entry size: {old_size_from_entry}, actual content to write: {new_size}")
    
    # Update size in directory entry
    struct.pack_into("<I", data, entry_off + 28, new_size)
    
    # Update time stamps
    struct.pack_into("<H", data, entry_off + 14, 0xAE92)  # date
    struct.pack_into("<H", data, entry_off + 22, 0x4D21)  # time
    
    # Write the new content
    data[data_off:data_off + new_size] = new_content[:]
    
    # Pad with spaces if new content is shorter
    if new_size < old_size:
        data[data_off + new_size:data_off + old_size] = b' ' * (old_size - new_size)
        print(f"  Padded {old_size - new_size} bytes with spaces")
    
    return True

# ─── Read current config.txt ────────────────────
print("\nSearching for config.txt in FAT32...")
result = find_file_in_fat32(img_data, "CONFIG.TXT")
if result:
    entry_off, cluster, size, data_off = result
    print(f"  Found at cluster {cluster}, size={size}, data offset=0x{data_off:x}")
    
    # Read current content
    current = bytes(img_data[data_off:data_off + size])
    print(f"  Current content ({len(current)} bytes):")
    print(current.decode('ascii', errors='replace'))
    
    # ─── Generate new config.txt ─────────────────
    new_config = b"""# YUNSH OS - v1.0.1
# Raspberry Pi 5 config

# Enable 64-bit mode
arm_64bit=1

# VideoCore: enable KMS (not FKMS)
dtoverlay=vc4-kms-v3d
# gpu_mem split: 256MB for Pi 5
gpu_mem=256
gpu_mem_256=128

# Disable rainbow splash
disable_splash=1

# Enable I2C (for IMU/BNO085)
dtparam=i2c_arm=on
dtparam=i2c_vc=on

# Boot HDMI output
hdmi_force_hotplug=1
hdmi_group=2
hdmi_mode=82

# Auto detection
display_auto_detect=1
dtparam=audio=on

# Boot order: try SD card first, then USB
boot_order=0xf41

# Disable Bluetooth (not needed on Pi 5 AR)
dtoverlay=disable-bt
"""
    
    print(f"\n  New config.txt ({len(new_config)} bytes):")
    print(new_config.decode())
    
    # Write new config
    if len(new_config) <= size:
        print("  Fits within original size ✓")
        write_file_content(img_data, result, new_config)
    else:
        # Try to expand by reusing the full cluster
        cluster_size = struct.unpack_from("<H", img_data, 11)[0]  # bytes per sector
        sec_per_cluster = img_data[13]
        cluster_size = cluster_size * sec_per_cluster
        
        if len(new_config) <= cluster_size:
            print(f"  Need {len(new_config)} bytes, cluster is {cluster_size} bytes ✓")
            write_file_content(img_data, result, new_config)
        else:
            print(f"  ⚠ config.txt ({len(new_config)} bytes) > cluster size ({cluster_size})")
            print("  Truncating to cluster size")
            write_file_content(img_data, result, new_config[:cluster_size])
else:
    print("  WARNING: config.txt not found!")

# ─── Read/modify cmdline.txt ───────────────────
print("\nSearching for cmdline.txt...")
result = find_file_in_fat32(img_data, "CMDLINE.TXT")
if result:
    entry_off, cluster, size, data_off = result
    current = bytes(img_data[data_off:data_off + size])
    print(f"  Current: {current.decode('ascii', errors='replace')[:100]}...")
    
    new = current.replace(b"console=serial0,115200", b"console=tty1")
    if b"consoleblank" not in new:
        new = new.rstrip() + b" consoleblank=0 logo.nologo vt.global_cursor_default=0"
    if b"quiet" not in new:
        new = new.rstrip() + b" quiet"
    
    print(f"  New cmdline ({len(new)} bytes)")
    write_file_content(img_data, result, new)
else:
    print("  WARNING: cmdline.txt not found!")

# ─── Copy YUNSH boot files ──────────────────────
print("\nCopying YUNSH boot files...")

# Find free directory slots in root
bytes_per_sec = struct.unpack_from("<H", img_data, 11)[0]
sec_per_cluster = img_data[13]
reserved_sec = struct.unpack_from("<H", img_data, 14)[0]
num_fats = img_data[16]
sec_per_fat = struct.unpack_from("<I", img_data, 36)[0]
DATA_OFF2 = (reserved_sec + num_fats * sec_per_fat) * bytes_per_sec
CLUSTER_SIZE2 = sec_per_cluster * bytes_per_sec

# Find first empty slot in root dir
root_cluster = struct.unpack_from("<I", img_data, 44)[0]
def read_fat_entry2(cluster):
    fat_off = reserved_sec * bytes_per_sec
    return struct.unpack_from("<I", img_data, fat_off + cluster * 4)[0] & 0x0FFFFFFF

# Count files already present
cluster = root_cluster
all_names = []
while 2 <= cluster < 0x0FFFFFF8:
    clus_off = DATA_OFF2 + (cluster - 2) * CLUSTER_SIZE2
    clus_data = img_data[clus_off:clus_off + CLUSTER_SIZE2]
    for off in range(0, len(clus_data), 32):
        if clus_data[off] == 0:
            break
        if clus_data[off] == 0xE5:
            continue
        if clus_data[off+11] & 0x0F == 0x0F:
            continue
        name = clus_data[off:off+8].decode('ascii', errors='replace').rstrip()
        ext = clus_data[off+8:off+11].decode('ascii', errors='replace').rstrip()
        all_names.append(name + '.' + ext if ext else name)
    cluster = read_fat_entry2(cluster)

print(f"  Root dir has {len(all_names)} entries")

# Find free clusters
FREE_OFF = reserved_sec * bytes_per_sec
free_clusters = []
for c in range(2, min(read_fat_entry2(2) + 1000, 100000)):
    entry = struct.unpack_from("<I", img_data, FREE_OFF + c * 4)[0] & 0x0FFFFFFF
    if entry == 0:
        free_clusters.append(c)

print(f"  Free clusters available: {len(free_clusters)}")

# Files to copy
files_to_copy = [
    ("yunsh-firstboot.sh", os.path.join(YUNSH_DIR, "boot", "yunsh-firstboot.sh")),
    ("yunsh-iptables.sh", os.path.join(YUNSH_DIR, "boot", "yunsh-iptables.sh")),
]

# Create directory entries
dir_off = DATA_OFF2  # Start of root dir
# Find end of existing directory
for off in range(0, 8192, 32):  # Scan up to 8192 bytes
    if img_data[dir_off + off] == 0:
        next_free_slot = dir_off + off
        break
else:
    next_free_slot = dir_off + len(all_names) * 32

print(f"  Free slot at offset 0x{next_free_slot:x}")

cluster_idx = 0
for name_83, src_path in files_to_copy:
    if not os.path.exists(src_path):
        print(f"  ⚠ {src_path} not found, skipping")
        continue
    
    with open(src_path, "rb") as f:
        content = f.read()
    
    clusters_needed = (len(content) + CLUSTER_SIZE2 - 1) // CLUSTER_SIZE2
    
    if cluster_idx + clusters_needed > len(free_clusters):
        print(f"  ⚠ Not enough free clusters for {name_83}")
        continue
    
    first_cluster = free_clusters[cluster_idx]
    
    # Mark clusters as used in FAT
    for i in range(clusters_needed):
        c = free_clusters[cluster_idx + i]
        next_c = free_clusters[cluster_idx + i + 1] if i + 1 < clusters_needed else 0x0FFFFFFF
        struct.pack_into("<I", img_data, FREE_OFF + c * 4, next_c)
    
    cluster_idx += clusters_needed
    
    # Write content
    content_off = DATA_OFF2 + (first_cluster - 2) * CLUSTER_SIZE2
    img_data[content_off:content_off + len(content)] = content[:]
    
    # Create directory entry
    name_parts = name_83.rsplit(".", 1)
    name_bytes = name_parts[0].ljust(8).encode('ascii')[:8]
    ext_bytes = name_parts[1].ljust(3).encode('ascii')[:3] if len(name_parts) > 1 else b'   '
    
    entry = bytearray(32)
    entry[0:8] = name_bytes
    entry[8:11] = ext_bytes
    entry[11] = 0x20  # Archive
    entry[12:22] = b'\x00' * 10  # Reserved/creatime/credate
    struct.pack_into("<H", entry, 22, 0x4D21)  # Time
    struct.pack_into("<H", entry, 24, 0xAE92)  # Date
    struct.pack_into("<H", entry, 20, first_cluster >> 16)  # Cluster high
    struct.pack_into("<H", entry, 26, first_cluster & 0xFFFF)  # Cluster low
    struct.pack_into("<I", entry, 28, len(content))  # File size
    
    img_data[next_free_slot:next_free_slot + 32] = entry
    next_free_slot += 32
    
    size_str = f"{len(content)} bytes, {clusters_needed} clusters"
    print(f"  ✓ {name_83} ({size_str})")

# ─── Write boot partition back ─────────────────
print(f"\nWriting boot partition back...")
with open(OUTPUT_IMG, "r+b") as f:
    f.seek(BOOT_OFF)
    f.write(bytes(img_data))
    
print("✅ Boot partition updated successfully!")
print(f"  Written {len(img_data)} bytes")
