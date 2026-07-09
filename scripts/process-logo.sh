#!/bin/bash
# YUNSH OS v1.0 - Logo Processing Script
# Converts source logo to multiple sizes for system use

set -e

LOGO_SOURCE="${1:-/mnt/agents/upload/2D2E86CD-E398-4E31-B667-B3DBDB8DEA6D.jpg}"
OUTPUT_DIR="${2:-/Users/tim/.openclaw/workspace/yunsh-os/logo}"

echo "=== YUNSH: Processing Logo ==="

# Check if source exists
if [ ! -f "${LOGO_SOURCE}" ]; then
    echo "WARNING: Source logo not found at ${LOGO_SOURCE}"
    echo "Creating placeholder logo instead..."
    # Generate a simple placeholder logo using ImageMagick or Python
    if command -v convert &>/dev/null; then
        # Create colored square with "Y" text as placeholder
        for size in 32 64 128 256 512; do
            convert -size "${size}x${size}" \
                -background '#00D4FF' -fill '#FFFFFF' \
                -gravity center -pointsize $((size/2)) \
                label:"Y" \
                "${OUTPUT_DIR}/logo-${size}.png"
        done
    else
        # Minimal Python fallback
        python3 -c "
from PIL import Image, ImageDraw, ImageFont
import os

os.makedirs('${OUTPUT_DIR}', exist_ok=True)

for size in [32, 64, 128, 256, 512]:
    img = Image.new('RGBA', (size, size), (0, 212, 255, 255))
    draw = ImageDraw.Draw(img)
    
    # Draw a simple 'Y' shape
    cx, cy = size//2, size//2
    r = size // 3
    
    draw.ellipse([cx-r, cy-r, cx+r, cy+r], fill=(0, 170, 220, 255))
    draw.ellipse([cx-r//2, cy-r//2, cx+r//2, cy+r//2], fill=(0, 212, 255, 255))
    draw.ellipse([cx-2, cy-2, cx+2, cy+2], fill=(255, 255, 255, 255))
    
    img.save(os.path.join('${OUTPUT_DIR}', f'logo-{size}.png'))
    print(f'Created logo-{size}.png')
" 2>/dev/null || echo "Install Pillow: pip3 install Pillow"
    fi
    echo "Placeholder logo created"
    exit 0
fi

echo "Processing: ${LOGO_SOURCE}"

# Install ImageMagick if needed for conversion
if command -v convert &>/dev/null; then
    # Convert to PNG with transparent background
    convert "${LOGO_SOURCE}" \
        -strip \
        -background none \
        -gravity center \
        -extent 100%x100% \
        "${OUTPUT_DIR}/logo-full.png"
    
    # Generate resized versions
    for size in 32 64 128 256 512; do
        convert "${OUTPUT_DIR}/logo-full.png" \
            -resize "${size}x${size}" \
            -gravity center \
            -background none \
            -extent "${size}x${size}" \
            "${OUTPUT_DIR}/logo-${size}.png"
        echo "  Created: logo-${size}.png"
    done
    
    # Copy to overlay
    mkdir -p "${OUTPUT_DIR}/../br2-overlay/usr/share/yunsh/logo"
    cp "${OUTPUT_DIR}/logo-32.png" "${OUTPUT_DIR}/../br2-overlay/usr/share/yunsh/logo/"
    cp "${OUTPUT_DIR}/logo-64.png" "${OUTPUT_DIR}/../br2-overlay/usr/share/yunsh/logo/"
    cp "${OUTPUT_DIR}/logo-128.png" "${OUTPUT_DIR}/../br2-overlay/usr/share/yunsh/logo/"
    cp "${OUTPUT_DIR}/logo-256.png" "${OUTPUT_DIR}/../br2-overlay/usr/share/yunsh/logo/"
    cp "${OUTPUT_DIR}/logo-512.png" "${OUTPUT_DIR}/../br2-overlay/usr/share/yunsh/logo/"
    
    # Also to pixmaps for general use
    cp "${OUTPUT_DIR}/logo-256.png" "${OUTPUT_DIR}/../br2-overlay/usr/share/pixmaps/yunsh-logo.png"
    cp "${OUTPUT_DIR}/logo-32.png" "${OUTPUT_DIR}/../br2-overlay/usr/share/pixmaps/yunsh-icon.png"
    
    echo "Logo processing complete!"
else
    echo "WARNING: ImageMagick not found. Install with: brew install imagemagick"
    echo "Copy logo file manually to: ${OUTPUT_DIR}/logo-256.png"
fi
