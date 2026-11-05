#!/usr/bin/env python3
"""Generates the original pixel-art world and UI graphics (dev tool, PLAN.md Q).

Run from the project root:  python3 tools/art/generate_world.py   (needs Pillow)
Writes PNGs to assets/; commit them and run the Godot import. Everything is drawn here
procedurally with fixed random seeds (same result every run), no third-party images.

  assets/sprites/tiles/   stone_top.png 16x16, stone_fill.png 16x16, wood_beam.png 16x8
  assets/backgrounds/     <arena>.png 480x270 (static scene), clouds.png 480x120 (drifting)
  assets/ui/              button_*.png (9-slice, 2x pixels), field.png, panel.png, logo.png
"""

import math
import random
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUTLINE = (18, 14, 22, 255)


def rgb(hex_color: str, alpha: int = 255) -> tuple:
    h = hex_color.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (alpha,)


def mix(a: tuple, b: tuple, t: float) -> tuple:
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3)) + (255,)


def new(w: int, h: int, color=(0, 0, 0, 0)) -> Image.Image:
    return Image.new("RGBA", (w, h), color)


def rect(img, x0, y0, x1, y1, color):
    for y in range(max(0, y0), min(img.height, y1 + 1)):
        for x in range(max(0, x0), min(img.width, x1 + 1)):
            img.putpixel((x, y), color)


def px(img, x, y, color):
    if 0 <= x < img.width and 0 <= y < img.height:
        img.putpixel((x, y), color)


# --- Tiles ---------------------------------------------------------------------------

def stone_tile(top: bool) -> Image.Image:
    """Mossy temple stone blocks; `top` adds grass/moss and a light top edge."""
    rnd = random.Random(7 if top else 8)
    base, dark, light, mortar = rgb("#6b6f80"), rgb("#4e5160"), rgb("#8a8fa3"), rgb("#353744")
    img = new(16, 16, base)
    for y in range(16):
        for x in range(16):
            if rnd.random() < 0.12:
                px(img, x, y, dark if rnd.random() < 0.6 else light)
    # Brick layout: two rows of 8 px high, offset joints.
    for y in (7, 15):
        rect(img, 0, y, 15, y, mortar)
    for x in (0,):
        rect(img, x, 0, x, 7, mortar)
    rect(img, 8, 8, 8, 15, mortar)
    rect(img, 1, 0, 6, 0, light)
    rect(img, 9, 8, 14, 8, light)
    if top:
        moss, moss_dark = rgb("#5f9e4a"), rgb("#3f7034")
        rect(img, 0, 0, 15, 2, moss)
        for x in range(16):
            if rnd.random() < 0.5:
                px(img, x, 3, moss_dark)
            if rnd.random() < 0.3:
                px(img, x, 0, rgb("#86c26a"))
    return img


def wood_beam() -> Image.Image:
    """Dark wooden beam for one-way platforms (jump through from below)."""
    rnd = random.Random(9)
    img = new(16, 8, rgb("#8a5a35"))
    rect(img, 0, 0, 15, 1, rgb("#b07a4a"))
    rect(img, 0, 6, 15, 7, rgb("#5a3a22"))
    for _ in range(10):
        px(img, rnd.randrange(16), rnd.randrange(2, 6), rgb("#6e4629"))
    px(img, 3, 3, rgb("#3b2616")); px(img, 12, 4, rgb("#3b2616"))  # wooden pegs
    return img


# --- Backgrounds ----------------------------------------------------------------------

W, H = 480, 270


def sky(img, top: tuple, bottom: tuple, bands: int = 14):
    """Banded vertical gradient with a dithered seam between bands (classic pixel sky)."""
    band_h = H / bands
    for y in range(H):
        t = min(int(y / band_h), bands - 1) / (bands - 1)
        nxt = min(int(y / band_h) + 1, bands - 1) / (bands - 1)
        for x in range(W):
            in_seam = (y % band_h) > band_h - 3 and (x + y) % 2 == 0
            img.putpixel((x, y), mix(top, bottom, nxt if in_seam else t))


def ridge(img, base_y: int, amplitude: int, color: tuple, seed: int, roughness: float = 0.08):
    """Smooth mountain silhouette: a few sine waves with random phases (peaks a bit pointy)
    plus 1-px noise. `roughness` sets how many peaks fit across the screen."""
    rnd = random.Random(seed)
    waves = [(rnd.uniform(0.5, 1.0) * roughness * 0.25 * k, rnd.uniform(0, math.tau), 1.0 / k) for k in (1, 2, 4)]
    for x in range(W):
        value = sum(weight * (1.0 - abs(math.sin(x * freq + phase))) for freq, phase, weight in waves) / 1.75
        top = int(base_y - value * amplitude * 2) + rnd.choice((0, 0, 0, 1))
        rect(img, x, top, x, H - 1, color)


def circle(img, cx, cy, r, color):
    for y in range(cy - r, cy + r + 1):
        for x in range(cx - r, cx + r + 1):
            if (x - cx) ** 2 + (y - cy) ** 2 <= r * r:
                px(img, x, y, color)


def pagoda(img, cx, base_y, tiers, color, window=None, rnd=None):
    """Silhouette of a pagoda: stacked roofs with upturned eaves."""
    y = base_y
    width = 12 + tiers * 6
    for tier in range(tiers):
        body_h = 9
        rect(img, cx - width // 2 + 3, y - body_h, cx + width // 2 - 3, y, color)
        if window and rnd and rnd.random() < 0.7:
            rect(img, cx - 1, y - 6, cx + 1, y - 4, window)
        y -= body_h
        rect(img, cx - width // 2 - 2, y - 2, cx + width // 2 + 2, y, color)  # roof
        px(img, cx - width // 2 - 3, y - 3, color)
        px(img, cx + width // 2 + 3, y - 3, color)
        width -= 6
        y -= 2
    rect(img, cx, y - 6, cx, y, color)  # spire


def torii(img, cx, base_y, size, color):
    """Shrine gate: two posts, two lintels with upturned ends."""
    h, w = size * 2, size * 2
    rect(img, cx - w // 2, base_y - h, cx - w // 2 + 1, base_y, color)
    rect(img, cx + w // 2 - 1, base_y - h, cx + w // 2, base_y, color)
    rect(img, cx - w // 2 - 4, base_y - h - 3, cx + w // 2 + 4, base_y - h - 1, color)
    px(img, cx - w // 2 - 5, base_y - h - 4, color); px(img, cx + w // 2 + 5, base_y - h - 4, color)
    rect(img, cx - w // 2 - 1, base_y - h + 4, cx + w // 2 + 1, base_y - h + 5, color)


def stars(img, count, seed, max_y):
    rnd = random.Random(seed)
    for _ in range(count):
        x, y = rnd.randrange(W), rnd.randrange(max_y)
        px(img, x, y, rgb("#fff6d8") if rnd.random() < 0.3 else rgb("#9aa4d8"))


def bg_rooftops() -> Image.Image:
    img = new(W, H)
    sky(img, rgb("#0f1030"), rgb("#3b2d5c"))
    stars(img, 140, 1, 150)
    circle(img, 380, 60, 22, rgb("#f3e6b8")); circle(img, 372, 55, 5, rgb("#e2d29c")); circle(img, 388, 70, 3, rgb("#e2d29c"))
    ridge(img, 215, 35, rgb("#2a2550"), 11, 0.05)
    ridge(img, 238, 18, rgb("#221d40"), 12, 0.09)
    rnd = random.Random(13)
    x = 10
    while x < W:  # city of pagoda roofs with lit windows
        pagoda(img, x, 260 - rnd.randrange(0, 20), rnd.randrange(1, 4), rgb("#16122b"), rgb("#ffcf6b"), rnd)
        x += rnd.randrange(34, 60)
    rect(img, 0, 255, W - 1, H - 1, rgb("#110e22"))
    return img


def bg_temple_steps() -> Image.Image:
    img = new(W, H)
    sky(img, rgb("#3b2a6b"), rgb("#ff9a62"))
    circle(img, 150, 105, 30, rgb("#ffd27a")); circle(img, 150, 105, 24, rgb("#ffe7a8"))
    ridge(img, 200, 40, rgb("#b0587a"), 21, 0.05)
    ridge(img, 222, 26, rgb("#7b3a68"), 22, 0.07)
    ridge(img, 242, 14, rgb("#4a2350"), 23, 0.1)
    for cx, by, size in ((70, 250, 14), (300, 240, 11), (420, 252, 16)):
        torii(img, cx, by, size, rgb("#2a1230"))
    rnd = random.Random(24)
    for _ in range(40):  # drifting petals
        px(img, rnd.randrange(W), rnd.randrange(H - 40), rgb("#ffc2d6"))
    rect(img, 0, 252, W - 1, H - 1, rgb("#2a1230"))
    return img


def bg_hanging_bridges() -> Image.Image:
    img = new(W, H)
    sky(img, rgb("#6fb7c9"), rgb("#d9eee4"))
    ridge(img, 170, 50, rgb("#9fc7c4"), 31, 0.04)
    ridge(img, 205, 30, rgb("#79a8a6"), 32, 0.07)
    rnd = random.Random(33)
    for cx in (40, 120, 250, 360, 450):  # tall rock pillars with pines on top
        width = rnd.randrange(18, 34)
        top = rnd.randrange(90, 150)
        rect(img, cx - width // 2, top, cx + width // 2, H - 1, rgb("#4f7a78"))
        rect(img, cx - width // 2, top, cx - width // 2 + 2, H - 1, rgb("#6a9795"))
        for i in range(3):
            tree_x = cx - width // 2 + 4 + i * (width // 3)
            for row in range(6):
                rect(img, tree_x - (5 - row) // 2, top - 6 + row, tree_x + (5 - row) // 2, top - 6 + row, rgb("#2f5d4a"))
    rect(img, 300, 120, 303, H - 1, rgb("#eaf7f7"))  # waterfall
    for y in range(120, H, 4):
        px(img, 301, y, rgb("#b8e0e6"))
    mist = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    for y in range(H):  # soft mist rising from the valley (dithered alpha bands)
        strength = max(0.0, (y - 170) / 100.0)
        for x in range(W):
            wave = 0.15 * math.sin(x / 23.0 + y / 9.0)
            alpha = strength + wave
            if alpha > 0.15 and (x + y * 3) % max(1, int(4 - alpha * 3)) == 0:
                mist.putpixel((x, y), rgb("#f2fbf8", int(min(alpha, 0.85) * 200)))
    img.alpha_composite(mist)
    return img


def clouds() -> Image.Image:
    img = new(W, 120)
    rnd = random.Random(41)
    for _ in range(7):
        cx, cy = rnd.randrange(W), rnd.randrange(15, 100)
        for _ in range(6):
            r = rnd.randrange(6, 13)
            ox, oy = cx + rnd.randrange(-18, 18), cy + rnd.randrange(-4, 4)
            for y in range(oy - r, oy + 1):
                for x in range(ox - r, ox + r + 1):
                    if (x - ox) ** 2 + (y - oy) ** 2 <= r * r:
                        px(img, x % W, y, rgb("#ffffff", 150))
    return img


# --- UI -------------------------------------------------------------------------------

def frame(fill: tuple, border: tuple, light: tuple, shadow: tuple, size: int = 12) -> Image.Image:
    """9-slice frame (4-px corners) with an outline, bevel and drop shadow; drawn at 1x."""
    img = new(size, size)
    rect(img, 1, 1, size - 2, size - 2, fill)
    rect(img, 1, 0, size - 2, 0, border); rect(img, 1, size - 1, size - 2, size - 1, border)
    rect(img, 0, 1, 0, size - 2, border); rect(img, size - 1, 1, size - 1, size - 2, border)
    rect(img, 1, 1, size - 2, 1, light); rect(img, 1, 1, 1, size - 3, light)
    rect(img, 1, size - 2, size - 2, size - 2, shadow); rect(img, size - 2, 2, size - 2, size - 2, shadow)
    return img


def scaled(img: Image.Image, factor: int = 2) -> Image.Image:
    return img.resize((img.width * factor, img.height * factor), Image.NEAREST)


# 5x7 pixel glyphs for the logo (original lettering).
GLYPHS = {
    "D": ["1110", "1001", "1001", "1001", "1001", "1001", "1110"],
    "O": ["0110", "1001", "1001", "1001", "1001", "1001", "0110"],
    "J": ["0011", "0001", "0001", "0001", "0001", "1001", "0110"],
    "K": ["1001", "1010", "1100", "1100", "1010", "1001", "1001"],
    "N": ["100001", "110001", "101001", "100101", "100011", "100001", "100001"],
    "C": ["0111", "1000", "1000", "1000", "1000", "1000", "0111"],
    "U": ["1001", "1001", "1001", "1001", "1001", "1001", "0110"],
    "T": ["11111", "00100", "00100", "00100", "00100", "00100", "00100"],
    " ": ["00", "00", "00", "00", "00", "00", "00"],
}


def logo() -> Image.Image:
    text = "DOJO KNOCKOUT"
    width = sum(len(GLYPHS[ch][0]) + 2 for ch in text) + 3
    img = new(width, 13)
    x = 1
    top, bottom = rgb("#ffe7a8"), rgb("#e0603a")
    for ch in text:
        glyph = GLYPHS[ch]
        for gy, row in enumerate(glyph):
            for gx, bit in enumerate(row):
                if bit == "1":
                    px(img, x + gx, 2 + gy, mix(top, bottom, gy / 6))
        x += len(glyph[0]) + 2
    bold = img.copy()  # 2-px vertical strokes: brighter, chunkier letters
    for y in range(img.height):
        for x in range(img.width - 1):
            if img.getpixel((x, y))[3] and not bold.getpixel((x + 1, y))[3]:
                bold.putpixel((x + 1, y), img.getpixel((x, y)))
    img = bold
    # Katana stroke under the title.
    rect(img, 2, 11, width - 8, 11, rgb("#c9ced6"))
    rect(img, width - 7, 11, width - 4, 11, rgb("#c0392b"))
    out = img.copy()
    for y in range(img.height):  # outline
        for x in range(img.width):
            if img.getpixel((x, y))[3] == 0 and any(
                    0 <= x + dx < img.width and 0 <= y + dy < img.height and img.getpixel((x + dx, y + dy))[3]
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                out.putpixel((x, y), OUTLINE)
    return out


def main() -> None:
    tiles, bgs, ui = ROOT / "assets/sprites/tiles", ROOT / "assets/backgrounds", ROOT / "assets/ui"
    for d in (tiles, bgs, ui):
        d.mkdir(parents=True, exist_ok=True)
    stone_tile(True).save(tiles / "stone_top.png")
    stone_tile(False).save(tiles / "stone_fill.png")
    wood_beam().save(tiles / "wood_beam.png")
    bg_rooftops().save(bgs / "rooftops.png")
    bg_temple_steps().save(bgs / "temple_steps.png")
    bg_hanging_bridges().save(bgs / "hanging_bridges.png")
    clouds().save(bgs / "clouds.png")
    border = rgb("#120e16")
    scaled(frame(rgb("#3a2f4a"), border, rgb("#5a4a70"), rgb("#241c30"))).save(ui / "button_normal.png")
    scaled(frame(rgb("#4d3d63"), border, rgb("#7a64a0"), rgb("#2e2440"))).save(ui / "button_hover.png")
    scaled(frame(rgb("#c0392b"), border, rgb("#e06050"), rgb("#7e231a"))).save(ui / "button_pressed.png")
    scaled(frame(rgb("#2a2533"), border, rgb("#332d3d"), rgb("#1e1a25"))).save(ui / "button_disabled.png")
    scaled(frame(rgb("#e5b63c", 0), rgb("#e5b63c"), rgb("#e5b63c", 0), rgb("#e5b63c", 0))).save(ui / "focus.png")
    scaled(frame(rgb("#17131f"), border, rgb("#241e30"), rgb("#0f0c15"))).save(ui / "field.png")
    scaled(frame(rgb("#211a2c", 235), border, rgb("#3a2f4a"), rgb("#140f1b"))).save(ui / "panel.png")
    scaled(logo(), 6).save(ui / "logo.png")
    print("Wrote tiles, backgrounds and UI graphics to assets/")


if __name__ == "__main__":
    main()
