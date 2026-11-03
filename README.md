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
| Míření | myš (střílí se tam, kde je kurzor) |
| Střelba *(přijde v M3)* | levé tlačítko myši |
| Schopnost *(přijde v M5)* | pravé tlačítko myši nebo E |
| Zpět do menu | Esc |

## Jak hrát s kamarády

*Online hra zatím není hotová (milníky M2 a M3).* Postup bude takový:
1. Všichni si stáhnou **stejnou verzi**. Číslo verze je vidět vlevo dole v menu.
2. Jeden hráč klikne na *Hostovat*. Lobby ukáže adresy pro kamarády včetně kódu hry (např. `85.12.34.56:24642#K7Q2MX`). Tlačítkem *Kopírovat* je pošleš kamarádům.
   - **„Internet“:** router otevřel port automaticky (UPnP), funguje odkudkoli.
   - **„Stejná Wi-Fi / síť“:** jen pro hráče ve stejné síti.
   - Pokud lobby napíše, že se port otevřít nepovedlo, přesměruj v routeru **UDP port 24642** na svůj počítač, nebo použijte Tailscale.
3. Ostatní vloží celou adresu (i s částí za `#`) a kliknou na *Připojit*.

## Bezpečnost hraní přes internet

- **Co hra otevírá:** jen jeden UDP port (24642) na počítači **hostitele** a jen po dobu hostování. Pokud to router umí (UPnP), otevře se automaticky a po odchodu z lobby se zase zavře, nejpozději za 2 hodiny. Hra nedává přístup k souborům, jiným programům ani k jiným zařízením ve tvé Wi-Fi. Kdo se jen připojuje, žádný port neotevírá.
- **Kód hry:** adresa obsahuje i náhodný kód (např. `85.12.34.56:24642#K7Q2MX`). Bez něj se nikdo cizí nepřipojí. Kód se mění při každém hostování.
- **Adresu posílej jen kamarádům.** Obsahuje tvoji veřejnou IP. Kdo ji zná, mohl by tvoje připojení zahltit nebo zhruba určit, kde jsi.
- **Nejbezpečnější varianta je [Tailscale](https://tailscale.com).** Nic se neotevírá do internetu a připojit se můžou jen pozvaní. Firewall nech zapnutý.
- **Windows Firewall:** povol hru pro **soukromé sítě**. Na veřejné Wi-Fi (kavárna, knihovna) hostování nedoporučujeme.
- **Hru stahuj jen z [GitHub Releases](https://github.com/nejhorsiprogramatorsveta/Gun_game/releases)** tohoto projektu, nikdy ne jako exe poslané v chatu. Hra nikdy nepotřebuje práva správce.

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
