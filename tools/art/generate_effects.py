#!/usr/bin/env python3
"""Generates the original pixel-art ability effects (dev tool, PLAN.md Q).

Run from the project root:  python3 tools/art/generate_effects.py   (needs Pillow)
Writes horizontal frame strips to assets/sprites/effects/ (all frames of one strip have
the same size; the size is in the docstring of each function).
"""

import math
import random
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "sprites" / "effects"
OUTLINE = (18, 14, 22, 255)


def rgb(hex_color: str, alpha: int = 255) -> tuple:
    h = hex_color.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (alpha,)


def px(img, x, y, color):
    if 0 <= x < img.width and 0 <= y < img.height:
        img.putpixel((x, y), color)


def disc(img, cx, cy, r, color):
    for y in range(int(cy - r), int(cy + r) + 1):
        for x in range(int(cx - r), int(cx + r) + 1):
            if (x - cx) ** 2 + (y - cy) ** 2 <= r * r:
                px(img, x, y, color)


def outline(img, color=OUTLINE):
    src = img.copy()
    for y in range(img.height):
        for x in range(img.width):
            if src.getpixel((x, y))[3] == 0 and any(
                    0 <= x + dx < img.width and 0 <= y + dy < img.height and src.getpixel((x + dx, y + dy))[3] > 0
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                img.putpixel((x, y), color)


def strip(frames):
    w, h = frames[0].size
    out = Image.new("RGBA", (w * len(frames), h), (0, 0, 0, 0))
    for i, frame in enumerate(frames):
        out.paste(frame, (i * w, 0))
    return out


def gas_puffs():
    """4 frames 32x24: a green gas puff cluster that churns (tiled along Krügermann's strip)."""
    frames = []
    for f in range(4):
        rnd = random.Random(100 + f)
        img = Image.new("RGBA", (32, 24), (0, 0, 0, 0))
        for i in range(6):
            angle = f * 0.9 + i * 1.1
            cx = 16 + math.cos(angle) * (6 + i % 3 * 2)
            cy = 12 + math.sin(angle * 1.3) * 4
            r = 5 + (i + f) % 3
            disc(img, cx, cy, r, rgb("#4fb84a", 200))
            disc(img, cx - 1, cy - 1, r - 2, rgb("#7fdc5c", 210))
            disc(img, cx - 2, cy - 2, max(1, r - 4), rgb("#c2f59a", 220))
        for _ in range(5):
            px(img, rnd.randrange(32), rnd.randrange(24), rgb("#e8ffd0", 230))
        outline(img, rgb("#24561f", 200))
        frames.append(img)
    return strip(frames)


def gas_arrow():
    """1 frame 12x14: a pale green chevron drifting through Krügermann's gas, pointing right
    (mirrored in the game for gas that blows left) - shows which way the gas blows."""
    img = Image.new("RGBA", (12, 14), (0, 0, 0, 0))
    for i in range(6):
        for t in range(3):                       # 3 px thick chevron arms
            px(img, 2 + i + t, 1 + i, rgb("#ffffff", 245))
            px(img, 2 + i + t, 12 - i, rgb("#ffffff", 245))
    for i in range(6):
        px(img, 2 + i, 1 + i, rgb("#c8f7a8", 245))      # light green inner edge for depth
        px(img, 2 + i, 12 - i, rgb("#c8f7a8", 245))
    outline(img, rgb("#173d14", 240))
    return img


def shield_bubble():
    """2 frames 48x64: Balvan's energy dome with a hexagon shimmer."""
    frames = []
    for f in range(2):
        img = Image.new("RGBA", (48, 64), (0, 0, 0, 0))
        cx, cy, rx, ry = 24, 32, 22, 30
        for y in range(64):
            for x in range(48):
                d = ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2
                if d <= 1.0:
                    edge = d > 0.82
                    hexline = ((x + y // 2 + f * 3) % 6 == 0) or (y % 6 == 0 and (x // 3 + f) % 2 == 0)
                    if edge:
                        img.putpixel((x, y), rgb("#9fe8ff", 230))
                    elif hexline and d > 0.35:
                        img.putpixel((x, y), rgb("#7cc8ff", 120))
                    else:
                        img.putpixel((x, y), rgb("#5ab0ff", 45))
        for sx, sy in ((14 + f, 12), (12 + f, 14), (13 + f, 13)):  # highlight
            px(img, sx, sy, rgb("#ffffff", 255))
        frames.append(img)
    return strip(frames)


def shockwave_ring():
    """6 frames 160x160: Vichr's expanding wind ring (radius up to 76 px at the last frame)."""
    frames = []
    for f in range(6):
        img = Image.new("RGBA", (160, 160), (0, 0, 0, 0))
        r = 14 + f * 12.4
        thickness = max(2, 6 - f)
        alpha = int(255 * (1.0 - f / 7))
        for y in range(160):
            for x in range(160):
                d = math.hypot(x - 80, y - 80)
                if r - thickness <= d <= r:
                    stripe = (int(math.atan2(y - 80, x - 80) * 8) + f) % 3 == 0
                    color = rgb("#ffffff", alpha) if d > r - 1.5 else rgb("#a8f0ff" if stripe else "#5cc8e8", alpha)
                    img.putpixel((x, y), color)
        frames.append(img)
    return strip(frames)


def jet_flame():
    """3 frames 12x18: Jiskra's jetpack exhaust (two nozzles, flame pointing down)."""
    frames = []
    for f in range(3):
        img = Image.new("RGBA", (12, 18), (0, 0, 0, 0))
        for nozzle_x in (3, 8):
            length = 9 + (f + nozzle_x) % 3 * 3
            for y in range(length):
                half = max(0, 2 - y // 4)
                color = rgb("#ffffff") if y < 2 else rgb("#ffe27a") if y < length * 0.45 else rgb("#ff8a3a") if y < length * 0.8 else rgb("#c0392b", 200)
                for dx in range(-half, half + 1):
                    px(img, nozzle_x + dx, y, color)
        frames.append(img)
    return strip(frames)


def teleport_smoke():
    """5 frames 40x40: Stín's purple smoke poof."""
    frames = []
    for f in range(5):
        img = Image.new("RGBA", (40, 40), (0, 0, 0, 0))
        spread = 4 + f * 3
        alpha = int(255 * (1.0 - f / 5.5))
        for i in range(8):
            angle = i * math.tau / 8 + f * 0.3
            cx, cy = 20 + math.cos(angle) * spread, 20 + math.sin(angle) * spread
            r = max(2, 7 - f)
            disc(img, cx, cy, r, rgb("#5b3f8a", alpha))
            disc(img, cx - 1, cy - 1, max(1, r - 2), rgb("#9a74d6", alpha))
        if f < 2:
            disc(img, 20, 20, 6 - f * 2, rgb("#e9dcff", 255))
        frames.append(img)
    return strip(frames)


def line(img, x0, y0, x1, y1, color):
    steps = max(abs(x1 - x0), abs(y1 - y0), 1)
    for i in range(steps + 1):
        px(img, round(x0 + (x1 - x0) * i / steps), round(y0 + (y1 - y0) * i / steps), color)


def nazgul():
    """4 frames 48x56 (drawn at 2x, taller than the players; the body's centre is at x 17):
    an original hooded wraith in a tattered black cloak with a long pale sword, facing right
    (Hobitín). 0-1 hovering (the ragged hem flutters), 2 sword raised behind the head,
    3 slash with a white arc."""
    cloak, fold, light = rgb("#17131f"), rgb("#09070d"), rgb("#2e2740")
    blade, edge, hilt = rgb("#dfe4ec"), rgb("#9ba4b4"), rgb("#6a5238")
    frames = []
    for f in range(4):
        img = Image.new("RGBA", (48, 56), (0, 0, 0, 0))
        rnd = random.Random(210 + (f % 2))
        cx = 17
        for y in range(3, 50):  # hood, then a robe widening towards the hem
            half = math.sqrt(max(0.0, 42.0 - (y - 10) ** 2)) if y < 15 else 6.0 + (y - 15) * 0.32
            for x in range(int(cx - half), int(cx + half) + 1):
                px(img, x, y, cloak)
            px(img, int(cx - half), y, light)  # rim light on the back
        hem = 50
        x = int(cx - 17)
        while x <= cx + 17:  # tattered hem, different every hovering frame
            length = rnd.randrange(2, 7)
            for y in range(hem, hem + length):
                px(img, x, y, cloak)
            px(img, x + 1, hem, cloak)
            x += 2
        for fx, top in ((cx - 4, 22), (cx + 3, 26), (cx - 9, 34)):  # folds
            line(img, fx, top, fx - 1, hem, fold)
        for y in range(7, 14):  # the hood's black opening, facing right, two faint eyes
            for x in range(cx + 1, cx + 6):
                if (x - cx - 3) ** 2 / 6.0 + (y - 10) ** 2 / 10.0 <= 1.0:
                    px(img, x, y, rgb("#000000"))
        px(img, cx + 3, 10, rgb("#b8c8ff", 210)); px(img, cx + 5, 10, rgb("#b8c8ff", 210))
        if f < 2:  # sword held low in front
            line(img, cx + 3, 19, cx + 9, 29, cloak); line(img, cx + 4, 19, cx + 10, 29, cloak)  # sleeve
            line(img, cx + 9, 30, cx + 12, 28, hilt)
            line(img, cx + 11, 31, cx + 19, 50, blade); line(img, cx + 12, 31, cx + 20, 50, edge)
        elif f == 2:  # raised behind the head
            line(img, cx + 2, 19, cx - 2, 6, cloak); line(img, cx + 3, 19, cx - 1, 6, cloak)
            line(img, cx - 4, 5, cx, 5, hilt)
            line(img, cx - 3, 4, cx - 12, 0, blade); line(img, cx - 3, 5, cx - 13, 1, edge)
        else:  # slash: arm and blade forward, a white arc in front
            line(img, cx + 3, 19, cx + 11, 24, cloak); line(img, cx + 3, 20, cx + 11, 25, cloak)
            line(img, cx + 11, 22, cx + 11, 27, hilt)
            line(img, cx + 12, 24, cx + 22, 24, blade); line(img, cx + 12, 25, cx + 22, 25, edge)
            for i in range(28):
                angle = -1.25 + i * 0.09
                ax, ay = cx + 6 + math.cos(angle) * 16, 26 + math.sin(angle) * 22
                px(img, int(ax), int(ay), rgb("#ffffff", 230))
                px(img, int(ax) - 1, int(ay), rgb("#c8d4ff", 150))
        outline(img)
        frames.append(img)
    return strip(frames)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    gas_puffs().save(OUT / "gas_puffs.png")
    gas_arrow().save(OUT / "gas_arrow.png")
    shield_bubble().save(OUT / "shield_bubble.png")
    shockwave_ring().save(OUT / "shockwave_ring.png")
    jet_flame().save(OUT / "jet_flame.png")
    teleport_smoke().save(OUT / "teleport_smoke.png")
    nazgul().save(OUT / "nazgul.png")
    print(f"Wrote ability effects to {OUT}")


if __name__ == "__main__":
    main()
