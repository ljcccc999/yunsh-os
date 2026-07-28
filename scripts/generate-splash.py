#!/usr/bin/env python3
"""Generate deterministic YUNSH boot splash assets from the repository logo."""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "logo" / "logo-512.png"
OUTPUT = ROOT / "build" / "splash"


def font_for(size: int):
    candidates = (
        "/System/Library/Fonts/HelveticaNeue.ttc",
        "/System/Library/Fonts/Helvetica.ttc",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
        "/usr/share/fonts/truetype/liberation2/LiberationSans-Regular.ttf",
    )
    for path in candidates:
        if Path(path).is_file():
            return ImageFont.truetype(path, size=size, index=0)
    return ImageFont.load_default()


def logo_layer(size: int) -> Image.Image:
    with Image.open(SOURCE) as source:
        logo = source.convert("RGBA")
    alpha_bounds = logo.getchannel("A").getbbox()
    if alpha_bounds:
        logo = logo.crop(alpha_bounds)
    logo.thumbnail((size, size), Image.Resampling.LANCZOS)
    return logo


def compose(width: int, height: int, with_wordmark: bool) -> Image.Image:
    canvas = Image.new("RGBA", (width, height), (0, 0, 0, 255))
    mark_size = round(height * (0.24 if with_wordmark else 0.30))
    mark = logo_layer(mark_size)
    mark_y = round(height * (0.40 if with_wordmark else 0.50) - mark.height / 2)
    canvas.alpha_composite(mark, ((width - mark.width) // 2, mark_y))

    if with_wordmark:
        font = font_for(max(28, round(height * 0.055)))
        draw = ImageDraw.Draw(canvas)
        text = "YUNSH OS"
        bounds = draw.textbbox((0, 0), text, font=font)
        text_width = bounds[2] - bounds[0]
        text_y = mark_y + mark.height + round(height * 0.055)
        draw.text(
            ((width - text_width) / 2, text_y),
            text,
            font=font,
            fill=(255, 255, 255, 224),
        )
    return canvas


def save_bmp(image: Image.Image, name: str):
    image.convert("RGB").save(OUTPUT / name, format="BMP")


def save_raw(image: Image.Image, name: str):
    # Raspberry Pi 32-bit framebuffer memory order is BGRA/XRGB.
    (OUTPUT / name).write_bytes(image.tobytes("raw", "BGRA"))


def main():
    if not SOURCE.is_file():
        raise SystemExit(f"YUNSH logo is missing: {SOURCE}")
    OUTPUT.mkdir(parents=True, exist_ok=True)

    logo_1080 = compose(1920, 1080, with_wordmark=False)
    full_1080 = compose(1920, 1080, with_wordmark=True)
    full_720 = compose(1280, 720, with_wordmark=True)

    save_raw(logo_1080, "yunsh-splash-logo.raw")
    save_raw(full_1080, "yunsh-splash-full.raw")
    save_bmp(logo_1080, "yunsh-splash-logo.bmp")
    save_bmp(full_1080, "yunsh-splash-full.bmp")
    save_bmp(full_720, "yunsh-splash-full-720p.bmp")

    expected_raw = 1920 * 1080 * 4
    for path in OUTPUT.glob("yunsh-splash-*.raw"):
        if path.stat().st_size != expected_raw:
            raise SystemExit(f"invalid raw splash size: {path}")
    for path in OUTPUT.glob("yunsh-splash-*.bmp"):
        with Image.open(path) as image:
            image.verify()
    print(f"Generated verified splash assets in {OUTPUT}")


if __name__ == "__main__":
    main()
