"""Pixel-drawn Krugermann and Architekt, following the user's stylized references.

Called by generate_sprites.py; keeps its 32x40 frames, pose offsets and separate gun arm.
The supplied reference images are not read, copied into the project or shipped.
"""


def palette(**colors: str) -> dict:
    return {key: tuple(bytes.fromhex(value)) + (255,) for key, value in colors.items()}


SWEATER = palette(
    d="3c3029", h="69513d", H="96765a", s="ffca92", l="ffdbac", t="eaa36e",
    n="b97b53", w="fff2db", e="35536c", k="302725", b="292938", B="39384b",
    c="4b4b5d", v="1c1c29", z="a68e60", Z="e1cb89", r="c44832", R="87342d",
    p="282737", P="363546", f="17171f", F="5e5551",
)
SUIT = palette(
    d="48382f", h="6e5948", H="99816a", s="fac18a", l="ffd49c", t="e49c64",
    n="bd7c50", w="f6edda", e="322722", k="3b302a", b="342e2f", B="494041",
    c="564b49", v="231f23", z="88766a", Z="b6a28a", p="342d2e", P="473d3d",
    f="171517", F="6a5148", T="30313e", U="47495a", W="d2c8b8",
)

# Clustered hair/skin shading, eyes, nose and jaw, at the same pixel scale as the body.
# Faces stay inside the HUD's first-frame portrait region (8, 4, 16, 16).
SWEATER_HEAD = (
    ".....hHHhh......",
    "...hhHhhHhh.....",
    "..dhhhdhHhhhhd..",
    ".dhhdhhhHhhhhdd.",
    ".dhhhdhhtssssth.",
    ".dhhhtssssllsst.",
    ".dhhtsssllllssst",
    ".dhtsssnnnssnnst",
    ".htsssswessswest",
    ".tstssssekssest.",
    ".lstssssssstlst.",
    ".ttssssssstnstt.",
    "..tssssstnnssst.",
    "...tssssssssst..",
    "....ntssssttt...",
    ".....nnnttt.....",
)
SUIT_HEAD = (
    ".......H..H.....",
    "...HHhhhdhH..H..",
    ".H..hHHhhdhhHhd.",
    "..hHhhHhhdhhhdH.",
    ".HhHhhdhhhtsshd.",
    "HhhHhdhhhtsslshd",
    ".hHhdhhhtsslsstd",
    "Hhhdhhdtsnsssnst",
    ".dhhhdtsnnnssnnt",
    ".dhhdtsswkssswkt",
    "..dhtssssesssest",
    "..dttssssstnstst",
    "...tssssnkkkntst",
    "....tssnkhhkntt.",
    ".....tsskssktt..",
    ".....ntsssstt...",
)


def pixels(c, rows: tuple, colors: dict, x: int, y: int) -> None:
    for dy, row in enumerate(rows):
        for dx, key in enumerate(row):
            if key != ".":
                c.px(x + dx, y + dy, colors[key])


def legs(c, colors: dict, p: dict) -> None:
    """Trousers with a lit front seam; standing soles keep the sheet's bottom anchor."""
    top = 29 if p["leg_len"] == 7 else 30
    for index, (x, lift) in enumerate(p["legs"]):
        x += -1 if index == 0 else 1
        c.rect(x, top + lift, x + 3, 38 + lift, colors["p"], shaded=False)
        c.rect(x, top + 1 + lift, x, 36 + lift, colors["P"], shaded=False)
        c.rect(x, 38 + lift, x + 4, 39 + lift, colors["f"], shaded=False)
        c.rect(x, 38 + lift, x + 4, 38 + lift, colors["F"], shaded=False)


def sweater(c, colors: dict, bob: int, lean: int) -> None:
    x, y = 10 + lean, 18 + bob
    # Navy zip sweater: high collar, ribbed cuffs/hem, small red chest emblem.
    c.rect(x, y + 1, x + 11, y + 11, colors["b"], shaded=False)
    c.rect(x, y + 1, x + 2, y + 7, colors["B"], shaded=False)
    c.rect(x - 2, y + 2, x, y + 9, colors["b"], shaded=False)
    c.rect(x - 2, y + 5, x - 1, y + 7, colors["B"], shaded=False)
    c.rect(x - 2, y + 9, x, y + 10, colors["c"], shaded=False)
    c.rect(x - 2, y + 11, x + 1, y + 13, colors["s"], shaded=False)
    c.rect(x - 2, y + 11, x - 1, y + 12, colors["l"], shaded=False)
    c.rect(x - 2, y + 13, x + 1, y + 13, colors["t"], shaded=False)
    pixels(c, (".cbb....bc..", ".bbc...cbb..", "..bbc.cbb...", "...bbZbb...."), colors, x, y - 1)
    c.rect(x + 6, y + 3, x + 6, y + 11, colors["z"], shaded=False)
    c.rect(x + 6, y + 3, x + 6, y + 5, colors["Z"], shaded=False)
    c.rect(x, y + 10, x + 5, y + 11, colors["v"], shaded=False)
    c.rect(x + 7, y + 10, x + 11, y + 11, colors["v"], shaded=False)
    pixels(c, (".r.", "rRr", ".R.", ".r."), colors, x + 8, y + 3)


def suit(c, colors: dict, bob: int, lean: int) -> None:
    x, y = 10 + lean, 18 + bob
    # Charcoal jacket, cream shirt, navy tie and angular lapels from the reference.
    c.rect(x, y + 1, x + 11, y + 12, colors["b"], shaded=False)
    c.rect(x - 1, y + 1, x + 2, y + 4, colors["B"], shaded=False)
    c.rect(x - 2, y + 2, x, y + 10, colors["b"], shaded=False)
    c.rect(x - 3, y + 7, x - 1, y + 10, colors["B"], shaded=False)
    c.rect(x - 2, y + 11, x, y + 11, colors["w"], shaded=False)
    c.rect(x - 2, y + 12, x + 1, y + 13, colors["s"], shaded=False)
    c.rect(x - 2, y + 12, x - 1, y + 12, colors["l"], shaded=False)
    pixels(c, (
        "..vwwwwwwv..", "..BvwwTwwv..", "...BvWTWv...", "...vBWUWv...",
        "....vWUWv...", "....bWTWv...", "....bTTTb...", ".....TTTb...",
        ".....vTvb...", "......vzb...", "......vbb...",
    ), colors, x, y - 1)
    c.rect(x + 9, y + 3, x + 10, y + 10, colors["v"], shaded=False)
    c.rect(x, y + 12, x + 11, y + 12, colors["v"], shaded=False)


def draw_reference_character(c, name: str, p: dict, overrides: dict | None = None) -> None:
    """overrides: palette letters -> "rrggbb" (a skin, generate_sprites.CHARACTER_SKINS)."""
    colors = dict(SWEATER if name == "krugermann" else SUIT)
    if overrides:
        colors.update(palette(**overrides))
    bob, lean = p["bob"], p["lean"]
    legs(c, colors, p)
    c.rect(14 + lean, 16 + bob, 19 + lean, 19 + bob, colors["t"], shaded=False)
    if name == "krugermann":
        sweater(c, colors, bob, lean)
    else:
        suit(c, colors, bob, lean)
    head = SWEATER_HEAD if name == "krugermann" else SUIT_HEAD
    pixels(c, head, colors, 8 + lean, 2 + bob)
    c.outline()
