#!/usr/bin/env python3
"""
Fix config.txt in boot partition — proper FAT32 file size update.
Needs the correct Python FAT32 file update with directory entry size update.
"""

import os, sys, struct

YUNSH_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BOOT_IMG = os.path.join(YUNSH_DIR, "build", "boot-partition.img")

FAT_START = 32 * 512
SECOND_FAT_START = FAT_START + 8066 * 512
DATA_START = (32 + 2 * 8066) * 512

config_new = """# YUNSH OS v1.0 - Raspberry Pi Boot Config
# 1080p output for AR glasses, black=transparent

# GPU memory
gpu_mem=256

# Force 1080p output
hdmi_group=2
hdmi_mode=82
hdmi_pixel_freq_limit=400000000
hdmi_drive=2
hdmi_force_hotplug=1
hdmi_ignore_edid=0xa5000080
hdmi_timings=1920 0 44 8 200 1080 0 4 4 6 0 0 1 60 0 165000000

# Display settings
disable_overscan=1
framebuffer_width=1920
framebuffer_height=1080
framebuffer_depth=32
framebuffer_ignore_alpha=0

# Enable 64-bit kernel
arm_64bit=1

# GPU — only vc4-kms-v3d (no FKMS — conflicts on Pi 5)
dtoverlay=vc4-kms-v3d
max_framebuffers=2

# Serial console for debugging
enable_uart=1

# Audio
dtparam=audio=on

# USB
dtoverlay=dwc2,dr_mode=host

# YUNSH OS additions
[pi5]
dtoverlay=vc4-kms-v3d
disable_splash=1
framebuffer_width=1920
framebuffer_height=1080
framebuffer_depth=32
disable_overscan=1

[all]
dtparam=i2c_arm=on
"""

print("=== Fixing config.txt ===")
print(f"New config size: {len(config_new)} bytes")

with open(BOOT_IMG, 'r+b') as f:
    data = bytearray(f.read())
    
    # Find directory entry for config.txt
    dir_start = DATA_START
    dir_end = dir_start + 512
    
    found_entry = None
    for i in range(dir_start, dir_end, 32):
        entry = data[i:i+32]
        if entry[0] == 0:
            break
        if entry[0] == 0xE5:
            continue
        if entry[11] & 0x0F == 0x0F:
            continue
        if entry[11] & 0x10:
            continue
        
        name = entry[0:8].decode('ascii', errors='replace').rstrip()
        ext = entry[8:11].decode('ascii', errors='replace').rstrip()
        if name.upper() == 'CONFIG' and ext.upper() == 'TXT':
            found_entry = (i, entry)
            break
    
    if found_entry is None:
        print("ERROR: config.txt directory entry not found")
        sys.exit(1)
    
    entry_offset, orig_entry = found_entry
    orig_size = struct.unpack_from('<I', orig_entry, 28)[0]
    clus_low = struct.unpack_from('<H', orig_entry, 26)[0]
    clus_high = struct.unpack_from('<H', orig_entry, 20)[0]
    start_cluster = (clus_high << 16) | clus_low
    
    print(f"  Found: cluster={start_cluster}, original size={orig_size} bytes")
    
    # Read current content
    cluster = start_cluster
    content = bytearray()
    while cluster >= 2 and cluster < 0x0FFFFFF8:
        offset = DATA_START + (cluster - 2) * 512
        content.extend(data[offset:offset+512])
        fat_entry = struct.unpack_from('<I', data, FAT_START + cluster * 4)[0]
        cluster = fat_entry & 0x0FFFFFFF
        if cluster >= 0x0FFFFFF0:
            break
    
    content = bytes(content[:orig_size])
    print(f"  Current config ({len(content)} bytes):")
    for line in content.decode('utf-8', errors='replace').split('\n')[:5]:
        print(f"    {line}")
    print(f"    ...")
    
    # Check if new config fits in allocated clusters
    alloc_size = (orig_size + 511) // 512 * 512
    new_size_needed = (len(config_new) + 511) // 512 * 512
    
    if new_size_needed > alloc_size:
        print(f"  ⚠ Need {new_size_needed} bytes but only {alloc_size} allocated")
        print(f"  Attempting to allocate more clusters...")
        
        # Count existing chain
        cluster_count = 1
        c = start_cluster
        while True:
            fat_e = struct.unpack_from('<I', data, FAT_START + c * 4)[0] & 0x0FFFFFFF
            if fat_e >= 0x0FFFFFF0:
                break
            c = fat_e
            cluster_count += 1
        
        alloc_avail = cluster_count * 512
        if alloc_avail >= len(config_new):
            # Just need to extend the cluster chain (it's already allocated)
            print(f"  Existing cluster chain large enough ({alloc_avail} bytes)")
            # Mark last cluster with more clusters if needed
        else:
            print(f"  ⚠ Boot partition too small for new config")
            sys.exit(1)
    
    # Write new config
    cluster = start_cluster
    remaining = len(config_new.encode('utf-8'))
    config_bytes = config_new.encode('utf-8')
    
    while remaining > 0:
        offset = DATA_START + (cluster - 2) * 512
        chunk = config_bytes[cluster * 512 - start_cluster * 512:cluster * 512 - start_cluster * 512 + 512]
        chunk = min(chunk, bytes)
        data[offset:offset + len(chunk)] = chunk
        remaining -= len(chunk)
        
        fat_e = struct.unpack_from('<I', data, FAT_START + cluster * 4)[0] & 0x0FFFFFFF
        if fat_e >= 0x0FFFFFF0:
            break
        cluster = fat_e
    
    # Update directory entry size
    struct.pack_into('<I', data, entry_offset + 28, len(config_bytes))
    # Update write time
    struct.pack_into('<H', data, entry_offset + 14, 0xAE92)  # time
    struct.pack_into('<H', data, entry_offset + 16, 0xAE92)  # access time
    struct.pack_into('<H', data, entry_offset + 22, 0x4D21)  # date
    struct.pack_into('<H', data, entry_offset + 24, 0x4D21)  # modify date
    
    # Write back
    f.seek(0)
    f.write(bytes(data))

print("  ✓ config.txt properly updated with correct FAT entry")
