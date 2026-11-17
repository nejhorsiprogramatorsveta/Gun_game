"""Bibi's hand-drawn pixel sprite, following the user's stylized pixel-art reference.

Uses the existing 32x40 body/portrait anchors; the game draws the gun arm separately.
No reference image is copied, read by the generator or bundled with the game.
"""

from reference_characters import legs, palette, pixels, suit


BIBI = palette(
    d="686b72", h="989b9f", H="d5d7d6", s="f0b887", l="ffd3a1", t="d99b72",
    n="bd896a", w="fff5e9", e="6d9aba", E="304b5b", k="4c3b33", q="dca17b",
    r="b5826b", b="252936", B="383e50",
    c="4b5366", v="171b27", z="11151e", p="292d3b", P="404658", f="141720",
    F="51535c", T="548bd2", U="8fc5f5", W="dce9f4",
)

# Broad, high forehead framed by swept-back silver hair, heavy angled eyebrows,
# pale-blue eyes, long nose, lined cheeks and a wide clean-shaven jaw. A near-frontal
# three-quarter face follows the portrait rather than reducing it to a generic profile.
# The eyes and jaw stay in the unchanged HUD portrait crop (8, 4, 16, 16).
HEAD = (
    ".....HHHHHH.....",
    "...HHHhHHhHHH...",
    "..HHhHhHHHhHhH..",
    ".HhHhssllllhHHh.",
    ".HhhtsllllllshH.",
    ".HhhtsqqqqllthH.",
    ".HhhtsllllllthH.",
    ".HhhtkkllsskkhH.",
    "tHhtskkkstkkkstt",
    "tnttswEetswEetnt",
    "tnttstqqslqqstnt",
    ".tttsstqsltnstt.",
    "..ttssltsltnstt.",
    "..ttsnsttnnsst..",
    "...tssnsssnqst..",
    "...ttssrrrsstt..",
    "....ttsslsstt...",
    ".....ntttttn....",
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
    head_colors = dict(colors, s=(239, 180, 135, 255), l=(255, 208, 160, 255), t=(215, 151, 112, 255))
    pixels(c, HEAD, head_colors, 8 + lean, 2 + bob)
    c.outline()
