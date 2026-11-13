#!/usr/bin/env python3
"""Generates the game's original pixel-art sprites (dev tool, PLAN.md Q).

Run from the project root:  python3 tools/art/generate_sprites.py   (needs Pillow)
Writes PNG sprite sheets to assets/sprites/; commit them and run the Godot import.
Art is drawn here and in reference_characters.py pixel by pixel; no image files are copied.

Character sheet: 10 frames of 32x40 px in one row, facing right, feet on the bottom row:
  0-1 idle, 2-5 walk, 6 jump, 7 fall, 8-9 shoot (recoil lean).
The front arm and gun are a separate weapon sprite (rotated towards the mouse in game).
Weapon sheet: 2 frames of 34x12 px (normal, muzzle flash); the grip/hand is at (4, 6).
"""

from pathlib import Path
from PIL import Image
from reference_characters import draw_reference_character

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "sprites"
FW, FH = 32, 40
WW, WH = 34, 12
OUTLINE = (18, 14, 22, 255)
FRAMES = ["idle0", "idle1", "walk0", "walk1", "walk2", "walk3", "jump", "fall", "shoot0", "shoot1"]


def rgb(hex_color: str, alpha: int = 255) -> tuple:
    hex_color = hex_color.lstrip("#")
    return tuple(int(hex_color[i:i + 2], 16) for i in (0, 2, 4)) + (alpha,)


def shade(color: tuple, factor: float) -> tuple:
    return tuple(max(0, min(255, int(c * factor))) for c in color[:3]) + (color[3],)


class Canvas:
    def __init__(self, width: int, height: int):
        self.img = Image.new("RGBA", (width, height), (0, 0, 0, 0))
        self.w, self.h = width, height

    def px(self, x: int, y: int, color: tuple) -> None:
        if 0 <= x < self.w and 0 <= y < self.h:
            self.img.putpixel((x, y), color)

    def rect(self, x0: int, y0: int, x1: int, y1: int, color: tuple, shaded: bool = True) -> None:
        """Filled rectangle (inclusive) with a light top-left and dark bottom-right edge."""
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                c = color
                if shaded and x1 - x0 >= 2 and y1 - y0 >= 2:
                    if x == x1 or y == y1:
                        c = shade(color, 0.72)
                    elif x == x0 or y == y0:
                        c = shade(color, 1.18)
                self.px(x, y, c)

    def outline(self) -> None:
        """Dark 1-px outline around everything drawn (the pixel-art look of PLAN.md Q)."""
        src = self.img.copy()
        for y in range(self.h):
            for x in range(self.w):
                if src.getpixel((x, y))[3] != 0:
                    continue
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < self.w and 0 <= ny < self.h and src.getpixel((nx, ny))[3] != 0:
                        self.img.putpixel((x, y), OUTLINE)
                        break


# --- Characters --------------------------------------------------------------------

def pose(frame: str) -> dict:
    """Leg/body offsets of one animation frame."""
    p = {"bob": 0, "lean": 0, "legs": ((12, 0), (17, 0)), "leg_len": 7}
    if frame == "idle1":
        p["bob"] = 1
    elif frame == "walk0":
        p["legs"] = ((10, 0), (19, 0))
        p["bob"] = -1
    elif frame == "walk1":
        p["legs"] = ((13, 0), (16, -1))
    elif frame == "walk2":
        p["legs"] = ((19, 0), (10, 0))
        p["bob"] = -1
    elif frame == "walk3":
        p["legs"] = ((16, -1), (13, 0))
    elif frame == "jump":
        p["legs"] = ((11, -3), (17, -2))
        p["leg_len"] = 5
        p["bob"] = -2
    elif frame == "fall":
        p["legs"] = ((10, -1), (19, -1))
        p["bob"] = -1
    elif frame in ("shoot0", "shoot1"):
        p["lean"] = -1 if frame == "shoot0" else -2
    return p


def draw_character(c: Canvas, spec: dict, frame: str) -> None:
    p = pose(frame)
    pal = spec["palette"]
    bob, lean = p["bob"], p["lean"]
    top = 38 - p["leg_len"]  # top of the legs
    # Things behind the body (weapon on the back, gas tank, ponytail ...).
    spec["back"](c, pal, bob, lean)
    # Legs and feet.
    for x, lift in p["legs"]:
        c.rect(x, top + lift, x + 2, 37 + lift, pal["legs"])
        c.rect(x, 38 + lift, x + 3, 39 + lift, pal["feet"], shaded=False)
    # Torso.
    tx = 11 + lean
    c.rect(tx, 19 + bob, tx + 9, top + 1 + bob, pal["body"])
    c.rect(tx, 26 + bob, tx + 9, 27 + bob, pal["belt"], shaded=False)
    # Back arm (the front arm belongs to the weapon sprite).
    c.rect(tx - 2, 20 + bob, tx, 27 + bob, shade(pal["body"], 0.8))
    c.rect(tx - 2, 28 + bob, tx, 29 + bob, pal["hand"], shaded=False)
    # Head.
    hx = 12 + lean
    c.rect(hx, 9 + bob, hx + 7, 18 + bob, pal["skin"])
    spec["head"](c, pal, hx, 9 + bob)
    spec["front"](c, pal, tx, bob)
    c.outline()


def eyes(c: Canvas, x: int, y: int, color=(30, 24, 30, 255)) -> None:
    c.px(x + 5, y + 4, color)
    c.px(x + 7, y + 4, color)


def jiskra_back(c, pal, bob, lean):  # jetpack with two nozzles on the back, ponytail
    c.rect(5 + lean, 18 + bob, 10 + lean, 28 + bob, pal["jetpack"])
    c.rect(5 + lean, 21 + bob, 10 + lean, 22 + bob, pal["accent"], shaded=False)  # red stripe
    c.rect(5 + lean, 29 + bob, 6 + lean, 30 + bob, pal["nozzle"], shaded=False)
    c.rect(9 + lean, 29 + bob, 10 + lean, 30 + bob, pal["nozzle"], shaded=False)
    c.rect(9 + lean, 10 + bob, 11 + lean, 19 + bob, pal["hair"])


def jiskra_head(c, pal, x, y):
    c.rect(x, y, x + 7, y + 3, pal["hair"])                  # hair
    c.rect(x + 3, y + 2, x + 8, y + 7, pal["mask"])           # kitsune mask, snout to the right
    c.px(x + 8, y + 6, pal["accent"])
    c.px(x + 5, y + 4, pal["accent"]); c.px(x + 7, y + 4, pal["accent"])
    c.px(x + 4, y + 1, pal["mask"]); c.px(x + 7, y + 1, pal["mask"])  # fox ears
    c.px(x + 4, y, pal["accent"]); c.px(x + 7, y, pal["accent"])


def jiskra_front(c, pal, tx, bob):
    c.rect(tx + 2, 19 + bob, tx + 4, 25 + bob, pal["trim"], shaded=False)  # kimono collar


def balvan_back(c, pal, bob, lean):  # big shoulder plates (sode)
    c.rect(7 + lean, 18 + bob, 11 + lean, 25 + bob, pal["armor_dark"])


def balvan_head(c, pal, x, y):
    c.rect(x - 1, y - 1, x + 8, y + 3, pal["armor"])          # kabuto helmet
    c.rect(x - 2, y + 3, x + 9, y + 4, pal["armor_dark"])     # helmet brim
    c.px(x + 3, y - 2, pal["gold"]); c.px(x + 6, y - 2, pal["gold"])  # crest (maedate)
    c.px(x + 2, y - 3, pal["gold"]); c.px(x + 7, y - 3, pal["gold"])
    c.rect(x + 3, y + 6, x + 8, y + 9, pal["menpo"], shaded=False)   # face guard
    eyes(c, x, y + 1)


def balvan_front(c, pal, tx, bob):
    for row in (20, 23):                                         # lacing on the cuirass
        c.rect(tx + 1, row + bob, tx + 8, row + bob, pal["gold"], shaded=False)


def vichr_back(c, pal, bob, lean):  # scarf tail and kusarigama chain
    c.rect(6 + lean, 18 + bob, 10 + lean, 19 + bob, pal["scarf"], shaded=False)
    c.rect(5 + lean, 20 + bob, 7 + lean, 21 + bob, pal["scarf"], shaded=False)
    for i in range(5):
        c.px(21 + lean, 27 + i + bob, pal["chain"])
    c.rect(20 + lean, 32 + bob, 23 + lean, 32 + bob, pal["chain"], shaded=False)


def vichr_head(c, pal, x, y):
    c.rect(x, y, x + 7, y + 9, pal["body"])                    # hood
    c.rect(x + 3, y + 3, x + 8, y + 5, pal["skin"], shaded=False)  # eye slit
    eyes(c, x, y)
    c.rect(x, y + 8, x + 7, y + 9, pal["scarf"], shaded=False)


def vichr_front(c, pal, tx, bob):
    c.rect(tx + 1, 19 + bob, tx + 8, 20 + bob, pal["scarf"], shaded=False)


def stin_back(c, pal, bob, lean):  # big four-point shuriken on the back
    cx, cy = 9 + lean, 22 + bob
    for i in range(-5, 6):
        c.px(cx + i, cy, pal["steel"]); c.px(cx, cy + i, pal["steel"])
    for i in range(-2, 3):
        c.px(cx + i, cy + 1, pal["steel"]); c.px(cx + 1, cy + i, pal["steel"])
    c.px(cx, cy, pal["accent"])


def stin_head(c, pal, x, y):
    c.rect(x, y, x + 7, y + 9, pal["body"])
    c.rect(x + 2, y + 4, x + 8, y + 4, pal["accent"], shaded=False)  # headband
    c.px(x + 5, y + 5, (230, 230, 240, 255)); c.px(x + 7, y + 5, (230, 230, 240, 255))  # eyes
    c.rect(x - 2, y + 3, x - 1, y + 3, pal["accent"], shaded=False)  # headband tails
    c.px(x - 3, y + 4, pal["accent"])


def stin_front(c, pal, tx, bob):
    pass


SKIN = rgb("#f1c6a0")
CHARACTERS = {
    "jiskra": {"palette": {"body": rgb("#c0392b"), "legs": rgb("#3a3a4a"), "feet": rgb("#1e1e26"),
                           "belt": rgb("#e0b84a"), "hand": SKIN, "skin": SKIN, "hair": rgb("#2b1d2e"),
                           "mask": rgb("#f4f1ea"), "accent": rgb("#d9433b"), "jetpack": rgb("#8a8f99"), "nozzle": rgb("#3a3d44"),
                           "trim": rgb("#f4f1ea")},
               "back": jiskra_back, "head": jiskra_head, "front": jiskra_front},
    "balvan": {"palette": {"body": rgb("#3d4e66"), "legs": rgb("#2a3648"), "feet": rgb("#1b222e"),
                           "belt": rgb("#e5b63c"), "hand": rgb("#2a3648"), "skin": SKIN, "armor": rgb("#5c7491"),
                           "armor_dark": rgb("#2a3648"), "gold": rgb("#e5b63c"), "menpo": rgb("#7a2c2c")},
               "back": balvan_back, "head": balvan_head, "front": balvan_front},
    "vichr": {"palette": {"body": rgb("#2f6f73"), "legs": rgb("#1f4b4e"), "feet": rgb("#16302f"),
                          "belt": rgb("#1f4b4e"), "hand": rgb("#1f4b4e"), "skin": SKIN, "scarf": rgb("#e07b39"),
                          "chain": rgb("#a8adb5")},
              "back": vichr_back, "head": vichr_head, "front": vichr_front},
    "stin": {"palette": {"body": rgb("#2b2540"), "legs": rgb("#1b1729"), "feet": rgb("#100d18"),
                         "belt": rgb("#463d66"), "hand": rgb("#1b1729"), "skin": SKIN, "steel": rgb("#c9ced6"),
                         "accent": rgb("#8e5cd9")},
             "back": stin_back, "head": stin_head, "front": stin_front},
    "krugermann": {"reference": True},
    "architekt": {"reference": True},
}


# Skins (user 2026-11-13: one per character and one per weapon in use): original palettes
# of the same drawings, saved as <name>_skin.png next to the normal sheets.
#   jiskra "Sakura", balvan "Zlatý šógun", vichr "Bouře", stin "Rudý stín",
#   krugermann "Sváteční svetr" (palette letters), architekt "Bílý oblek" (palette letters)
CHARACTER_SKINS = {
    "jiskra": {"body": "#e58fb0", "accent": "#b8326a", "belt": "#f4d36b", "jetpack": "#d9dde6",
               "trim": "#fff4fa", "hair": "#4a2238", "nozzle": "#8a5a6e"},
    "balvan": {"body": "#1d1c22", "legs": "#2b2a31", "feet": "#121116", "armor": "#c9a23a",
               "armor_dark": "#7a5a18", "gold": "#fff0a8", "menpo": "#a01f2a", "belt": "#a01f2a", "hand": "#2b2a31"},
    "vichr": {"body": "#dfe3ea", "legs": "#8f99ab", "feet": "#4c5466", "belt": "#8f99ab", "hand": "#8f99ab",
              "scarf": "#3fa9f5", "chain": "#f2d16b"},
    "stin": {"body": "#6e1a24", "legs": "#3a0d14", "feet": "#1e070b", "belt": "#a8323e", "hand": "#3a0d14",
             "accent": "#f2c94c", "steel": "#f2e2b0"},
    "krugermann": {"b": "8c1d2a", "B": "b02a36", "c": "d64a52", "v": "5a1019", "r": "f2d16b", "R": "b8902e",
                   "z": "2f6b34", "Z": "5aa05e"},
    "architekt": {"b": "dcd6ca", "B": "f0ebe0", "c": "c8c0b2", "v": "8e8679", "p": "cfc8bb", "P": "e8e2d6",
                  "T": "a3232c", "U": "d04048", "F": "8a6a4a", "f": "3a2a20"},
}


def skin_spec(name: str) -> dict:
    """The character spec with the skin's palette (generated characters)."""
    spec = dict(CHARACTERS[name])
    spec["palette"] = dict(spec["palette"])
    for key, value in CHARACTER_SKINS[name].items():
        spec["palette"][key] = rgb(value)
    return spec


# --- Weapons -----------------------------------------------------------------------

def draw_weapon(c: Canvas, spec: dict, flash: bool) -> None:
    """Gun pointing right; hand/grip at (4, 6). Shapes: barrel length, stock, magazine."""
    metal, wood, hand = rgb(spec.get("metal", "#4a4f5a")), rgb(spec.get("wood", "#6b4a2e")), rgb("#f1c6a0")
    length = spec["length"]
    c.rect(4, 4, 4 + spec["body"], 7, metal)                     # receiver
    c.rect(4 + spec["body"], 5, 4 + length, 6, shade(metal, 1.1), shaded=False)  # barrel
    if spec.get("stock"):
        c.rect(0, 5, 4, 7, wood)
    if spec.get("mag"):
        c.rect(7, 8, 8, 8 + spec["mag"], metal)
    if spec.get("scope"):
        c.rect(7, 2, 12, 3, rgb("#22252b"))
    if spec.get("double"):
        c.rect(4 + spec["body"], 4, 4 + length, 4, shade(metal, 1.2), shaded=False)
    if spec.get("box"):                                          # big ammo box under the receiver
        c.rect(7, 8, 12, 10, rgb(spec["box"]))
    if spec.get("bipod"):                                        # folded-out bipod near the muzzle
        bx = 4 + length - 5
        for i in range(4):
            c.px(bx - i, 7 + i, shade(metal, 0.9))
            c.px(bx + i, 7 + i, shade(metal, 0.9))
    if spec.get("shroud"):                                       # thick perforated barrel shroud
        c.rect(4 + spec["body"], 4, length, 7, shade(metal, 1.05))
        for x in range(6 + spec["body"], length, 2):
            c.px(x, 5, shade(metal, 0.55))
            c.px(x, 6, shade(metal, 0.55))
    if spec.get("pattern"):
        PATTERNS[spec["pattern"]](c, spec)
    c.rect(3, 6, 5, 8, hand, shaded=False)                       # front hand on the grip
    if flash:
        mx = 5 + length
        for dx, dy in ((0, 0), (1, 0), (2, 0), (1, -1), (1, 1), (3, 0), (0, -1), (0, 1)):
            c.px(mx + dx, 5 + dy, rgb("#ffe27a"))
        c.px(mx + 1, 5, rgb("#ffffff"))
    c.outline()


def pattern_dragon(c, spec):
    """Dračí svitek: a gold Japanese dragon winding along black lacquer, red eye and pearl."""
    gold, light, red = rgb("#e5b63c"), rgb("#fff0a8"), rgb("#c0392b")
    for x in range(1, 4 + spec["length"] - 2):
        y = 5 + (1 if (x // 3) % 2 else 0)  # the dragon's body waves along the gun
        c.px(x, y, gold)
        if x % 3 == 0:
            c.px(x, y - 1 if y == 6 else y + 1, light)  # scales
    head = 4 + spec["body"] - 1
    c.px(head, 4, gold); c.px(head + 1, 4, gold); c.px(head + 1, 3, light)  # horn
    c.px(head, 5, red)  # eye
    c.px(1, 5, red); c.px(2, 6, red)  # the flaming pearl at the stock
    c.rect(7, 2, 12, 2, gold, shaded=False)  # gold scope rings
    c.px(7, 3, gold); c.px(12, 3, gold)


def pattern_sakura(c, spec):
    for x, y in ((6, 5), (9, 6), (11, 4), (14, 5)):
        c.px(x, y, rgb("#fff4fa")); c.px(x + 1, y, rgb("#f7b8d0"))


def pattern_camo(c, spec):
    for x, y in ((5, 4), (8, 6), (11, 5), (14, 4), (17, 6), (20, 5), (1, 6)):
        c.px(x, y, rgb("#8a94a6")); c.px(x + 1, y, rgb("#b7bfcc"))


def pattern_lightning(c, spec):
    blue, white = rgb("#3fa9f5"), rgb("#d6f0ff")
    for i, (x, y) in enumerate(((5, 4), (6, 5), (7, 6), (8, 5), (9, 4), (10, 5), (11, 6), (12, 5), (13, 4), (14, 5))):
        c.px(x, y, white if i % 3 == 0 else blue)


def pattern_engraving(c, spec):
    for x in range(5, 4 + spec["body"]):
        if x % 2:
            c.px(x, 5, rgb("#fff0a8"))
    c.px(1, 6, rgb("#e5b63c")); c.px(2, 5, rgb("#e5b63c"))


def pattern_gold(c, spec):
    for x in range(5, 4 + spec["body"], 3):
        c.px(x, 5, rgb("#fff0a8"))


PATTERNS = {"dragon": pattern_dragon, "sakura": pattern_sakura, "camo": pattern_camo,
            "lightning": pattern_lightning, "engraving": pattern_engraving, "gold": pattern_gold}

# Weapon skins of the six weapons in use: overrides of the WEAPONS spec (+ a pattern).
WEAPON_SKINS = {
    "heavy_machine_gun": {"metal": "#b8902e", "box": "#8a1f2a", "wood": "#2a2026", "pattern": "gold"},  # Zlatý šógun
    "smg": {"metal": "#d97aa0", "pattern": "sakura"},                                                  # Sakura
    "light_machine_gun": {"metal": "#d9dee6", "wood": "#9aa3b2", "pattern": "camo"},                   # Zimní maskování
    "sniper": {"metal": "#1a1418", "wood": "#24161a", "pattern": "dragon"},                           # Dračí svitek
    "battle_rifle": {"metal": "#22304a", "wood": "#1a2236", "pattern": "lightning"},                   # Bouře
    "double_barrel": {"metal": "#c9a23a", "wood": "#7a2e1c", "pattern": "engraving"},                  # Mahagon a zlato
}

WEAPONS = {
    "pistol": {"body": 5, "length": 9},
    "smg": {"body": 8, "length": 13, "mag": 3},
    "compact_smg": {"body": 7, "length": 11, "mag": 3},
    "assault_rifle": {"body": 10, "length": 19, "stock": True, "mag": 3},
    "battle_rifle": {"body": 11, "length": 21, "stock": True, "mag": 2, "metal": "#3d3a34"},
    "carbine": {"body": 9, "length": 16, "stock": True, "mag": 2},
    "light_machine_gun": {"body": 12, "length": 21, "stock": True, "mag": 2, "metal": "#3f4a3a"},
    "heavy_machine_gun": {"body": 13, "length": 24, "stock": True, "box": "#5e5a2c", "bipod": True, "shroud": True,
                          "metal": "#353a40"},
    "sniper": {"body": 10, "length": 23, "stock": True, "scope": True},
    "shotgun": {"body": 9, "length": 18, "stock": True},
    "double_barrel": {"body": 8, "length": 17, "stock": True, "double": True},
    "revolver": {"body": 6, "length": 10, "metal": "#7a7f8a"},
    "nail_gun": {"body": 8, "length": 11, "metal": "#c9a03c"},
}


def main() -> None:
    (OUT / "characters").mkdir(parents=True, exist_ok=True)
    (OUT / "weapons").mkdir(parents=True, exist_ok=True)
    for name, spec in CHARACTERS.items():
        for skin in (False, True):
            sheet = Image.new("RGBA", (FW * len(FRAMES), FH), (0, 0, 0, 0))
            for i, frame in enumerate(FRAMES):
                canvas = Canvas(FW, FH)
                if spec.get("reference"):
                    draw_reference_character(canvas, name, pose(frame), CHARACTER_SKINS[name] if skin else None)
                else:
                    draw_character(canvas, skin_spec(name) if skin else spec, frame)
                sheet.paste(canvas.img, (i * FW, 0))
            sheet.save(OUT / "characters" / f"{name}{'_skin' if skin else ''}.png")
    for name, spec in WEAPONS.items():
        for skin in (False, True):
            if skin and name not in WEAPON_SKINS:
                continue
            sheet = Image.new("RGBA", (WW * 2, WH), (0, 0, 0, 0))
            for i, flash in enumerate((False, True)):
                canvas = Canvas(WW, WH)
                draw_weapon(canvas, dict(spec, **WEAPON_SKINS[name]) if skin else spec, flash)
                sheet.paste(canvas.img, (i * WW, 0))
            sheet.save(OUT / "weapons" / f"{name}{'_skin' if skin else ''}.png")
    print(f"Wrote {len(CHARACTERS)} character and {len(WEAPONS)} weapon sheets (+ skins) to {OUT}")


if __name__ == "__main__":
    main()
