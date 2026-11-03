# Stav projektu

## Kde jsme skončili
**M2 krok 1 (Session + EnetDirectConnector + handshake verze) je hotový a otestovaný lokálně. Zatím není commitnutý.**
- M1 je na GitHubu (`d234c5a`), CI prošlo. Ruční test na Windows je ODLOŽENÝ (viz níže).
- Necommitnuté soubory:
  - `src/autoload/session.gd`, `src/net/connectors/*`
  - `tests/test_address_parsing.gd`
  - úpravy `project.godot` (autoload), `build_info.gd` (`--fake-commit`), `translations.csv`
  - dokumentace (`PLAN.md` D.8, `ARCHITECTURE.md`, `CLAUDE.md`, tento soubor)
- Hráč zatím nic z M2 nevidí: tlačítka Hostovat a Připojit jsou pořád vypnutá. UI přijde v kroku 2.

## Další krok
**M2 krok 2: lobby UI + autoload `Settings`.**
- **Hlavní menu:** zapnout *Hostovat* a *Připojit*.
  - Dialog pro jméno hráče a u připojení i pro adresu.
  - Zapamatovat jméno a poslední adresu v `Settings` (`user://settings.cfg`).
- **Scéna `src/ui/lobby.tscn`:** seznam hráčů (`Session.players_changed`), tlačítko *Odejít*, u hostitele adresa k sdílení s tlačítkem *Kopírovat*.
  - V tomto kroku jen lokální IP adresy a port. UPnP a veřejná IP přijdou v kroku 3.
- **Chyby:** zobrazovat zprávy ze `Session.ended(message)` (návrat do menu s hláškou).
- **Test:** dvě instance hry ručně (`tools/godot --path .` dvakrát) a navíc druhá s `-- --fake-commit=abc` pro test neshody verzí.

Nejdřív se zeptej, jestli uživatel chce ODLOŽENÝ test na Windows udělat teď.

## ODLOŽENO (uživatel: „vyřešíme později“, 2026-11-03)
**Ruční test staženého ZIPu (poslední část M1).** CI a ZIPy jsou ověřené (body 1–3 hotové 2026-11-03).
4. Uživatel stáhne `gun_game-windows.zip` na **Windows PC** (a případně `gun_game-macos.zip` v prohlížeči na Macu) a zkontroluje:
   - SmartScreen / Gatekeeper postup
   - menu s verzí `v0.0.0+<commit> (dev)`
   - trénink

**Do té doby se hra na Macu spouští lokálně:** `tools/godot --path .` z kořene projektu, nebo lokálně exportovaný `build/macos/gun_game.zip` (vzniká jen lokálním exportem, není v gitu).

## Aktuální stav
- **Milník:** M2, krok 1 z 5 hotový. M1 je hotový včetně CI, chybí jen ruční test na Windows (viz ODLOŽENO).
- **Funguje** (ověřeno lokálně na macOS arm64):
  - hlavní menu s verzí a českými texty
  - trénink v aréně: běh, skok, dvojskok, coyote time, buffer skoku, seskok z jednosměrné plošiny, respawn po pádu
  - Esc vrací do menu
  - export pro Windows, macOS a Linux
- **Síť (zatím jen v kódu, bez UI):**
  - hostování a připojení přes IP:port (IPv4, IPv6, hostname)
  - kontrola verze a protokolu s českou hláškou
  - seznam hráčů v lobby rozesílaný hostem (max. 4)
  - odmítnutí při plném lobby nebo běžícím zápase
  - hlášky při odchodu hostitele, nedostupném hostiteli (timeout 10 s), neplatné adrese a obsazeném portu
- **Hostovat / Připojit:** tlačítka v menu jsou pořád vypnutá (zapnou se v M2 kroku 2).

## Poslední změny
- **2026-11-03, M2 krok 1:**
  - **`src/autoload/session.gd`** (autoload `Session`): host/join/leave, fáze OFFLINE/CONNECTING/LOBBY, handshake přes autentizaci `SceneMultiplayer`, seznam hráčů (RPC jen host → klienti), signály `phase_changed`, `players_changed` a `ended(message)`.
  - **`src/net/connectors/connector.gd`** a **`enet_direct_connector.gd`:** ENet, výchozí port 24642, rozbor adresy, timeouty 5–8 s.
  - **`BuildInfo`:** debug přepínač `-- --fake-commit=xxx`.
  - **Texty:** 8 nových (chyby připojení, výchozí jméno).
  - **Testy:** `tests/test_address_parsing.gd`.
  - **Dokumentace:** PLAN.md D.8 upřesněno (handshake přes autentizaci, ne RPC).
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
1. Dokončit M1: ruční test Windows ZIPu (ODLOŽENO, viz výše).
2. M2, zbývající kroky:
   - **krok 2:** lobby UI + `Settings`
   - **krok 3:** UPnP (`src/net/upnp_helper.gd` ve vlákně), veřejná IP v lobby, detekce CGNAT a doporučení Tailscale
   - **krok 4:** synchronizace pohybu: start zápasu z lobby, spawn hráčů, vstupy 60 Hz → host, snapshoty 30 Hz, interpolace (`snapshot.gd`, `match_net.gd`, `remote_interpolator.gd`)
   - **krok 5:** `LagSimulator`, test na 2 počítačích v LAN a **první internetový test** (z domova nebo přes Tailscale)
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
- **Unit testy:** 12/12 OK.
  - `PlayerMotor` (8): skok, držený skok, coyote, dvojskok, buffer, rozjezd, knockback se neruší, seskok
  - rozbor adresy (4): IPv4, hostname, IPv6, neplatné vstupy
- **Síť, lokálně na jednom Macu** (headless procesy, 127.0.0.1 a `[::1]`, M2 krok 1):
  - host a 3 klienti: všichni v lobby, správná jména (Hráč 2–4), seznam se rozešle všem
  - 4. klient dostane „Hra je plná“
  - klient s `--fake-commit` dostane českou hlášku o jiné verzi a je odpojen
  - odchod klienta: host ho odebere a rozešle nový seznam
  - odchod hostitele: klienti dostanou „Hostitel ukončil hru…“
  - nedostupný host: po 10 s „Nepodařilo se připojit…“
  - neplatná adresa a obsazený port: správné hlášky
  - Poznámka: testovací skripty při ukončení hlásí „resources still in use at exit“. Je to pravděpodobně artefakt testovacích skriptů (lambdy na autoloadu), ve hře neověřeno.
- **Kontrola lokalizace:** 18 klíčů, 0 chybí. Ověřeno, že při chybějícím klíči skončí s exit 1.
- **Smoke test** (skript s `Input.action_press`, macOS):
  - menu: snímek obrazovky, diakritika OK
  - běh na 440 px/s, skok
  - pád z arény → respawn po 1,5 s
  - seskok z jednosměrné plošiny
  - průskok plošiny zespodu
- **Export lokálně** (macOS host): Windows, macOS i Linux bez chyb.
  - `build_info.json` je v PCK, `tests/` a `tools/` ne.
  - macOS .app je ad-hoc podepsaná a exportovaná binárka se spustí.
- **CI na GitHubu** (commit `d234c5a`): import, testy, kontrola lokalizace, 3 exporty a publikace na `releases/tag/dev`, vše OK.
  - Stažený `gun_game-macos.zip` (62 MB): verze `0.0.0+d234c5a (dev)`, ad-hoc podpis, binárka se spustí.
  - Stažený `gun_game-windows.zip` (39 MB) obsahuje `gun_game.exe`.
- **NETESTOVÁNO:**
  - spuštění na Windows (exe ani SmartScreen)
  - spuštění na Linuxu
  - Gatekeeper postup se staženým ZIPem
  - ruční hraní s klávesnicí (jen simulované vstupy)
  - síť mezi dvěma různými počítači a přes internet (zatím jen localhost)

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
- **Handshake přes autentizaci `SceneMultiplayer`, ne RPC:** RPC se párují podle indexu metody, takže mezi různými buildy by hello nemuselo jít přečíst. Bez dokončené autentizace peer nemůže posílat RPC.
- **ENet `MAX_CLIENTS = 4`** (o 1 víc než hráčů): klient navíc dostane hlášku „Hra je plná“, ne tichý timeout.
- **CI bez actions třetích stran** (kromě checkout a cache) a s vlastním `setup_env.sh`: méně křehké při nové verzi Godotu.
