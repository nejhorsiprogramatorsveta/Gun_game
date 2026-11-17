"""Bibi's hand-drawn pixel sprite, following the user's stylized pixel-art reference.

Uses the existing 32x40 body/portrait anchors; the game draws the gun arm separately.
No reference image is copied, read by the generator or bundled with the game.
"""

from reference_characters import legs, palette, pixels, suit


BIBI = palette(
    d="656776", h="8b8f98", H="c1c4c9", s="f0b887", l="ffd3a1", t="d99b72",
    n="b47c5f", w="f5f4ed", e="49657b", k="47414a", b="252936", B="383e50",
    c="4b5366", v="171b27", z="11151e", p="292d3b", P="404658", f="141720",
    F="51535c", T="548bd2", U="8fc5f5", W="dce9f4",
)

# Receding silver hair, a broad forehead, strong eyebrows and a clean-shaven jaw.
# The eyes stay within the same first-frame HUD portrait crop as the other characters.
HEAD = (
    ".....HHHHHH.....",
    "...HHHHhHhhH....",
    "..HHhhHhhtttt...",
    ".HHhHhhhtsssss..",
    ".HhHhhhtsslllss.",
    ".HhHhhtssllllss.",
    ".HhHhhtssssssst.",
    ".HhHhhtsnnssnns.",
    ".HhHhtsskksskkst",
    ".dHhhtsswesswest",
    "..dhtssssstlssst",
    "..tstssssstlnsst",
    "..tstssssssntst.",
    "...ttssssnnsst..",
    "....tssssssst...",
    ".....ntttttt....",
)


def draw_bibi(c, p: dict, overrides: dict | None = None) -> None:
    """Draw one animation pose; skin overrides use the existing palette-letter format."""
    colors = dict(BIBI)
    if overrides:
        colors.update(palette(**overrides))
    bob, lean = p["bob"], p["lean"]
    legs(c, colors, p)
    c.rect(14 + lean, 16 + bob, 19 + lean, 19 + bob, colors["t"], shaded=False)
    suit(c, colors, bob, lean)
    # Jacket pocket and buttons distinguish the silhouette from Architekt's suit.
    c.rect(19 + lean, 23 + bob, 21 + lean, 23 + bob, colors["c"], shaded=False)
    c.px(17 + lean, 28 + bob, colors["z"])
    c.px(17 + lean, 30 + bob, colors["z"])
    pixels(c, HEAD, colors, 8 + lean, 2 + bob)
    c.outline()
