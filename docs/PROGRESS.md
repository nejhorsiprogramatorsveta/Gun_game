# Stav projektu

## Kde jsme skončili
**M2 krok 3 (UPnP, veřejná adresa, kód hry a bezpečnostní opatření) je hotový, commitnutý a pushnutý.**
- Nový trvalý požadavek uživatele: **bezpečnost online hry** (PLAN.md, sekce S; CLAUDE.md; paměť).
- Úspěšnou cestu UPnP (router port otevře) nešlo otestovat, uživatel je v knihovně. Ověřit doma.
- Necommitnuté soubory: žádné.

## Další krok
**M2 krok 4a: rozdělit `session.gd` (292 řádků) a připravit start zápasu.**
1. Přesunout handshake (hello, reply, kód hry, validace) z `session.gd` do `src/net/handshake.gd` (statické funkce pro sestavení a ověření zpráv). `Session` si nechá jen stav a události.
2. Pak **M2 krok 4b, synchronizace pohybu** (PLAN.md D.2–D.4):
   - tlačítko *Začít zápas* u hostitele (min. 2 hráči), RPC `match_started` → všichni načtou `match.tscn`
   - spawn podle slotů
   - `InputFrame` rozšířit o `seq` a `aim` (úhel ke kurzoru, u16)
   - vstupy 60 Hz (unreliable_ordered, poslední 3 kvůli ztrátám) → host
   - snapshot 30 Hz → klienti (`src/net/snapshot.gd`)
   - interpolace vzdálených hráčů (`src/player/remote_interpolator.gd`)
   - RPC jen v `src/match/match_net.gd`, validace dle D.7 a sekce S (velikosti, rate-limit, sender ID)
   - Lze rozdělit na víc commitů.

## ODLOŽENO NA KONEC PROJEKTU (uživatel 2026-11-03: „Windows ověříme až na konci, pokud neřeknu jinak“)
**Neptat se na to v každé session.**

**Ruční test staženého ZIPu (poslední část M1).** CI a ZIPy jsou ověřené (body 1–3 hotové 2026-11-03).
4. Uživatel stáhne `gun_game-windows.zip` na **Windows PC** (a případně `gun_game-macos.zip` v prohlížeči na Macu) a zkontroluje:
   - SmartScreen / Gatekeeper postup
   - menu s verzí `v0.0.0+<commit> (dev)`
   - trénink

**Do té doby se hra na Macu spouští lokálně:** `tools/godot --path .` z kořene projektu, nebo lokálně exportovaný `build/macos/gun_game.zip` (vzniká jen lokálním exportem, není v gitu).

## Aktuální stav
- **Milník:** M2, kroky 1–3 z 5 hotové. M1 je hotový včetně CI, chybí jen ruční test na Windows (viz ODLOŽENO).
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
- **Menu a lobby (M2 krok 2):**
  - Menu: jméno, Hostovat, adresa + Připojit. Jméno a poslední adresa se pamatují.
  - Lobby: seznam hráčů (hostitel, ty), u hostitele adresy ke zkopírování (LAN, Tailscale, IPv6), Odejít.
  - Chyby se zobrazí červeně v menu.
  - Zápas z lobby zatím spustit nejde (krok 4).
- **Internet a bezpečnost (M2 krok 3):**
  - Host zkouší UPnP (jeden UDP port, limit 2 h, zavírá se při odchodu i zavření okna) a v lobby ukáže stav: zkouším / otevřeno + adresa „Internet“ / nepovedlo se + návod / CGNAT + Tailscale.
  - Adresa ke sdílení obsahuje **kód hry** (`ip:port#KÓD`). Bez správného kódu se nikdo nepřipojí.
  - `server_relay` je vypnutý a zprávy handshaku jsou omezené na 512 B.

## Poslední změny
- **2026-11-03, M2 krok 3:**
  - **`src/net/upnp_helper.gd`:** vlákno, mutex, neblokující zavření, `wait_for_all()`.
  - **Connector:** `close()`, `internet_status()`, signál `share_info_changed`.
  - **`EnetDirectConnector`:** UPnP při hostování, detekce CGNAT, veřejná adresa.
  - **`Session`:** kód hry (`generate_room_code`, kontrola v handshaku, `ERROR_WRONG_CODE` a `ERROR_MISSING_CODE`), `server_relay = false`, limit 512 B, úklid při `WM_CLOSE_REQUEST`.
  - **Lobby:** kód hry, stav UPnP, bezpečnostní upozornění.
  - **README:** sekce Bezpečnost a aktualizovaný návod Jak hrát.
  - **PLAN.md, sekce S** (bezpečnost); `tests/test_room_code.gd`.
- **2026-11-03, M2 krok 2:**
  - **`src/autoload/settings.gd`** (autoload `Settings`): jméno a poslední adresa v `user://settings.cfg`.
  - **`src/ui/main_menu.*`:** pole jména a adresy, Hostovat a Připojit, stav „Připojuji se…“, chybové hlášky.
  - **`src/ui/lobby.*`:** seznam hráčů, adresy ke sdílení s kopírováním, Odejít, při konci session návrat do menu.
  - **`Connector.share_addresses()`** a **`EnetDirectConnector.address_kind()`:** rozsah 100.64/10 se rozlišuje podle rozhraní. Knihovní Wi-Fi ho používá jako LAN, Tailscale jako VPN.
  - **`Session`:** `last_end_message`, `host_port`, `share_addresses()`.
  - **Vstupy:** střelba = levé tlačítko myši, schopnost = pravé tlačítko nebo E (README).
  - **Zadání uživatele:** míření ke kurzoru (PLAN.md C, D.3, D.5), pixel-art styl (PLAN.md Q, reference v gitignored `art_reference/`), testy na Windows až na konci (CLAUDE.md).
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
   - **krok 3:** UPnP (`src/net/upnp_helper.gd` ve vlákně), veřejná IP v lobby, detekce CGNAT a doporučení Tailscale
   - **krok 4:** synchronizace pohybu: start zápasu z lobby, spawn hráčů, vstupy 60 Hz → host (**včetně úhlu míření ke kurzoru**), snapshoty 30 Hz (včetně `aim`), interpolace (`snapshot.gd`, `match_net.gd`, `remote_interpolator.gd`)
   - **krok 5:** `LagSimulator`, test na 2 počítačích v LAN a **první internetový test** (z domova nebo přes Tailscale)
3. M3: souboj = MVP (`v0.1.0`).

Ostatní milníky viz PLAN.md, sekce K.

## Známé problémy
- **Internetové testy z knihovny:** uživatel je teď v knihovně. Veřejné Wi-Fi sítě skoro jistě neumožní hostovat (NAT nebo CGNAT, žádný přístup k routeru, často izolace klientů), někdy blokují i UDP.
  - Pro internetový test v M2: hostovat **z domova**, nebo použít **Tailscale**.
  - Typ připojení hostitele (veřejná IPv4 / CGNAT) se zjistí v M2 z výsledku UPnP.
- **Velikost buildů:** Windows exe má ~110 MB (ZIP ~39 MB, změřeno lokálně), macOS ZIP ~62 MB. To je dáno šablonami Godotu 4.7.
- Ikona hry a exe je výchozí ikona Godotu (vlastní přijde v M8).
- **`session.gd` má 292 řádků** (limit ~300). Před dalším rozšiřováním rozdělit (Další krok 4a).
- **UPnP hledání routeru trvá 8–12 s** (sítě bez UPnP). Lobby mezitím ukazuje „Zkouším…“. Zavření hry v té době čeká až ~6 s.
- **Grafika:** cílový pixel-art styl (PLAN.md, sekce Q) vyžaduje sprity. Zdroj zatím není rozhodnutý (vlastní kresba, objednávka, nebo CC0 assety), proto zatím placeholdery.
- `EDITING_GUIDE.md` zatím neexistuje (plán: M5).
- `ArenaData` resource zatím neexistuje, aréna je pevně v `match_controller.gd` (výběr arény přijde v M6).
- Varování o „leaked RID/ObjectDB“ při exportu bylo opraveno v `platform.gd` (tvar se přidává v `_init`).

## Stav testů
- **Unit testy:** 16/16 OK (+ kód hry: formát a náhodnost).
  - `PlayerMotor` (8): skok, držený skok, coyote, dvojskok, buffer, rozjezd, knockback se neruší, seskok
  - adresy (6): rozbor IPv4, hostname, IPv6, neplatné vstupy, druh adresy, rozsah 100.64/10 podle rozhraní
- **Síť, lokálně na jednom Macu** (headless procesy, 127.0.0.1 a `[::1]`, M2 krok 1):
  - host a 3 klienti: všichni v lobby, správná jména (Hráč 2–4), seznam se rozešle všem
  - 4. klient dostane „Hra je plná“
  - klient s `--fake-commit` dostane českou hlášku o jiné verzi a je odpojen
  - odchod klienta: host ho odebere a rozešle nový seznam
  - odchod hostitele: klienti dostanou „Hostitel ukončil hru…“
  - nedostupný host: po 10 s „Nepodařilo se připojit…“
  - neplatná adresa a obsazený port: správné hlášky
  - Poznámka: testovací skripty při ukončení hlásí „resources still in use at exit“. Je to pravděpodobně artefakt testovacích skriptů (lambdy na autoloadu), ve hře neověřeno.
- **UI s okny, lokálně na Macu** (M2 krok 2, skript mačká tlačítka, snímky obrazovky):
  - host a klient: oba v lobby, správný seznam se štítky (hostitel) a (ty)
  - host vidí adresu `100.64.45.243:24642` jako „Stejná Wi-Fi / síť“ (knihovna)
  - klient s jinou verzí: červená česká hláška v menu
  - hostitel klikne Odejít: klient se vrátí do menu s hláškou „Hostitel ukončil hru…“
  - jméno a adresa se uloží do `settings.cfg`
  - **Neotestováno:** tlačítko Kopírovat (schránka) a ruční ovládání myší
- **M2 krok 3, lokálně v knihovně:**
  - správný kód (i malými písmeny): klient je v lobby
  - špatný kód: „Špatný kód hry…“
  - chybějící kód: „Chybí kód hry…“
  - UPnP v knihovně: po ~8–12 s stav „nepovedlo se“ a česká hláška v lobby (snímek)
  - odchod během hledání routeru neblokuje (1 ms)
  - zavření okna během hledání počká na vlákno (~6 s) bez varování
  - **NETESTOVÁNO:** úspěšné UPnP, detekce CGNAT se skutečným routerem, hra přes internet. Ověřit doma.
- **Kontrola lokalizace:** 42 klíčů, 0 chybí. Ověřeno, že při chybějícím klíči skončí s exit 1.
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
- **Míření ke kurzoru myši** (změna oproti Gun Mayhem, zadání uživatele): `aim` úhel se posílá ve vstupu klienta už od M2 kroku 4, aby se formát zprávy v M3 neměnil.
- **Pixel-art styl** podle reference v `art_reference/` (cizí dílo, gitignored, jen reference). Zdroj vlastní grafiky zatím nevyřešen.
- **Testy na Windows až na konci projektu**, pokud uživatel neřekne jinak. Kód musí zůstat multiplatformní.
- **Bezpečnost online hry** (požadavek uživatele, PLAN.md S): kód hry, `server_relay` vypnutý, žádné objekty ze sítě, limity velikosti, UPnP jen 1 port s časovým limitem, Tailscale jako nejbezpečnější varianta.
- **Kód hry se sdílí v adrese za `#`:** jedno kopírování obsahuje vše a nezávisí na konektoru (zpracuje ho `Session`).
- **CI bez actions třetích stran** (kromě checkout a cache) a s vlastním `setup_env.sh`: méně křehké při nové verzi Godotu.
