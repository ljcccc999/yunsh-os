#!/usr/bin/env python3
"""
YUNSH OS — Boot Partition Injector (No hdiutil/mount)
Modifies the FAT32 boot partition of the YUNSH OS image directly.
"""

import os, shutil, struct, sys

YUNSH_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BUILD_DIR = os.path.join(YUNSH_DIR, "build")
OUTPUT_DIR = os.path.join(YUNSH_DIR, "output")
OUTPUT_IMG = os.path.join(OUTPUT_DIR, "YUNSH-OS-v1.0.1.img")
BOOT_IMG = os.path.join(BUILD_DIR, "boot-partition.img")


def read_sectors(f, sector, count=1):
    f.seek(sector * 512)
    return f.read(count * 512)


def write_sectors(f, sector, data):
    f.seek(sector * 512)
    f.write(data)


def fat32_read_file(image_path, path):
    """Read a file from FAT32 partition by path."""
    with open(image_path, 'rb') as f:
        bs = read_sectors(f, 0)
        bpb = parse_bpb(bs)
        fat = read_fat(f, bpb)
        root_entries = read_directory(f, bpb, fat, bpb['root_cluster'])
        
        # Navigate path
        parts = path.strip('/').split('/')
        entries = root_entries
        
        for part in parts[:-1]:
            found = False
            for e in entries:
                if e['is_dir'] and e['short_name'].lower() == part.lower():
                    entries = read_directory(f, bpb, fat, e['cluster'])
                    found = True
                    break
            if not found:
                return None
        
        # Find file
        filename = parts[-1]
        for e in entries:
            if not e['is_dir'] and (e['short_name'].lower() == filename.lower() or 
                                     filename.lower() in e['long_name'].lower()):
                return read_cluster_chain(f, bpb, fat, e['cluster'], e['size'])
    
    return None


def parse_bpb(bs):
    """Parse FAT32 BIOS Parameter Block."""
    bytes_per_sec = struct.unpack_from('<H', bs, 11)[0]
    sec_per_cluster = bs[13]
    reserved_sec = struct.unpack_from('<H', bs, 14)[0]
    num_fats = bs[16]
    sec_per_fat = struct.unpack_from('<I', bs, 36)[0]
    root_cluster = struct.unpack_from('<I', bs, 44)[0]
    data_sec = reserved_sec + (num_fats * sec_per_fat)
    return {
        'bytes_per_sector': bytes_per_sec,
        'sectors_per_cluster': sec_per_cluster,
        'reserved_sectors': reserved_sec,
        'num_fats': num_fats,
        'sectors_per_fat': sec_per_fat,
        'root_cluster': root_cluster,
        'first_data_sector': data_sec,
    }


def read_fat(f, bpb):
    """Read the File Allocation Table."""
    fat_entries = []
    for i in range(bpb['sectors_per_fat']):
        sector_data = read_sectors(f, bpb['reserved_sectors'] + i)
        for j in range(0, 512, 4):
            entry = struct.unpack_from('<I', sector_data, j)[0]
            fat_entries.append(entry)
    return fat_entries


def cluster_to_sector(bpb, cluster):
    """Convert cluster number to sector number."""
    return ((cluster - 2) * bpb['sectors_per_cluster']) + bpb['first_data_sector']


def parse_short_name(entry):
    """Parse 8.3 short name from directory entry."""
    name = entry[0:8].decode('ascii', errors='replace').rstrip()
    ext = entry[8:11].decode('ascii', errors='replace').rstrip()
    return f"{name}.{ext}" if ext else name


def parse_long_name(entries, idx):
    """Parse long filename entries."""
    name_chars = []
    for i in range(idx, -1, -1):
        e = entries[i]['raw']
        if e[11] & 0x0F != 0x0F:
            break
        # Extract characters from long name entry
        for offset in [1, 3, 5, 7, 9, 0x0E, 0x10, 0x12, 0x14, 0x16, 0x18, 0x1C, 0x1E]:
            if offset < 32:
                c = struct.unpack_from('<H', e, offset)[0]
                if c != 0xFFFF and c != 0:
                    name_chars.append(chr(c))
    return ''.join(reversed(name_chars)).rstrip('\0').rstrip()


def read_directory(f, bpb, fat, cluster):
    """Read a directory from a given cluster."""
    entries = []
    while cluster < 0x0FFFFFF8 and cluster > 1:
        sector = cluster_to_sector(bpb, cluster)
        for s in range(bpb['sectors_per_cluster']):
            data = read_sectors(f, sector + s)
            i = 0
            while i < 512:
                entry = data[i:i+32]
                if len(entry) < 32:
                    break
                if entry[0] == 0:
                    # No more entries
                    return entries
                if entry[0] == 0xE5:
                    i += 32
                    continue
                attr = entry[11]
                long_name = ""
                if attr & 0x0F == 0x0F:
                    i += 32
                    continue
                
                name = parse_short_name(entry)
                is_dir = (attr & 0x10) != 0
                size = struct.unpack_from('<I', entry, 28)[0]
                
                if entry[0] != 0x2E:  # skip . and ..
                    lfn_entries = []
                    cluster_low = struct.unpack_from('<H', entry, 26)[0]
                    cluster_high = struct.unpack_from('<H', entry, 20)[0]
                    ent_cluster = (cluster_high << 16) | cluster_low
                    
                    entries.append({
                        'short_name': name,
                        'is_dir': is_dir,
                        'size': size,
                        'cluster': ent_cluster,
                        'raw': entry,
                        'attr': attr,
                    })
                i += 32
        cluster = fat[cluster]
    return entries


def find_empty_cluster(fat, bpb, start=2):
    """Find a free cluster in FAT."""
    for i in range(start, len(fat)):
        if fat[i] == 0:
            return i
    return None


def alloc_cluster_chain(fat, bpb, num_clusters, image_path):
    """Allocate a chain of clusters and return the start cluster."""
    with open(image_path, 'r+b') as f:
        fat_sec = bpb['reserved_sectors']
        
        clusters = []
        for i in range(num_clusters):
            c = find_empty_cluster(fat, bpb, start=(clusters[-1] + 1 if clusters else 2))
            if c is None:
                raise RuntimeError("No free clusters")
            clusters.append(c)
        
        # Link clusters
        for i in range(len(clusters) - 1):
            set_fat_entry(f, fat_sec, clusters[i], clusters[i+1])
        # Last cluster gets EOC
        set_fat_entry(f, fat_sec, clusters[-1], 0x0FFFFFF8)
        
        # Mirror to second FAT
        for i in range(len(clusters)):
            c = clusters[i]
            next_c = clusters[i+1] if i < len(clusters) - 1 else 0x0FFFFFF8
            set_fat_entry(f, fat_sec + bpb['sectors_per_fat'], c, next_c)
        
        return clusters[0]


def set_fat_entry(f, fat_start_sector, cluster, value):
    """Set a FAT entry value."""
    fat_offset = cluster * 4
    fat_sec = fat_start_sector + (fat_offset // 512)
    sec_offset = fat_offset % 512
    data = bytearray(read_sectors(f, fat_sec))
    struct.pack_into('<I', data, sec_offset, value)
    write_sectors(f, fat_sec, bytes(data))


def read_cluster_chain(f, bpb, fat, start_cluster, size):
    """Read all data from a cluster chain."""
    data = b""
    cluster = start_cluster
    while cluster < 0x0FFFFFF8 and cluster > 1 and len(data) < size:
        sector = cluster_to_sector(bpb, cluster)
        for s in range(bpb['sectors_per_cluster']):
            data += read_sectors(f, sector + s, 1)
        cluster = fat[cluster]
    return data[:size]


def write_to_cluster(f, bpb, start_cluster, data):
    """Write data starting at a cluster chain."""
    cluster = start_cluster
    offset = 0
    while cluster < 0x0FFFFFF8 and cluster > 1 and offset < len(data):
        sector = cluster_to_sector(bpb, cluster)
        for s in range(bpb['sectors_per_cluster']):
            chunk = data[offset:offset + bpb['bytes_per_sector']]
            if chunk:
                write_sectors(f, sector + s, chunk.ljust(bpb['bytes_per_sector'], b'\0'))
                offset += len(chunk)
            else:
                break
            if offset >= len(data):
                break
        cluster = None  # We only write to pre-allocated clusters


def fat32_write_file(image_path, dest_path, src_data):
    """Write a file into the FAT32 partition."""
    with open(image_path, 'r+b') as f:
        bs = read_sectors(f, 0)
        bpb = parse_bpb(bs)
        fat = read_fat(f, bpb)
        root_entries = read_directory(f, bpb, fat, bpb['root_cluster'])
        
        # Find a free directory entry in root
        free_entry_sector = None
        free_entry_offset = None
        
        # First find the end of the directory
        dir_sector = cluster_to_sector(bpb, bpb['root_cluster'])
        for s in range(bpb['sectors_per_cluster']):
            data = read_sectors(f, dir_sector + s)
            for i in range(0, 512, 32):
                if data[i] == 0 or data[i] == 0xE5:
                    free_entry_sector = dir_sector + s
                    free_entry_offset = i
                    break
            if free_entry_sector:
                break
        
        if free_entry_sector is None:
            print("  No free directory entry found")
            return False
        
        # Allocate clusters
        num_clusters = (len(src_data) + (bpb['bytes_per_sector'] * bpb['sectors_per_cluster']) - 1) // (bpb['bytes_per_sector'] * bpb['sectors_per_cluster'])
        if num_clusters == 0:
            num_clusters = 1
        
        fat_copy = fat[:]
        start_cluster = alloc_cluster_chain(fat_copy, bpb, num_clusters, image_path)
        
        # Write file data
        write_to_cluster(f, bpb, start_cluster, src_data)
        
        # Write directory entry
        dest_basename = os.path.basename(dest_path).upper()
        short_name = dest_basename[:8].ljust(8) + dest_basename[8:11].ljust(3)
        if len(short_name) > 11:
            short_name = dest_basename[:6].upper() + "~1" + dest_basename[-4:].upper()
            short_name = short_name.ljust(11, ' ')
        
        entry_data = bytearray(32)
        entry_data[0:8] = short_name[:8].encode('ascii', errors='replace')
        entry_data[8:11] = short_name[8:11].encode('ascii', errors='replace')
        entry_data[11] = 0x20  # Archive attribute
        struct.pack_into('<H', entry_data, 26, start_cluster & 0xFFFF)
        struct.pack_into('<H', entry_data, 20, (start_cluster >> 16) & 0xFFFF)
        struct.pack_into('<I', entry_data, 28, len(src_data))
        
        current_data = bytearray(read_sectors(f, free_entry_sector))
        current_data[free_entry_offset:free_entry_offset + 32] = entry_data
        write_sectors(f, free_entry_sector, bytes(current_data))
    
    return True


def main():
    print("=== YUNSH OS Boot Partition Injector ===")
    
    if not os.path.exists(BOOT_IMG):
        print(f"ERROR: Boot partition image not found: {BOOT_IMG}")
        sys.exit(1)
    
    if not os.path.exists(OUTPUT_IMG):
        print(f"ERROR: Output image not found: {OUTPUT_IMG}")
        sys.exit(1)
    
    # Parse partition layout from output image
    print("Parsing partition layout...")
    with open(OUTPUT_IMG, 'rb') as f:
        mbr = read_sectors(f, 0)
        # Partition 1: boot (type 0xC or 0xE FAT)
        boot_start = struct.unpack_from('<I', mbr, 454)[0]  # partition 1 start sector
        boot_size = struct.unpack_from('<I', mbr, 458)[0]    # partition 1 size in sectors
        print(f"  Boot partition: sector {boot_start}, size {boot_size} sectors")
    
    # Extract boot partition
    print(f"\nExtracting boot partition to {BOOT_IMG}...")
    with open(OUTPUT_IMG, 'rb') as f_in, open(BOOT_IMG, 'wb') as f_out:
        f_in.seek(boot_start * 512)
        remaining = boot_size * 512
        while remaining > 0:
            chunk = f_in.read(min(remaining, 4 * 1024 * 1024))
            if not chunk:
                break
            f_out.write(chunk)
            remaining -= len(chunk)
    print(f"  Extracted: {boot_size * 512} bytes")
    
    # Read config.txt
    try:
        config_data = fat32_read_file(BOOT_IMG, "/config.txt")
        if config_data:
            config_text = config_data.decode('utf-8', errors='replace')
            print(f"\nCurrent config.txt ({len(config_data)} bytes):")
            for line in config_text.split('\n')[:10]:
                print(f"  {line}")
            
            # Modify config
            import re
            config_text = re.sub(r'^kernel_address=.*\n?', '', config_text, flags=re.MULTILINE)
            config_text = re.sub(r'^dtoverlay=vc4-fkms-v3d.*\n?', '', config_text, flags=re.MULTILINE)
            config_text = re.sub(r'^arm_freq=.*\n?', '', config_text, flags=re.MULTILINE)
            config_text = re.sub(r'^gpu_freq=.*\n?', '', config_text, flags=re.MULTILINE)
            config_text = re.sub(r'^force_turbo=.*\n?', '', config_text, flags=re.MULTILINE)
            
            # Add YUNSH config
            config_text += "\n# === YUNSH OS Settings ===\n"
            config_text += "arm_64bit=1\n"
            config_text += "[pi5]\ndtoverlay=vc4-kms-v3d\ndisable_splash=1\n"
            config_text += "framebuffer_width=1920\nframebuffer_height=1080\n"
            config_text += "framebuffer_depth=32\ndisable_overscan=1\n"
            config_text += "[all]\ndtparam=i2c_arm=on\n"
            
            print(f"\nWriting modified config.txt ({len(config_text)} bytes)...")
            if fat32_write_file(BOOT_IMG, "/config.txt", config_text.encode('utf-8')):
                print("  ✓ config.txt updated")
            else:
                print("  ⚠ Failed to write config.txt")
        else:
            print("  ⚠ config.txt not found")
    except Exception as e:
        print(f"  ⚠ Error modifying config.txt: {e}")
    
    # Copy YUNSH boot files
    boot_files = [
        ("yunsh-firstboot.sh", "yunsh-firstboot.sh"),
        ("yunsh-iptables.sh", "yunsh-iptables.sh"),
        ("yunsh-ssh-config.conf", "yunsh-ssh-config.conf"),
    ]
    
    # Splash files
    splash_dir = os.path.join(BUILD_DIR, "splash")
    if os.path.isdir(splash_dir):
        for f in os.listdir(splash_dir):
            boot_files.append((os.path.join("..", "build", "splash", f), f))
    
    print(f"\nCopying YUNSH boot files...")
    for src_rel, dest_name in boot_files:
        src_path = os.path.join(YUNSH_DIR, src_rel) if not src_rel.startswith('/') else src_rel
        src_path = os.path.normpath(src_path)
        if os.path.isfile(src_path):
            with open(src_path, 'rb') as f:
                data = f.read()
            print(f"  Copying {dest_name} ({len(data)} bytes)...")
            try:
                if fat32_write_file(BOOT_IMG, f"/{dest_name}", data):
                    print(f"    ✓ {dest_name}")
                else:
                    print(f"    ⚠ Failed to copy {dest_name}")
            except Exception as e:
                print(f"    ⚠ Error: {e}")
        else:
            print(f"  ⚠ {dest_name} not found (expected: {src_path})")
    
    # Write boot partition back to output image
    print(f"\nWriting boot partition back to output image...")
    with open(BOOT_IMG, 'rb') as f_in, open(OUTPUT_IMG, 'r+b') as f_out:
        f_out.seek(boot_start * 512)
        remaining = boot_size * 512
        while remaining > 0:
            chunk = f_in.read(min(remaining, 4 * 1024 * 1024))
            if not chunk:
                break
            f_out.write(chunk)
            remaining -= len(chunk)
    print(f"  ✓ Boot partition written back")
    
    print(f"\n✅ Boot partition injection complete")


if __name__ == "__main__":
    main()
