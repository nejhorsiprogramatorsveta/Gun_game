# Návod: úpravy postav, zbraní, schopností a textů

Většinu hry jde měnit bez programování, jen úpravou datových souborů. Tento návod popisuje, kde co je
a na co si dát pozor.

## Základní pravidla

- **Data** jsou v souborech `.tres` ve složce `data/`. Jsou to obyčejné textové soubory (`klíč = hodnota`),
  dají se upravit ve VS Code nebo v editoru Godotu (`tools/godot --path . --editor`, soubor otevřít dvojklikem
  a měnit ve formuláři vpravo).
- **Texty** pro hráče jsou jen v `localization/translations.csv` (sloupce `keys,cs`). V kódu ani v datech
  nikdy nepiš český text přímo, jen klíč (např. `CHARACTER_STIN_NAME`).
- **Po každé změně** spusť kontroly (viz konec návodu). Testy hlídají třeba limity odhozu.
- **Všichni hráči musí mít stejnou verzi.** Každá změna hry = nová verze, kterou kamarádům nabídne
  automatická aktualizace (viz „Vydání změny“).

## Postavy – `data/characters/*.tres`

Každý soubor je jedna postava. Hra je načte sama: **novou postavu přidáš jen novým souborem a dvěma řádky
v CSV, bez změny kódu.** Objeví se v menu u Tréninku i v lobby.

### Přidat postavu
1. Zkopíruj existující postavu, např. `data/characters/jiskra.tres` → `data/characters/nova.tres`.
2. V novém souboru změň `id = &"nova"` (malá písmena bez diakritiky, jedinečné) a klíče
   `name_key = "CHARACTER_NOVA_NAME"`, `description_key = "CHARACTER_NOVA_DESCRIPTION"`.
3. Nastav zbraň a schopnost: řádky `[ext_resource ... path="res://data/weapons/....tres" ...]` a
   `[ext_resource ... path="res://data/abilities/....tres" ...]` nahoře v souboru (stačí přepsat cestu).
4. Do `localization/translations.csv` přidej:
   ```
   CHARACTER_NOVA_NAME,Nová postava
   CHARACTER_NOVA_DESCRIPTION,"Krátký popis, zbraň a styl hry."
   ```
5. Spusť kontroly. Pozor: test `test_six_characters_with_one_own_weapon_each` v `tests/test_weapons.gd`
   hlídá přesný seznam postav a jejich zbraní – při přidání postavy ho doplň.

V jednom zápase může mít každou postavu jen jeden hráč a hraje max. 6 hráčů, takže postav musí být aspoň 6.

### Hodnoty postavy

| Hodnota | Význam |
|---|---|
| `move_speed` | rychlost běhu (px/s) |
| `ground_acceleration`, `air_acceleration` | jak rychle se rozběhne na zemi / ve vzduchu |
| `ground_friction`, `air_friction` | jak rychle zastaví bez ovládání |
| `knockback_friction` | jak rychle se zbrzdí po odhozu (menší = odletí dál) |
| `jump_velocity` | síla skoku |
| `air_jumps` | počet skoků ve vzduchu (1 = dvojskok) |
| `gravity`, `max_fall_speed` | gravitace a maximální rychlost pádu |
| `jump_buffer_time`, `drop_through_time` | tolerance stisku skoku před dopadem, čas seskoku přes plošinu |
| `weight` | váha: odhoz se jí dělí (1,4 = těžký, 0,8 = lehký, snadno odletí) |
| `weapon` | jediná zbraň postavy |
| `ability` | speciální schopnost (E / pravé tlačítko myši) |
| `color` | zatím nepoužito (barvu určuje pořadí hráče) |
| `sprite_sheet` | pixel art postavy `assets/sprites/characters/<id>.png` (10 snímků 32 × 40 px: klid 2, chůze 4, skok, pád, střelba 2) |
| `skin_sheet`, `skin_name_key` | skin postavy: stejný sheet v jiných barvách `assets/sprites/characters/<id>_skin.png` a jeho název v CSV (`SKIN_<ID>`); prázdné = postava skin nemá |

## Grafika (pixel art)

Postavy a zbraně kreslí skript `tools/art/generate_sprites.py` (potřebuje Python a Pillow). Barvy a tvary
postav jsou v něm (`CHARACTERS`, `WEAPONS`). Po úpravě spusť `python3 tools/art/generate_sprites.py`, pak
import Godotu a PNG soubory commitni. Novou postavu do skriptu přidej se stejným id jako v `data/characters/`.
Hotový obrázek z jiného programu (např. Aseprite) jde použít taky – stačí dodržet rozměry snímků.

**Skiny:** v `generate_sprites.py` jsou palety skinů postav v `CHARACTER_SKINS` (u Krügermanna a Architekta písmena
jejich palet, např. `b`/`B`/`c`/`v` = svetr/sako, `p`/`P` = kalhoty, `T`/`U` = kravata) a skiny zbraní ve `WEAPON_SKINS`
(barvy `metal`, `wood`, `box` + vzor `pattern`: `dragon`, `sakura`, `camo`, `lightning`, `engraving`, `gold`). Skript
zapíše `<id>_skin.png`; v `.tres` postavy je `skin_sheet` + `skin_name_key`, v `.tres` zbraně `skin_sprite` + `skin_name_key`.
Hráč skin zapne přepínači v menu (trénink) nebo v lobby; volba platí pro jakoukoli postavu a ostatní ji vidí.

Krügermanna ve svetru a Architekta s knírem v obleku kreslí samostatně `tools/art/reference_characters.py`.
Skript `generate_sprites.py` tento modul používá při tvorbě sprite sheetů. Jejich návrhy vycházejí ze stylizovaných předloh od uživatele; samotné
referenční obrázky nejsou součástí hry. Zůstává 10 snímků 32 × 40 px a stejné animace.

Mapy, pozadí a UI kreslí `tools/art/generate_world.py` (dlaždice plošin, pozadí map 480 × 270, mraky, logo, rámečky
tlačítek). Pozadí mapy je uzel `Background` ve scéně arény (pole `scene`). Vzhled tlačítek a textů je ve společném
tématu `assets/ui/theme.tres`.

## Zbraně – `data/weapons/*.tres`

| Hodnota | Význam |
|---|---|
| `id`, `name_key` | jedinečný identifikátor a klíč názvu v CSV (`WEAPON_..._NAME`) |
| `shots_per_second` | kadence při drženém tlačítku |
| `projectile_speed` | rychlost střely (px/s) |
| `max_range` | dostřel (px); pak střela zmizí – brokovnice krátce, odstřelovačka přes celou mapu |
| `spread_degrees` | náhodný rozptyl ± stupňů |
| `air_spread_degrees` | rozptyl ± stupňů, když střelec skáče nebo padá; záporné číslo = stejný jako `spread_degrees` (těžký kulomet: 1° vestoje, 30° ve vzduchu) |
| `move_spread_degrees` | rozptyl ± stupňů, když hráč drží klávesu pohybu (A/D, W, S); záporné číslo = pohyb rozptyl nemění (těžký kulomet: 30°) |
| `knockback` | odhoz jednoho zásahu (dělí se váhou zasaženého) |
| `recoil` | zpětný ráz střelce při každém výstřelu |
| `pellets` | počet broků na výstřel (brokovnice > 1, každý brok má vlastní rozptyl a odhoz) |
| `magazine_size` | náboje v zásobníku (výstřel brokovnice = 1 náboj); po posledním se přebíjí, po smrti je zásobník vždy plný. Pomalé silné zbraně malý (odstřelovačka 3), rychlé velký (samopal 32) |
| `reload_time` | délka přebíjení v sekundách (většina zbraní 1.0, těžký kulomet 2.0) |
| `damage` | procenta poškození za zásah (u brokovnic za každý brok); čím víc procent má zasažená postava, tím víc ji další zásahy odhodí (na 100 % ×2,5). Orientačně `knockback / 120`, celá rána max. ~15 % |
| `sprite` | pixel art zbraně `assets/sprites/weapons/<id>.png` (2 snímky 34 × 12 px: normální, záblesk; úchop v bodě 4,6) |
| `skin_sprite`, `skin_name_key` | skin zbraně `assets/sprites/weapons/<id>_skin.png` a název `WEAPON_SKIN_<ID>`; mají ho zbraně, které postavy používají |

**Limity hlídané testem `tests/test_weapons.gd`** (pokyn: odhoz nesmí být příliš vysoký, vše arkádové):
- odhoz jednoho výstřelu (`knockback × pellets`) max. **2600** (odstřelovačka Stína 2200, brokovnice Architekta 8 × 220 = 1760),
- odhoz za sekundu (`knockback × pellets × shots_per_second`) max. **7500** (měřítko: pistole 800 × 9/s),
- zpětný ráz `recoil` min. **100** (menší na zemi úplně zmizí).

Limity jsou v `src/combat/combat_rules.gd` (`MAX_KNOCKBACK_PER_SHOT`, `MAX_KNOCKBACK_PER_SECOND`, `MIN_RECOIL`).
Nepoužité zbraně (pistole, brokovnice, nýtovačka, revolver, kompaktní samopal, karabina) zůstávají v datech
pro pozdější použití.

## Schopnosti – `data/abilities/*.tres`

Společné hodnoty: `id`, `name_key`, `description_key`, `cooldown` (s do dalšího použití), `duration`
(jak dlouho je schopnost aktivní; 0 = okamžitá).

| Soubor (druh) | Postava | Vlastní hodnoty |
|---|---|---|
| `shield.tres` (štít) | Balvan | `knockback_multiplier` – násobek odhozu během štítu (0,2; platí i pro Krügermannův plyn); za štítem se dá střílet |
| `shockwave.tres` (tlaková vlna) | Vichr | `radius` (px, nyní 320 – dosah, ne melee), `strength` (síla odhozu, drž pod 1400), `lift` (náklon nahoru), `damage` (procenta poškození za zásah, nyní 9) |
| `dash.tres` (úskok) | Jiskra | `speed` (px/s po dobu `duration`) |
| `teleport.tres` (přesun) | Stín | `distance` – vzdálenost ke kurzoru (px, 250); přesun jde vždy co nejdál: proskakovací plošiny a hráče přeskočí, po pevné zemi/zdi sklouzne, zastaví ho jen pevný blok |
| `gas_blast.tres` (odfukovací plyn) | Krügermann | `length`, `height` (rozměr pásu), `gap` (mezera před postavou), `lifetime` (s), `blow_delay` (kolik sekund musí soupeř v plynu vydržet, než ho odfoukne; 1,0; `lifetime` 5), `blow_speed` (rychlost odfouknutí do strany, px/s, dělí se váhou soupeře; 1250), `blow_lift` (rychlost nahoru; 380) |
| `platform.tres` (plošina) | Architekt | `width` (px), `lifetime` (s) |

- **Varianta existujícího druhu** (např. silnější štít pro jinou postavu) = zkopírovat `.tres`, změnit `id`
  a hodnoty, přidat texty `ABILITY_..._NAME` a `ABILITY_..._DESCRIPTION` do CSV a odkázat na soubor z postavy.
- **Úplně nový druh schopnosti** potřebuje malý skript v `src/abilities/` (podtřída `AbilityData`) – to je
  programátorská práce, viz `docs/ARCHITECTURE.md`.

## Mapy (arény) – `data/arenas/*.tres` a `src/arenas/arena_*.tscn`

| Mapa (název ve hře) | Data | Scéna (rozložení) | Název v `translations.csv` |
|---|---|---|---|
| Střechy | `data/arenas/rooftops.tres` | `src/arenas/arena_rooftops.tscn` | `ARENA_ROOFTOPS_NAME` |
| Chrámové schody | `data/arenas/temple_steps.tres` | `src/arenas/arena_temple_steps.tscn` | `ARENA_TEMPLE_STEPS_NAME` |
| Visuté mosty | `data/arenas/hanging_bridges.tres` | `src/arenas/arena_hanging_bridges.tscn` | `ARENA_HANGING_BRIDGES_NAME` |
| Peklo | `data/arenas/hell.tres` | `src/arenas/arena_hell.tscn` | `ARENA_HELL_NAME` |
| Hobitín | `data/arenas/hobbiton.tres` | `src/arenas/arena_hobbiton.tscn` | `ARENA_HOBBITON_NAME` |

- **Pro kolik hráčů se mapa hodí** (nápověda po najetí myší na výběr mapy): v `.tres` mapy `recommended_min_players`
  a `recommended_max_players` (0 = „a více“). Peklo a Hobitín 4 a více, ostatní 2–3.
- **Přejmenovat mapu:** změň jen text u jejího `ARENA_..._NAME` v `localization/translations.csv` (`id` v `.tres`
  neměň – podle něj si hra pamatuje vybranou mapu a posílá ji ostatním).
- Mapa = scéna se skriptem `src/arenas/arena.gd`: plošiny (uzly s `platform.gd`: `position` = levý horní roh,
  `size`, `one_way = true` pro plošinu, kterou jde proskočit zespodu, `turf = true` = tráva na hlíně místo kamene,
  `color` = odstín), uzel `SpawnPoints` s
  **aspoň 6** `Marker2D` (místa oživení – kousek nad plošinou; prvních šest = začátek zápasu, sloty 0–5, v pořadí
  **vlevo, vpravo, vlevo, vpravo, střed-vlevo, střed-vpravo** – týmy pak začínají pohromadě: 2 týmy = levá/pravá strana,
  3 týmy = vlevo/vpravo/uprostřed; další spawny jsou jen pro oživení) a `Camera`
  (zoom 0,6; velký Hobitín 0,5). `kill_rect` = hranice, za kterou se ubírá život. Scénu nejpohodlněji upravíš v editoru Godotu
  (`tools/godot --path . --editor`, dvojklik na `.tscn`), jde to ale i v textovém editoru.
- **Pohyblivé plošiny (Hobitín):** uzel se skriptem `src/arenas/moving_platform.gd` (umí vše jako `platform.gd`) a navíc
  `travel` (posun vzdáleného konce dráhy od startu v px, např. `(300, 0)` = 300 px doprava, `(0, -200)` = 200 px nahoru),
  `period` (sekundy na cestu tam a zpět; nejrychlejší je uprostřed dráhy: π × délka / period – test hlídá max. 120 px/s)
  a `phase` (0–1, kde v cyklu začíná; 0,5 = na vzdáleném konci, aby se sousední plošiny míjely). Kdo na ní stojí,
  jede s ní. Spawny dávej na pevné plošiny. Poloha se počítá z času zápasu u hostitele, takže je u všech stejná.
- **Nazgûl (Hobitín):** uzel `Nazgul` (`src/arenas/nazgul.gd`) v mapě – `min_kills` (od kolika zabití hráče loví; 4),
  `first_delay` (s od dosažení do prvního příchodu; 3), `interval_min` / `interval_max` (s mezi příchody; 12–18),
  `strength` / `lift` (rychlost odhozu do strany / nahoru, dělí se váhou; 1200 / 400), `damage` (procenta za sek; 12),
  `center_x` (střed mapy: kdo je vlevo, letí doleva). Jde přidat do kterékoli mapy jako uzel s tímto skriptem.
- **Láva (Peklo):** uzel `Lava` (`src/arenas/lava.gd`) – `start_y` (hladina na začátku, pod všemi plošinami),
  `top_y` (kde se zastaví – těsně pod horní plošinou), `rise_speed` (px/s), `start_at_lives` (při kolika životech
  kteréhokoli hráče začne stoupat; v tréninku se počítají smrti). Kdo se lávy dotkne, hned přijde o život; když
  láva stoupá, oživuje se jen na spawnech nad `top_y`, takže **nahoře musí nějaké spawny být**. Lávu jde dát do
  kterékoli mapy – stačí do scény přidat uzel `Lava` s tímto skriptem.
- **Přidat mapu:** zkopíruj např. `src/arenas/arena_temple_steps.tscn` (uprav v editoru Godotu) a
  `data/arenas/temple_steps.tres` (změň `id`, `name_key` a cestu ke scéně), přidej název `ARENA_..._NAME` do CSV.
  Objeví se v menu u Tréninku i ve výběru hostitele v lobby. Test `tests/test_arenas.gd` hlídá, že pod každým
  spawnem je plošina – při přidání mapy doplň její id do seznamu v testu.

## Pravidla zápasu – `data/match_rules.tres`

`lives` (počet životů), `respawn_delay` (s do oživení), `respawn_invulnerability` (s ochrany po oživení),
`out_of_bounds_grace` (s mimo arénu, než se ubere život), `countdown_seconds` (odpočet na začátku).

## Texty – `localization/translations.csv`

- Formát `KLÍČ,text`. **Text s čárkou musí být v uvozovkách:** `KLÍČ,"Text, s čárkou"` – jinak se useknou
  (hlídá test `tests/test_translations_csv.gd`).
- Proměnné ve složených závorkách (`{name}`, `{seconds}`) nech beze změny.
- Soubor ukládej v UTF-8.

## Vydání změny

1. V `project.godot` zvyš `config/version` o jedno (např. `0.1.12` → `0.1.13`). GitHub jinou než následující
   verzi odmítne.
2. V `data/changelog.tres` přesuň dosavadní aktuální záznam (`"build": 0`) pod skutečně vydanou verzi a
   sestavení (zjistíš v `version.json` na stránce vydání) a do nového záznamu `"build": 0` napiš klíče
   novinek; texty novinek (`CHANGELOG_...`) přidej do CSV. „Co je nového“ ukazuje jen nejnovější verzi.
3. Commit a push na `main` – GitHub Actions hru sestaví a vydají; hráčům se nabídne aktualizace.

## Kontroly po každé změně

```
tools/godot --headless --path . --import                          # po přidání/přejmenování souborů
tools/godot --headless --path . -s tests/run_tests.gd             # testy (musí skončit „0 failures“)
tools/godot --headless --path . -s tools/check_localization.gd    # chybějící texty
tools/godot --path .                                               # zahrát si (Trénink: výběr postavy vedle tlačítka)
```
