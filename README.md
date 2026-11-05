# Dojo Knockout

Rychlá arkádová 2D plošinovková střílečka pro 2–4 hráče v samurajském a ninja stylu.
(Soubory ke stažení a složka s nastavením se z technických důvodů dál jmenují `gun_game`.) Zásahy soupeře neubírají životy, ale **odhazují** ho. Cílem je shodit ostatní z arény. Každý pád stojí život a vyhrává poslední, kdo v aréně zůstane.

> **Stav vývoje (verze 0.2.0):** 6 postav, každá s vlastní zbraní a speciální schopností (E / pravé tlačítko myši), 3 mapy, výběr postavy a mapy v lobby, zápas pro 2–4 hráče, životy, skóre, výsledky a návrat do lobby, automatické aktualizace. Trénink s výběrem postavy a mapy. Grafika je zatím jen z barevných tvarů. Aktuální vydanou verzi najdeš na [stránce vydání](https://github.com/nejhorsiprogramatorsveta/Gun_game/releases/latest), stav práce v [docs/PROGRESS.md](docs/PROGRESS.md).

## Stažení (hotová hra, bez instalace)

| Systém | Nejnovější verze |
|---|---|
| **Windows 10/11** | [gun_game-windows.exe](https://github.com/nejhorsiprogramatorsveta/Gun_game/releases/download/dev/gun_game-windows.exe) |
| macOS (Apple Silicon i Intel) | [gun_game-macos.zip](https://github.com/nejhorsiprogramatorsveta/Gun_game/releases/download/dev/gun_game-macos.zip) |
| Linux | [gun_game-linux.zip](https://github.com/nejhorsiprogramatorsveta/Gun_game/releases/download/dev/gun_game-linux.zip) |

- **Automatické aktualizace:** když vyjde nová verze, hra ji po spuštění sama nabídne v menu (*Aktualizovat*), stáhne a restartuje se. Ručně je potřeba stáhnout jen první verzi s touto funkcí.
- [Stránka vydání](https://github.com/nejhorsiprogramatorsveta/Gun_game/releases/latest) se průběžně aktualizuje. Verze postupují `0.1.1`, `0.1.2` atd.; číslo najdeš také v menu hry.

> ⚠️ **Nestahuj** zelené tlačítko *Code → Download ZIP* ani *Source code (zip)*. To jsou zdrojové kódy a bez Godotu je nespustíš. Stahuj soubor `gun_game-windows.exe` (Windows) nebo `gun_game-macos.zip` / `gun_game-linux.zip`.

### Windows
1. Stáhni `gun_game-windows.exe` (asi 110 MB) a spusť ho. Nic se neinstaluje ani nerozbaluje.
2. Pokud prohlížeč napíše, že soubor „není běžně stahován“, zvol *Zachovat*.
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
| Střelba | levé tlačítko myši (drž pro opakovanou střelbu) |
| Schopnost *(přijde v M5)* | pravé tlačítko myši nebo E |
| Zpět do menu | Esc |

## Jak hrát s kamarády

**Průběh hry:** lobby → hostitel klikne *Začít zápas* → odpočet 3-2-1 → každý má 5 životů, pád z arény = −1 život (po návratu chvíli blikáš a zásahy tě neodhodí) → poslední, komu zbydou životy, vyhrává → výsledky → **všichni zpět ve stejném lobby** a můžete hrát znovu. Esc: hostitel ukončí zápas pro všechny, ostatní odejdou.

### Na stejné Wi-Fi
1. Všichni si stáhnete **stejnou verzi** hry. Číslo verze je vlevo dole v menu.
2. Jeden klikne na **Hostovat** a v lobby klikne na **Kopírovat** u adresy „Stejná Wi-Fi / síť“.
3. Ostatní adresu vloží (celou, i s částí za `#`) a kliknou na **Připojit**.

### Přes internet (Tailscale)
[Tailscale](https://tailscale.com) je bezplatná aplikace pro Windows, Mac i Linux. Spojí vaše počítače do soukromé sítě, jako byste byli na stejné Wi-Fi. Nemusíte nic nastavovat v routeru a nikdo neuvidí tvoji skutečnou IP adresu.

**Jednou na začátku:**
1. **Všichni:** stáhněte a nainstalujte Tailscale z [tailscale.com/download](https://tailscale.com/download) a přihlaste se (stačí Google, Microsoft nebo Apple účet).
2. **Hostitel:** otevři v prohlížeči [login.tailscale.com/admin/machines](https://login.tailscale.com/admin/machines). U svého počítače klikni na **⋯ → Share…** a pošli kamarádům odkaz.
   - Kamarádi tak uvidí jen tento jeden počítač, ne tvoje ostatní zařízení. Je to bezpečnější než je zvát do celé sítě.
3. **Kamarádi:** otevřou odkaz a přijmou sdílení.

**Pokaždé, když chcete hrát:**
1. Všichni mají Tailscale zapnutý (ikona u hodin, stav *Connected*).
2. Hostitel klikne v hře na **Hostovat** a v lobby na **Kopírovat** u adresy „Přes internet (Tailscale)“. Adresa začíná `100.` a obsahuje kód hry za `#`.
3. Kamarádi adresu vloží a kliknou na **Připojit**.

**Když to nejde:**
- Zkontroluj, že **všichni mají zapnutý Tailscale** a kamarád v aplikaci Tailscale vidí tvůj počítač.
- **Windows:** když se po kliknutí na *Hostovat* objeví dotaz brány firewall, klikni na **Povolit přístup**. Tailscale síť může Windows brát jako veřejnou, proto zaškrtni i *Veřejné sítě*. Pokud jsi dotaz omylem zamítl: *Nastavení → Zabezpečení Windows → Brána firewall → Povolit aplikaci* → `gun_game`.
- **Všichni musí mít stejnou verzi hry.** Hra jinak sama napíše, že se verze liší.
- **Kód hry se mění při každém hostování.** Pošli vždy novou adresu.

## Vývoj

Potřebuješ jen git a bash (macOS nebo Linux). Godot se stáhne do projektu, nic se neinstaluje do systému.

```bash
tools/setup_env.sh                                        # jednou: stáhne Godot 4.7.2 do .tools/
tools/godot --headless --path . --import                  # import assetů (po čistém klonu)
tools/godot --path .                                      # spustit hru
tools/godot --path . --editor                             # otevřít editor
tools/godot --headless --path . -s tests/run_tests.gd     # unit testy
tools/godot --headless --path . -s tools/check_localization.gd   # kontrola překladů
tools/godot --path . -- --fake-lag=100 --fake-loss=5            # test: simulace pomalého internetu
```

- Plán projektu: [docs/PLAN.md](docs/PLAN.md)
- Architektura: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
- Průběh vývoje: [docs/PROGRESS.md](docs/PROGRESS.md)
- Buildy vytváří GitHub Actions ([.github/workflows/build.yml](.github/workflows/build.yml)) po každém pushi na `main`.
- Před další změnou hry zvýšit `application/config/version` v `project.godot` (nyní `0.1.1`, příště `0.1.2`) a archivovat vydaný záznam changelogu. CI aktualizuje stále stejné vydání; opakované spuštění stejného sestavení je povolené. Tagy se neposouvají a další vydání se nevytvářejí.

## Licence

- **Hra a kód:** [PolyForm Noncommercial 1.0.0](LICENSE). Hru i kód smíš zdarma stahovat, hrát, upravovat a sdílet, ale **jen nekomerčně**. Prodávat je nebo na nich jinak vydělávat je zakázáno.
- Cizí části mají vlastní licence (font Noto Sans: OFL, engine Godot: MIT), viz [CREDITS.md](CREDITS.md).
