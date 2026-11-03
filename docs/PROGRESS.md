# Stav projektu

## Kde jsme skončili
**Milník M1 (kostra, lokální pohyb, CI se ZIPy) je naimplementovaný, ale ještě není commitnutý.**
- Lokálně funguje a je otestováno (viz Stav testů).
- Úplně chybí ověření CI na GitHubu: workflow ještě neběžel, protože se nepushovalo.
- Necommitnuté soubory: všechny soubory M1 (`git status`).

## Další krok
**Dokončit M1: ověřit CI a ZIPy z GitHubu.**
1. Uživatel commitne a pushne M1 na `main` (návrh commit zprávy je v posledním shrnutí).
2. Zkontrolovat běh workflow (záložka Actions na GitHubu).
   - Pokud selže, opravit podle logu.
   - Nejpravděpodobnější místa selhání: `tools/setup_env.sh` na Linuxu (`shasum`), push tagu `dev`, `gh release` příkazy.
3. Ověřit, že na `releases/tag/dev` jsou 3 ZIPy.
4. Uživatel stáhne `gun_game-windows.zip` na **Windows PC**, spustí hru a zkontroluje:
   - SmartScreen postup
   - menu s verzí `v0.0.0+<commit> (dev)`
   - diakritiku
   - trénink: pohyb, skok, dvojskok, seskok a respawn
5. Pak označit M1 jako hotový a jako další krok zapsat **M2 krok 1: `Session` autoload + `EnetDirectConnector` + handshake verze** (PLAN.md, sekce D a K).

## Aktuální stav
- **Milník:** M1, čeká na ověření CI a Windows buildu.
- **Funguje** (ověřeno lokálně na macOS arm64):
  - hlavní menu s verzí a českými texty
  - trénink v aréně: běh, skok, dvojskok, coyote time, buffer skoku, seskok z jednosměrné plošiny, respawn po pádu
  - Esc vrací do menu
  - export pro Windows, macOS a Linux
- **Hostovat / Připojit:** tlačítka jsou zatím vypnutá (přijdou v M2).

## Poslední změny
- **2026-11-03, M1:**
  - **Projekt:** `project.godot` (Compatibility renderer, 1280×720 canvas_items, 60 Hz, pojmenované kolizní vrstvy, vstupy, locale fallback `cs`, ETC2/ASTC pro macOS).
  - **Základ:** `src/core/build_info.gd` a `content_db.gd`; `src/data_types/` (`CharacterData`, `MatchRules`); `data/characters/jiskra.tres`; `data/match_rules.tres`.
  - **Pohyb:** `src/player/` (`InputFrame`, sdílený `PlayerMotor` s čistou `compute_velocity()`, `Player`).
  - **Aréna:** `src/arenas/` (`Arena`, `@tool Platform`, `arena_rooftops.tscn`).
  - **Zápas a menu:** `src/match/` (lokální trénink s respawnem); `src/ui/main_menu`.
  - **Texty:** `localization/translations.csv`; font Noto Sans (OFL).
  - **Kontroly:** `tests/` (vlastní runner + 8 testů pohybu); `tools/check_localization.gd`.
  - **Build:** `export_presets.cfg` (Windows x86_64 s PCK v exe, macOS universal ad-hoc, Linux x86_64); `.github/workflows/build.yml`.
  - **Dokumentace:** README (česky), LICENSE (MIT), CREDITS.md, `docs/ARCHITECTURE.md`, `.gitattributes`; doplněný `.gitignore`.
- **2026-11-03, M0:** `docs/PLAN.md`, `tools/setup_env.sh` a `tools/godot`, `CLAUDE.md`, protokol „přečti si progress a pokračuj“.

## Co je potřeba udělat
1. Dokončit M1: ověřit CI a Windows ZIP (viz Další krok).
2. M2: síťové jádro (lobby, handshake, synchronizace pohybu, LagSimulator). Zadávat po krocích.
3. M3: souboj = MVP (`v0.1.0`).

Ostatní milníky viz PLAN.md, sekce K.

## Známé problémy
- **Internetové testy z knihovny:** uživatel je teď v knihovně. Veřejné Wi-Fi sítě skoro jistě neumožní hostovat (NAT nebo CGNAT, žádný přístup k routeru, často izolace klientů), někdy blokují i UDP.
  - Pro internetový test v M2: hostovat **z domova**, nebo použít **Tailscale**.
  - Typ připojení hostitele (veřejná IPv4 / CGNAT) se zjistí v M2 z výsledku UPnP.
- **Velikost buildů:** Windows exe má ~110 MB (ZIP ~39 MB, změřeno lokálně), macOS ZIP ~62 MB. To je dáno šablonami Godotu 4.7.
- Ikona hry a exe je výchozí ikona Godotu (vlastní přijde v M8).
- `EDITING_GUIDE.md` zatím neexistuje (plán: M5).
- `ArenaData` resource zatím neexistuje, aréna je pevně v `match_controller.gd` (výběr arény přijde v M6).
- Varování o „leaked RID/ObjectDB“ při exportu bylo opraveno v `platform.gd` (tvar se přidává v `_init`).

## Stav testů
- **Unit testy:** 8/8 OK (`PlayerMotor`: skok, držený skok, coyote, dvojskok, buffer, rozjezd, knockback se neruší, seskok).
- **Kontrola lokalizace:** 10 klíčů, 0 chybí. Ověřeno, že při chybějícím klíči skončí s exit 1.
- **Smoke test** (skript s `Input.action_press`, macOS):
  - menu: snímek obrazovky, diakritika OK
  - běh na 440 px/s, skok
  - pád z arény → respawn po 1,5 s
  - seskok z jednosměrné plošiny
  - průskok plošiny zespodu
- **Export lokálně** (macOS host): Windows, macOS i Linux bez chyb.
  - `build_info.json` je v PCK, `tests/` a `tools/` ne.
  - macOS .app je ad-hoc podepsaná a exportovaná binárka se spustí.
- **NETESTOVÁNO:**
  - běh workflow na GitHubu
  - spuštění na Windows (exe ani SmartScreen)
  - spuštění na Linuxu
  - Gatekeeper postup se staženým ZIPem
  - ruční hraní s klávesnicí (jen simulované vstupy)

## Rozhodnutí
- **Godot 4.7.2 + GDScript:** nejmenší buildy, export všech platforem z Linuxu.
- **Připnutý Godot v `.tools/` místo venv:** jedinou závislostí je engine. Stejný skript používá i CI.
- **Host-autoritativní listen server, ENet:** jednoduché, bez serveru.
- **Vlastní snapshot 30 Hz místo MultiplayerSynchronizer:** kontrola nad interpolací a velikostí zpráv.
- **MVP připojení:** IP + UPnP, záloha Tailscale, později noray kódy.
- **Rolling prerelease tag `dev`** (ne `latest`), protože /releases/latest ukazuje jen stabilní verze.
- **Hlavní platforma Windows.** macOS build je v CI, testy jen podle možností.
- **`PlayerMotor.compute_velocity()` bez vedlejších efektů:** testovatelné a připravené na predikci v M4.
- **InputFrame nese jen držená tlačítka, hrany počítá motor:** host i predikce je vyhodnotí stejně.
- **Knockback nad max. rychlostí brzdí jen tření:** držení směru knockback hned nezruší (pocit jako v žánru).
- **Vlastní mini test runner místo addonu (GUT):** ~30 řádků, žádná závislost.
- **Lokalizační klíče se hledají regexem** (citovaný `UPPER_SNAKE_CASE`): jednoduché, pokryje `.gd`, `.tscn` i `.tres`.
- **CI bez actions třetích stran** (kromě checkout a cache) a s vlastním `setup_env.sh`: méně křehké při nové verzi Godotu.
