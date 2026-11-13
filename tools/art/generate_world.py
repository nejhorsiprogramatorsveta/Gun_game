#!/usr/bin/env python3
"""Generates the original pixel-art world and UI graphics (dev tool, PLAN.md Q).

Run from the project root:  python3 tools/art/generate_world.py   (needs Pillow)
Writes PNGs to assets/; commit them and run the Godot import. Everything is drawn here
procedurally with fixed random seeds (same result every run), no third-party images.

  assets/sprites/tiles/   stone_top.png 16x16, stone_fill.png 16x16, wood_beam.png 16x8,
                          turf_top.png / turf_fill.png 16x16 (grass on earth, Hobitín)
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


def turf_tile(top: bool) -> Image.Image:
    """Hobitín ground: brown earth with pebbles and roots; `top` adds a lush grass edge with
    blades sticking up (solid blocks of the hobbit hills)."""
    rnd = random.Random(61 if top else 62)
    earth, dark, light = rgb("#7a5232"), rgb("#5e3e25"), rgb("#93683f")
    img = new(16, 16, earth)
    for y in range(16):
        for x in range(16):
            roll = rnd.random()
            if roll < 0.14:
                px(img, x, y, dark)
            elif roll < 0.2:
                px(img, x, y, light)
    for _ in range(2):  # pebbles
        x, y = rnd.randrange(1, 14), rnd.randrange(6 if top else 1, 14)
        rect(img, x, y, x + 1, y, rgb("#a89478")); px(img, x, y + 1, rgb("#6e6250"))
    if not top:
        x = rnd.randrange(3, 12)  # a thin root
        for y in range(3, 10):
            px(img, x + (y // 3) % 2, y, rgb("#4a3020"))
        return img
    grass, grass_dark, grass_light = rgb("#5fa844"), rgb("#3f7d2e"), rgb("#8fd16a")
    rect(img, 0, 0, 15, 4, grass)
    for x in range(16):
        px(img, x, 5 + (1 if rnd.random() < 0.4 else 0), grass_dark)  # ragged lower edge
        if rnd.random() < 0.45:
            px(img, x, 0, grass_light)
        if rnd.random() < 0.3:
            px(img, x, rnd.randrange(1, 4), grass_dark)
    for x in (3, 11):  # tiny flowers in the grass
        px(img, x, 1, rgb("#ffe066") if x == 3 else rgb("#ff8fb0"))
    return img


def lava_surface() -> Image.Image:
    """4 frames of 32x12 (Peklo): the wavy glowing top of the lava; the wave moves by 8 px
    per frame and the strip tiles sideways. Transparent above the crest."""
    frames = []
    for f in range(4):
        img = new(32, 12)
        rnd = random.Random(40 + f)
        for x in range(32):
            crest = 3 + round(1.6 * math.sin((x + f * 8) / 32 * math.tau) + 0.8 * math.sin((x + f * 8) / 16 * math.tau))
            px(img, x, crest, rgb("#fff1a0"))
            px(img, x, crest + 1, rgb("#ffc93c"))
            rect(img, x, crest + 2, x, crest + 3, rgb("#ff8a24"))
            rect(img, x, crest + 4, x, 11, rgb("#e0451c"))
        for _ in range(3):  # bubbles popping at the crest
            bx, by = rnd.randrange(1, 31), rnd.randrange(5, 10)
            px(img, bx, by, rgb("#ffe066")); px(img, bx + 1, by, rgb("#ffb347")); px(img, bx, by + 1, rgb("#b3260f"))
        frames.append(img)
    out = new(32 * 4, 12)
    for i, frame in enumerate(frames):
        out.paste(frame, (i * 32, 0))
    return out


def lava_fill() -> Image.Image:
    """32x32 tile under the lava surface: molten rock with darker crust patches and a few
    glowing cracks that wrap around the edges, so the tiling is hard to spot."""
    rnd = random.Random(44)
    img = new(32, 32, rgb("#b3260f"))
    for _ in range(14):  # darker crust patches
        cx, cy, r = rnd.randrange(32), rnd.randrange(32), rnd.randrange(1, 4)
        for y in range(cy - r, cy + r + 1):
            for x in range(cx - r, cx + r + 1):
                if (x - cx) ** 2 + (y - cy) ** 2 <= r * r and rnd.random() < 0.8:
                    img.putpixel((x % 32, y % 32), rgb("#7a160a"))
    for _ in range(4):  # glowing cracks
        x, y = rnd.randrange(32), rnd.randrange(32)
        for _ in range(rnd.randrange(6, 12)):
            img.putpixel((x % 32, y % 32), rgb("#ff7a24"))
            x += rnd.choice((1, 1, 0))
            y += rnd.choice((-1, 0, 1))
    for _ in range(10):  # single bright specks
        img.putpixel((rnd.randrange(32), rnd.randrange(32)), rgb("#ffb347"))
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


def bg_hell() -> Image.Image:
    """Peklo: red-black sky, volcanic ridges, a burning crater, a scorched torii and embers;
    a lava glow at the bottom."""
    img = new(W, H)
    sky(img, rgb("#140404"), rgb("#7a1a08"))
    rnd = random.Random(51)
    for _ in range(60):  # embers rising
        px(img, rnd.randrange(W), rnd.randrange(H - 30), rgb("#ff9a3c") if rnd.random() < 0.6 else rgb("#ffe08a"))
    # volcano with a glowing crater and a lava stream
    for y in range(110, H):
        half = (y - 110) * 1.4 + 10
        rect(img, int(330 - half), y, int(330 + half), y, rgb("#2a0a06"))
    rect(img, 320, 108, 340, 111, rgb("#ff7a24")); rect(img, 324, 106, 336, 107, rgb("#ffd060"))
    for y in range(112, 200):
        x = 330 + int(6 * math.sin(y / 9.0))
        rect(img, x - 1, y, x + 1, y, rgb("#ff6a1a"))
    ridge(img, 200, 34, rgb("#3a0d07"), 52, 0.06)
    ridge(img, 228, 20, rgb("#220604"), 53, 0.09)
    torii(img, 110, 236, 15, rgb("#0e0303"))  # scorched shrine gate
    rect(img, 101, 214, 103, 217, rgb("#ff5a1a"))  # embers on the lintel
    for y in range(244, H):  # lava glow on the horizon
        t = (y - 244) / max(1, H - 245)
        rect(img, 0, y, W - 1, y, mix(rgb("#3a0d07"), rgb("#ff6a1a"), t * 0.9))
    return img


def hills(img, base_y: int, amplitude: int, color: tuple, seed: int, freq: float = 0.02) -> list:
    """Soft rolling hills (no sharp peaks, unlike ridge()); returns the top y of every column."""
    rnd = random.Random(seed)
    waves = [(freq * k * rnd.uniform(0.8, 1.2), rnd.uniform(0, math.tau), 1.0 / k) for k in (1, 2, 3)]
    tops = []
    for x in range(W):
        value = sum(weight * (0.5 + 0.5 * math.sin(x * f + phase)) for f, phase, weight in waves) / 1.83
        top = int(base_y - value * amplitude)
        rect(img, x, top, x, H - 1, color)
        tops.append(top)
    return tops


def hobbit_hole(img, cx, cy, door: tuple, rnd: random.Random):
    """Round door with a wooden frame and a brass knob, a round window beside it and a
    chimney with smoke puffs on the hill above (original drawing)."""
    circle(img, cx, cy, 9, rgb("#3f6e2e"))  # shadow of the doorway in the hill
    circle(img, cx, cy, 8, rgb("#6b4a2b"))  # wooden frame
    circle(img, cx, cy, 6, door)
    for i in range(-5, 6, 3):  # planks
        rect(img, cx + i, cy - 5, cx + i, cy + 5, mix(door, rgb("#000000"), 0.25))
    px(img, cx, cy, rgb("#f0d060")); px(img, cx + 1, cy, rgb("#b8902a"))  # brass knob in the middle
    rect(img, cx - 6, cy + 9, cx + 6, cy + 10, rgb("#d9c08a"))  # doorstep
    side = rnd.choice((-1, 1))
    wx = cx + side * 15
    circle(img, wx, cy - 1, 4, rgb("#6b4a2b"))
    circle(img, wx, cy - 1, 3, rgb("#ffe9a8"))
    rect(img, wx - 3, cy - 1, wx + 3, cy - 1, rgb("#6b4a2b")); rect(img, wx, cy - 4, wx, cy + 2, rgb("#6b4a2b"))
    chimney_x = cx - side * 10
    rect(img, chimney_x - 1, cy - 20, chimney_x + 2, cy - 13, rgb("#8a7a6a"))
    rect(img, chimney_x - 2, cy - 21, chimney_x + 3, cy - 20, rgb("#6a5a4a"))
    for i in range(4):  # smoke drifting up and to the right
        circle(img, chimney_x + 1 + i * 3, cy - 25 - i * 6, 2 + i // 2, rgb("#f2f2ee", 200 - i * 35))


def fence(img, x0, x1, base_y):
    for x in range(x0, x1 + 1, 6):
        rect(img, x, base_y - 7, x + 1, base_y, rgb("#8a6a42"))
    rect(img, x0, base_y - 5, x1 + 1, base_y - 5, rgb("#a07a4c"))
    rect(img, x0, base_y - 2, x1 + 1, base_y - 2, rgb("#a07a4c"))


def big_tree(img, cx, base_y):
    rect(img, cx - 3, base_y - 26, cx + 3, base_y, rgb("#5a3c22"))
    rect(img, cx - 6, base_y - 3, cx + 6, base_y, rgb("#5a3c22"))  # roots
    for ox, oy, r, color in ((-14, -34, 13, "#3f7d2e"), (12, -36, 14, "#3f7d2e"), (0, -48, 16, "#4f8f38"),
                             (-8, -42, 10, "#5fa844"), (9, -48, 9, "#6cb84f")):
        circle(img, cx + ox, base_y + oy, r, rgb(color))


def bg_hobbiton() -> Image.Image:
    """Hobitín: a sunny green countryside of rolling hills with round doors dug into them,
    fences, a winding path, flowers and a big tree (original procedural drawing)."""
    img = new(W, H)
    sky(img, rgb("#6fb7e8"), rgb("#d6eef2"))
    circle(img, 70, 48, 18, rgb("#fff3c4")); circle(img, 70, 48, 14, rgb("#ffe68a"))
    hills(img, 150, 40, rgb("#9cc98a"), 71, 0.015)  # far, misty hills
    mid = hills(img, 195, 45, rgb("#6aa84f"), 72, 0.018)
    rnd = random.Random(73)
    big_tree(img, 360, mid[360] + 4)
    for cx, color in ((60, "#2e7d32"), (160, "#e0b030"), (265, "#b03a2e"), (430, "#2d5aa0")):
        hobbit_hole(img, cx, mid[cx] + 22, rgb(color), rnd)
    front = hills(img, 238, 22, rgb("#4f8a3a"), 74, 0.025)
    for x0, x1 in ((20, 120), (300, 420)):
        fence(img, x0, x1, front[(x0 + x1) // 2] + 2)
    for x in range(W):  # a winding sandy path along the front hill
        y = front[x] + 10 + int(4 * math.sin(x / 40.0))
        rect(img, x, y, x, y + 2, rgb("#d9c08a"))
    for _ in range(90):  # flowers
        x = rnd.randrange(W)
        y = rnd.randrange(front[x] + 1, H)
        px(img, x, y, rgb(rnd.choice(("#ffe066", "#ff8fb0", "#ffffff", "#e05050"))))
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
    bg_hell().save(bgs / "hell.png")
    bg_hobbiton().save(bgs / "hobbiton.png")
    turf_tile(True).save(tiles / "turf_top.png")
    turf_tile(False).save(tiles / "turf_fill.png")
    lava_surface().save(tiles / "lava_surface.png")
    lava_fill().save(tiles / "lava_fill.png")
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
