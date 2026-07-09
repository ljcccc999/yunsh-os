#!/usr/bin/env python3
"""YUNSH OS v1.0 - Process logo image for system use"""
import os
import sys
from PIL import Image

LOGO_SOURCE = "/Users/tim/.openclaw/media/inbound/d517850f-c470-4f5f-a111-adad73e285d4.jpg"
OUTPUT_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), "logo")

def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    
    if not os.path.exists(LOGO_SOURCE):
        print(f"Logo source not found at {LOGO_SOURCE}, creating placeholder")
        create_placeholder()
        return
    
    img = Image.open(LOGO_SOURCE).convert("RGBA")
    
    # Make white pixels transparent
    pixels = img.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = img.getpixel((x, y))
            if r > 200 and g > 200 and b > 200:
                img.putpixel((x, y), (r, g, b, 0))
            else:
                img.putpixel((x, y), (r, g, b, 255))
    
    # Save all sizes
    for size in [32, 64, 128, 256, 512]:
        resized = img.resize((size, size), Image.LANCZOS)
        path = os.path.join(OUTPUT_DIR, f"logo-{size}.png")
        resized.save(path)
        print(f"  Created: logo-{size}.png")
    
    print("Logo processing complete!")

def create_placeholder():
    """Create placeholder YUNSH logo (atom icon)"""
    for size in [32, 64, 128, 256, 512]:
        img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
        cx, cy = size // 2, size // 2
        
        from PIL import ImageDraw
        draw = ImageDraw.Draw(img)
        
        # Red center circle
        r = size // 8
        draw.ellipse([cx-r, cy-r, cx+r, cy+r], fill=(255, 50, 50, 255))
        
        # Three blue orbits
        colors = [(0, 150, 255, 200), (0, 180, 255, 180), (0, 120, 220, 160)]
        for i, (rx, ry, color) in enumerate([
            (size*0.35, size*0.15, colors[0]),
            (size*0.35, size*0.15, colors[1]),
            (size*0.2, size*0.3, colors[2]),
        ]):
            draw.ellipse([cx-rx, cy-ry, cx+rx, cy+ry], outline=color, width=max(2, size//20))
        
        img.save(os.path.join(OUTPUT_DIR, f"logo-{size}.png"))
        print(f"  Created (placeholder): logo-{size}.png")

if __name__ == "__main__":
    main()
