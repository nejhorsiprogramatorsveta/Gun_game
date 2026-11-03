# gun_game

Rychlá 2D plošinovková střílečka pro 2–4 hráče. Zásahy soupeře neubírají životy, ale **odhazují** ho. Cílem je shodit ostatní z arény. Každý pád stojí život a vyhrává poslední, kdo v aréně zůstane.

> **Stav vývoje:** zatím funguje jen **trénink pro jednoho hráče** (pohyb po aréně). Online hra s kamarády přijde v dalších verzích. Aktuální stav je v [docs/PROGRESS.md](docs/PROGRESS.md).

## Stažení (hotová hra, bez instalace)

| Systém | Nejnovější vývojová verze |
|---|---|
| **Windows 10/11** | [gun_game-windows.zip](https://github.com/nejhorsiprogramatorsveta/Gun_game/releases/download/dev/gun_game-windows.zip) |
| macOS (Apple Silicon i Intel) | [gun_game-macos.zip](https://github.com/nejhorsiprogramatorsveta/Gun_game/releases/download/dev/gun_game-macos.zip) |
| Linux | [gun_game-linux.zip](https://github.com/nejhorsiprogramatorsveta/Gun_game/releases/download/dev/gun_game-linux.zip) |

- Všechny vývojové buildy: [releases/tag/dev](https://github.com/nejhorsiprogramatorsveta/Gun_game/releases/tag/dev). Tento build se aktualizuje po každé změně.
- Stabilní verze: [releases/latest](https://github.com/nejhorsiprogramatorsveta/Gun_game/releases/latest). Zatím žádná neexistuje, první bude `v0.1.0`.

> ⚠️ **Nestahuj** zelené tlačítko *Code → Download ZIP* ani *Source code (zip)*. To jsou zdrojové kódy a bez Godotu je nespustíš. Stahuj soubory `gun_game-<systém>.zip`.

### Windows
1. Rozbal ZIP (pravým tlačítkem → *Extrahovat vše*).
2. Spusť `gun_game.exe`.
3. Pokud se objeví modré okno **„Systém Windows ochránil váš počítač“** (SmartScreen), klikni na *Další informace* a pak na *Přesto spustit*. Hra není podepsaná placeným certifikátem, proto ji Windows nezná.
4. *(Až bude online hra)* Pokud se Windows zeptá na **bránu firewall**, klikni na *Povolit přístup*. Bez toho se k tobě kamarádi nepřipojí.

### macOS
Hra není ověřená u Applu (to stojí 99 USD ročně), proto ji macOS napoprvé zablokuje:
1. Rozbal ZIP a přesuň `gun_game.app` třeba do složky Aplikace.
2. Dvakrát na hru klikni. Objeví se hláška, že ji Apple nemůže ověřit. Klikni na **Hotovo**.
3. Otevři **Nastavení systému → Soukromí a zabezpečení**, sjeď dolů a u hlášky o `gun_game` klikni na **Přesto otevřít**. Potvrď heslem.
4. Pokud tlačítko chybí, spusť v Terminálu `xattr -dr com.apple.quarantine /Applications/gun_game.app` a hru otevři znovu.

U každé nové verze se tento postup opakuje.

## Ovládání

| Akce | Klávesy |
|---|---|
| Pohyb | A / D nebo šipky |
| Skok (i dvojskok ve vzduchu) | W, mezerník nebo šipka nahoru |
| Seskok z tenké plošiny | S nebo šipka dolů |
| Střelba *(přijde v M3)* | J |
| Schopnost *(přijde v M5)* | K |
| Zpět do menu | Esc |

## Jak hrát s kamarády

*Online hra zatím není hotová (milníky M2 a M3).* Postup bude takový:
1. Všichni si stáhnou **stejnou verzi**. Číslo verze je vidět vlevo dole v menu.
2. Jeden hráč klikne na *Hostovat* a pošle ostatním adresu z lobby (tlačítko *Kopírovat*).
3. Ostatní kliknou na *Připojit* a adresu vloží.
4. Pokud se nedaří připojit, poradí návod, který tu přibude. Hostitel bude pravděpodobně muset otevřít port v routeru, nebo použijete Tailscale.

## Vývoj

Potřebuješ jen git a bash (macOS nebo Linux). Godot se stáhne do projektu, nic se neinstaluje do systému.

```bash
tools/setup_env.sh                                        # jednou: stáhne Godot 4.7.2 do .tools/
tools/godot --headless --path . --import                  # import assetů (po čistém klonu)
tools/godot --path .                                      # spustit hru
tools/godot --path . --editor                             # otevřít editor
tools/godot --headless --path . -s tests/run_tests.gd     # unit testy
tools/godot --headless --path . -s tools/check_localization.gd   # kontrola překladů
```

- Plán projektu: [docs/PLAN.md](docs/PLAN.md)
- Architektura: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
- Průběh vývoje: [docs/PROGRESS.md](docs/PROGRESS.md)
- Buildy vytváří GitHub Actions ([.github/workflows/build.yml](.github/workflows/build.yml)) po každém pushi na `main`.

## Licence

- Kód: [MIT](LICENSE)
- Cizí assety a jejich licence: [CREDITS.md](CREDITS.md)
