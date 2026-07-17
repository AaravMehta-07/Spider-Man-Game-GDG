from __future__ import annotations

import argparse
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
BRANDING = ROOT / "game" / "assets" / "branding"
TEXTURES = ROOT / "game" / "assets" / "textures"


def font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    for path in (Path("C:/Windows/Fonts/arialbd.ttf"), Path("C:/Windows/Fonts/segoeuib.ttf")):
        if path.is_file():
            return ImageFont.truetype(str(path), size)
    return ImageFont.load_default()


def logo(path: Path, title: str, accent: tuple[int, int, int]) -> None:
    image = Image.new("RGBA", (1024, 320), (3, 8, 22, 0))
    draw = ImageDraw.Draw(image)
    draw.polygon([(0, 0), (1024, 0), (930, 320), (0, 320)], fill=(3, 8, 22, 238))
    draw.rectangle((0, 0, 1024, 13), fill=accent + (255,))
    draw.text((55, 75), title, font=font(78), fill=(245, 248, 255, 255))
    draw.text((59, 190), "SPIDER-SENSE", font=font(42), fill=accent + (255,))
    image.save(path)


def emblem(path: Path) -> None:
    image = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    center = (256, 256)
    for radius in (70, 130, 195):
        draw.ellipse(
            (256 - radius, 256 - radius, 256 + radius, 256 + radius),
            outline=(210, 242, 255, 225),
            width=8,
        )
    for angle in range(0, 360, 45):
        import math

        end = (
            256 + int(math.cos(math.radians(angle)) * 220),
            256 + int(math.sin(math.radians(angle)) * 220),
        )
        draw.line((center, end), fill=(210, 242, 255, 225), width=7)
    draw.polygon(
        [(256, 98), (310, 214), (290, 404), (256, 445), (222, 404), (202, 214)],
        fill=(225, 10, 38, 255),
    )
    draw.ellipse((215, 170, 297, 265), fill=(5, 14, 35, 255))
    image.save(path)


def qr_placeholder(path: Path) -> None:
    random.seed(42420)
    size = 33
    scale = 12
    border = 4
    image = Image.new("RGB", ((size + border * 2) * scale, (size + border * 2) * scale), "white")
    draw = ImageDraw.Draw(image)
    grid = [[random.random() > 0.52 for _ in range(size)] for _ in range(size)]

    def finder(x: int, y: int) -> None:
        for row in range(7):
            for col in range(7):
                edge = row in (0, 6) or col in (0, 6)
                core = 2 <= row <= 4 and 2 <= col <= 4
                grid[y + row][x + col] = edge or core

    finder(0, 0)
    finder(size - 7, 0)
    finder(0, size - 7)
    for y, row in enumerate(grid):
        for x, value in enumerate(row):
            if value:
                x0, y0 = (x + border) * scale, (y + border) * scale
                draw.rectangle((x0, y0, x0 + scale - 1, y0 + scale - 1), fill=(4, 10, 25))
    draw.rectangle((0, image.height - 38, image.width, image.height), fill=(225, 10, 38))
    draw.text(
        (image.width // 2, image.height - 19),
        "REPLACE EVENT QR",
        font=font(16),
        fill="white",
        anchor="mm",
    )
    image.save(path)


def app_icon(path: Path) -> None:
    source = Image.open(BRANDING / "hero_emblem.png").convert("RGBA")
    source.save(
        path,
        format="ICO",
        sizes=[(16, 16), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)],
    )

def procedural_textures() -> None:
    TEXTURES.mkdir(parents=True, exist_ok=True)
    web = Image.new("RGBA", (512, 512), (3, 8, 22, 255))
    draw = ImageDraw.Draw(web)
    for radius in range(45, 360, 45):
        draw.ellipse(
            (256 - radius, 256 - radius, 256 + radius, 256 + radius),
            outline=(170, 225, 245, 70),
            width=2,
        )
    for offset in range(0, 360, 30):
        import math

        draw.line(
            (
                256,
                256,
                256 + math.cos(math.radians(offset)) * 390,
                256 + math.sin(math.radians(offset)) * 390,
            ),
            fill=(170, 225, 245, 70),
            width=2,
        )
    web.save(TEXTURES / "web_grid.png")

    halftone = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
    draw = ImageDraw.Draw(halftone)
    for y in range(8, 256, 16):
        for x in range(8, 256, 16):
            draw.ellipse((x - 2, y - 2, x + 2, y + 2), fill=(255, 255, 255, 45))
    halftone.save(TEXTURES / "halftone.png")


def main(argv: list[str] | None = None) -> None:
    parser = argparse.ArgumentParser(description="Generate replaceable local art assets")
    parser.add_argument("--force-branding", action="store_true")
    args = parser.parse_args(argv)
    BRANDING.mkdir(parents=True, exist_ok=True)
    branding_jobs = (
        (logo, BRANDING / "game_logo.png", ("WEB//PROTOCOL", (226, 10, 38))),
        (logo, BRANDING / "event_logo.png", ("AI/ML RECRUITMENT", (10, 170, 235))),
        (emblem, BRANDING / "hero_emblem.png", ()),
        (qr_placeholder, BRANDING / "recruitment_qr.png", ()),
    )
    for generator, path, arguments in branding_jobs:
        if args.force_branding or not path.exists():
            generator(path, *arguments)
    icon_path = BRANDING / "app_icon.ico"
    if args.force_branding or not icon_path.exists():
        app_icon(icon_path)
    icon_path = BRANDING / "app_icon.ico"
    if args.force_branding or not icon_path.exists():
        app_icon(icon_path)
    procedural_textures()
    print("Verified replaceable branding and generated procedural textures")


if __name__ == "__main__":
    main()
