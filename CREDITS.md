# Credits a licence assetů

Každý cizí asset musí mít v tomto souboru uvedený zdroj a licenci. Vlastní kód, grafika a zvuky projektu jsou pod licencí PolyForm Noncommercial 1.0.0 (soubor `LICENSE`): jen nekomerční použití.

| Asset | Soubor | Autor / zdroj | Licence |
|---|---|---|---|
| Pixelové písmo Jersey 15 (hlavní písmo hry od 0.2.7; nahradilo Pixelify Sans kvůli nečitelným číslicím) | `assets/fonts/Jersey15.ttf` | The Soft Type Project Authors, https://github.com/scfried/soft-type-jersey (přes https://github.com/google/fonts/tree/main/ofl/jersey15) | SIL Open Font License 1.1 (`assets/fonts/Jersey15-OFL.txt`) |
| Font Noto Sans (variabilní, dřívější písmo, zůstává v projektu) | `assets/fonts/NotoSans.ttf` | The Noto Project Authors, https://github.com/google/fonts/tree/main/ofl/notosans | SIL Open Font License 1.1 (`assets/fonts/OFL.txt`) |
| Herní engine Godot | (součást každého buildu) | Juan Linietsky, Ariel Manzur a přispěvatelé Godotu, https://godotengine.org | MIT, https://godotengine.org/license |

| Pixel art postav a zbraní | `assets/sprites/characters/*.png`, `assets/sprites/weapons/*.png` | vlastní pixelová kresba projektu, generuje `tools/art/generate_sprites.py`; Krügermanna ve svetru a Architekta v obleku kreslí `tools/art/reference_characters.py` podle stylizovaných předloh dodaných uživatelem | PolyForm Noncommercial 1.0.0 (jako zbytek projektu) |

| Pixel art efektů schopností (plyn, štít, tlaková vlna, úskok, kouř) | `assets/sprites/effects/*.png` | vlastní tvorba projektu, generuje `tools/art/generate_effects.py` | PolyForm Noncommercial 1.0.0 (jako zbytek projektu) |
| Pixel art map, pozadí a UI (dlaždice, 3 pozadí, mraky, logo, rámečky tlačítek a panelů) | `assets/sprites/tiles/*.png`, `assets/backgrounds/*.png`, `assets/ui/*.png`, `assets/ui/theme.tres` | vlastní tvorba projektu, generuje `tools/art/generate_world.py` (procedurálně, pevná semínka, bez cizích obrázků) | PolyForm Noncommercial 1.0.0 (jako zbytek projektu) |

Postavy nevycházejí z fotografií skutečných lidí. Krügermann a Architekt jsou samostatné pixelové kresby
podle stylizovaných předloh dodaných uživatelem; referenční obrázky se do hry nebalí. Ostatní postavy,
mapy a UI jsou originální návrhy projektu.
