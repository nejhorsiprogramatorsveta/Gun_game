# Stav projektu

## Kde jsme skončili
**Kadence pistole je lokálně zvýšená z 3 na 9 ran/s (trojnásobek) a přidaná do aktuálního changelogu.** Changelog z předchozího úkolu také zůstává lokálně: „Co je nového“ v menu, offline historie a stejné texty v poznámkách vydání. Bez commitu a bez pushe. Poslední publikovaný herní commit zůstává `da40eac` (dev sestavení 27, push provedl uživatel). Sekání Wi-Fi klientů je stále odložené do PLAN.md M4.1.
- Ověřeno: **74/74 unit testů, 35/35 kontrol dialogu, 18/18 kontrol samostatného exportovaného balíčku**, lokalizace a lokální generátor dev/stable poznámek. Otevření: hlavní menu → „Co je nového“; zavření tlačítkem nebo Esc.
- Changelog používá `data/changelog.tres` a české texty v CSV. Aktuální záznam převezme skutečnou verzi/build; historie obsahuje sestavení 27, 26 a 25. Starší build nezobrazuje budoucí změny. Před další obsahovou změnou archivovat aktuální záznam pod jeho skutečným vydaným buildem a založit nový.
- Pistole: odhoz 550 → 800 (přibližně +45 %). Scoreboard vedle jmen ukazuje životy/zabití/smrti, stejné skóre je ve výsledcích. Každá smrt se připíše poslednímu účinnému střelci; bez zásahu jen smrt. Série stejného střelce do 2 s zobrazí DOUBLE/TRIPLE/MULTI KILL.
- Klient ihned simuluje vlastní pohyb, obnovuje úplný stav z hostu a přehrává nepotvrzené vstupy. Malé korekce vyhlazuje pouze vizuálně; vzdálení hráči dál interpolují.
- Ověřeno pro skóre: **65/65 unit testů, lokalizace, 225/225 kontrol UI a 38/38 síťových kontrol se čtyřmi skutečnými procesy**. Předchozí M4: 57/57 lokálních síťových kontrol včetně +100 ms/5 % a +200 ms/10 %; tato měření nenahrazují nynější hlášení uživatele o sekání na skutečné Wi-Fi.
- **Publikace a aktualizátor se nemění:** `main` → stejný `dev`, tag `v*` → stable, rostoucí buildy a soubory hry před `version.json`. CI nově pouze generuje poznámky přes `tools/write_release_notes.gd`. Porovnáním workflow ověřeno, že mimo tento krok je totožné; updater, `BuildInfo`, export presety, kanály/URL a SHA-256 zůstávají bez změn.
- **Codex nesmí pushovat bez nového výslovného souhlasu; uživatel jej NEUDĚLIL (2026-11-04).** Codex nic necommitnul ani nepushnul. Nové změny zůstávají lokálně; jejich CI neběželo.
- **Pozor:** verze bez aktualizátoru (0.1.0, sestavení 23–24) si hráči musí **naposledy stáhnout ručně**. Od verze s aktualizátorem se nabídka objeví sama.
- Necommitnuté soubory: `.github/workflows/build.yml` (jen generování poznámek), `CLAUDE.md`, `docs/{PLAN,ARCHITECTURE,PROGRESS}.md`, `data/weapons/pistol.tres`, `localization/translations.csv`, `src/ui/main_menu.{gd,tscn}`, nové `data/changelog.tres`, `src/core/changelog.gd`, `src/data_types/changelog_data.gd`, `tools/write_release_notes.gd`, `tests/test_changelog.gd` a jejich UID.

## Další krok
**M4: doplnit debug měření RTT a velikosti korekcí** (PLAN.md K, M4).
- Přidat debug ukazatel RTT a korekcí vlastní postavy do HUD, texty přes CSV; ověřit s `--fake-lag=100/200` a ztrátami paketů. Changelog už je hotový.
- Zachovat dosavadní vydávání (`main` → `dev`, `v*` → stable), rostoucí buildy, kanály/URL a aktualizátor; soubory hry před manifestem.
- Sekání skutečných Wi-Fi klientů je v PLAN.md M4.1; **opravu nyní nespouštět, vyžaduje samostatné zadání.**
- Žádný commit ani push bez nového výslovného souhlasu. Vydání `v0.2.0` je samostatný pozdější krok.

## ODLOŽENO NA KONEC PROJEKTU (uživatel 2026-11-03: „Windows ověříme až na konci, pokud neřeknu jinak“)
**Neptat se na to v každé session.**
- **Další měření na více počítačích a Tailscale:** uživatel 2026-11-04 nahlásil, že spojení na stejné Wi-Fi funguje, ale všem klientům kromě hostitele se hra velmi seká. Výsledek je zapsán; podrobné měření a oprava jsou na jeho pokyn odložené (PLAN.md M4.1). Tailscale není ověřený.
- Ruční test staženého `gun_game-windows.zip` na Windows PC:
  - SmartScreen
  - menu s verzí
  - trénink
  - firewall při hostování
  - Tailscale
- Případně i `gun_game-macos.zip` stažený v prohlížeči (Gatekeeper).
- Do té doby se hra na Macu spouští lokálně: `tools/godot --path .` z kořene projektu.

## Aktuální stav
- **Milník:** M3 a M3U hotové; M4 predikce a skóre vydané jako dev sestavení 27. Changelog hotový lokálně, navazuje debug měření. Odložené ruční testy viz výše.
- **Dodatek dle zadání 2026-11-04:** silnější pistole, scoreboard životů/zabití/smrtí a kill hlášky; autorita skóre je na hostu, síťový protokol 5. Sekání reálných Wi-Fi klientů není vyřešené.
- **Funguje** (ověřeno lokálně na macOS arm64):
  - menu s verzí, jménem a českými texty
  - trénink: běh, skok, dvojskok, seskok z plošiny, respawn po pádu, Esc do menu
  - hostování a připojení: kód hry, kontrola verze, seznam hráčů (max. 4), české chybové hlášky (jiná verze, špatný nebo chybějící kód, plné lobby, odchod hostitele, nedostupný host, obsazený port)
  - lobby: hráči se štítky, adresy ke sdílení (Tailscale, stejná Wi-Fi) s kopírováním, nápověda, jestli je Tailscale zapnutý
  - export a CI: ZIPy pro Windows, macOS a Linux na `releases/tag/dev`
- **Společný zápas (M2 krok 4b):**
  - hostitel spustí zápas z lobby (min. 2 hráči)
  - pohyb, skoky a míření všech hráčů se synchronizují
  - jména nad postavami, barva podle slotu
  - odchod hráče nebo hostitele uprostřed zápasu funguje
  - Esc v zápase = odejít
- **Simulace sítě pro testy (M2 krok 5):** `-- --fake-lag=100 --fake-loss=5 [--fake-jitter=10]` (jen debug buildy, v zápase ukazuje [TEST] nápis).
- **Střelba (M3 krok 1):**
  - pistole (`data/weapons/pistol.tres`), drž levé tlačítko = 9 ran/s (původně 3)
  - střela letí ke kurzoru a prolétá tenkými plošinami
  - zásah odhodí soupeře, výstřel dá zpětný ráz
  - online zásahy počítá jen host, klienti střely vidí (spolehlivé události)
  - cvičný panák v tréninku
- **Zápas (M3 krok 2):**
  - odpočet 3-2-1 (jen míření)
  - 5 životů, pád = −1, respawn s 1,5 s nezranitelností (bliká, zásahy pohltí)
  - 0 životů = vypadává, poslední živý vyhrává
  - výsledky (pořadí) a automatický návrat do **stejného lobby** za 8 s (hostitel i tlačítkem)
  - HUD se životy
  - Esc: hostitel ukončí zápas pro všechny, klient odejde
  - Trénink má nekonečné životy.

## Poslední změny
- **2026-11-04, trojnásobná kadence (lokálně, bez commitu/pushe):** `data/weapons/pistol.tres` má `shots_per_second = 9.0` místo `3.0`; ostatní parametry zbraně a střelecká logika se nemění. Novinka přidaná do aktuálního, dosud nepublikovaného záznamu changelogu a CSV.
- **2026-11-04, implementace changelogu (lokálně, bez commitu/pushe):**
  - Tlačítko „Co je nového“ otevírá rolovací offline dialog, záznamy nejnovější první; překlady v CSV.
  - `Changelog` a `ChangelogData` načítají historii z `.tres`, aktuální metadata z `BuildInfo`, filtrují budoucí záznamy a sdílejí text s generátorem poznámek.
  - `tools/write_release_notes.gd` zapisuje poznámky přímo do souboru v češtině; CI volá tento nástroj místo původního heredocu. Zbytek workflow/publikace, updater, číslování a export presety beze změny.
  - Dev i stable generátor ověřen v izolované kopii projektu s testovacími metadaty (nejde o skutečně publikované sestavení/verzi). Ověřen samostatný exportovaný PCK bez dostupného zdrojového projektu.
  - 9 testů changelogu; celkem 74/74 testů OK včetně dosavadních testů aktualizátoru. Lokalizace: 93 klíčů, 0 chybějících.
  - Dialog ověřen při 1280×720 a 640×360: posuvný obsah, správné rozměry a oddělené tlačítko Zavřít, Esc a návrat fokusu. Changelog nespojuje žádnou novou HTTP komunikaci.
- **2026-11-04, plán changelogu a kontrola vydávání (jen dokumentace):**
  - Changelog nastaven jako nejbližší úkol v PLAN.md K, této sekci „Další krok“ a `CLAUDE.md`. Zatím pouze plán, žádná implementace.
  - Po uživatelově pushi commitu `da40eac` ověřen úspěšný [CI běh](https://github.com/nejhorsiprogramatorsveta/Gun_game/actions/runs/41836731732), aktualizované soubory releasu `dev` a manifest dev sestavení 27. Datum vytvoření rolling releasu zůstává původní; stabilní `v0.1.0` se pushem na main nemění.
  - Workflow, aktualizátor, menu a export presety se od předchozího vydání `a067293` nezměnily. Zůstává pořadí soubory hry → manifest, výběr dev/stable URL, kontrola vyššího sestavení a SHA-256. End-to-end instalace aktualizace se nyní neopakovala.
  - Žádný commit ani push od Codexu; kontrola rozdílů a `git diff --check`.
- **2026-11-04, silnější odhoz a skóre (lokálně, bez commitu/pushe):**
  - Pistole má `knockback = 800` místo 550; kadence, rychlost střely a zpětný ráz se neměnily.
  - **`MatchScore`:** poslední účinný zásah určuje autora každého zabití bez časového limitu do smrti. Po smrti se přiřazení smaže; nezranitelnost ani vlastní zásah jej nepřepíší. Odpojený střelec nedostane kredit, posmrtné zabití se počítá.
  - Projektil si pamatuje střelce a host zaznamenává účinné zásahy. Pád zvýší smrti, případnému střelci zabití; respawn součty zachová, nový zápas začíná od nuly.
  - **HUD:** přehled u jmen s životy/zabitími/smrtmi, v tréninku ∞ životů; dvousekundové hlášky KILL / DOUBLE / TRIPLE / MULTI KILL. Série se skládá ze zabití stejného střelce v rozestupu nejvýše 2 s. Součty jsou i ve výsledcích.
  - **Protokol 5:** snapshot 6 B + 33 B na hráče včetně zabití/smrtí; kill hlášky spolehlivým RPC pouze od hosta. Přenos a simulace pohybu se kvůli Wi-Fi problému neopravovaly.
  - **Plán M4.1:** nahlášené sekání klientů na skutečné Wi-Fi, budoucí reprodukce na 2–4 počítačích, měření časů snímků/RTT/front/vstupů/snapshotů/korekcí a teprve následná oprava. Žádná příčina zatím není potvrzená.
  - **Instrukce Git:** odstraněno rozporné automatické povolení k pushi pro Codex; souhlas nyní není udělen.
- **2026-11-04, M4 predikce vlastního pohybu (lokální změny, bez commitu/pushe):**
  - Před implementací přečten celý repozitář: zdroje, testy, scény, data, lokalizace, dokumentace a nástroje.
  - **`ClientPrediction`:** historie až 120 vstupů a výsledných stavů, potvrzování podle `last_seq` včetně přetečení, obnova a replay sdíleným motorem, omezená historie při výpadku. Smrt/respawn a velké korekce se zobrazí okamžitě.
  - **Snapshot, protokol 4:** 29 B na hráče; nově kontakt se zemí, předchozí tlačítka, počet skoků a časovače bufferu/seskoku. Validace slotů, konečných čísel a časovačů.
  - **Reconciliation pouze ve fyzikálním ticku:** příchozí snapshot se nejprve uloží; staré/duplicitní ticky se zahodí. Novější snapshot se stejným `last_seq` se zpracuje.
  - **`Player`/`PlayerMotor`:** úplná obnova pohybu a kolizí; vizuální offset pro malé opravy. Neaktivní postavy mají vypnuté kolize. Nezranitelnost odpočítává jen host.
  - **Odpočet:** zachovává číslo zpracovaného vstupu, dovolí jen míření. Při přechodu na výsledky/lobby se simulace a zpracování vstupů zastaví.
  - **Testy:** 9 nových testů predikce a další test kodeku; architektura a projektové instrukce aktualizovány.
  - **Pokyn uživatele:** Codex nesmí pushovat; zákaz je uložen i v `CLAUDE.md`.
- **2026-11-03, opravy a úpravy podle uživatele:**
  - **Hráč na hlavě jiného hráče z ní sklouzne do strany** (`PlayerMotor._slide_off_heads`). Řeší zaseknutí po respawnu na hráči.
  - **Respawn na nejvolnějším místě** (`Arena.free_spawn_point`)
  - **Horní okraj arény je otevřený** (vyletět nahoru nezabíjí). Život se ubere až po 0,5 s mimo arénu (`MatchRules.out_of_bounds_grace`), prostor pro budoucí létání.
  - **Hra startuje v maximalizovaném okně** (`window/size/mode=2`)
  - CI nevytváří nový build ani pro `.gitignore` a `.gitattributes`
  - **Plán M8:** hudba, zvuky postav a zbraní, menu Nastavení (hlasitost, FPS, celá obrazovka, přenastavení kláves) až na konci
  - `tests/test_arena.gd`
- **2026-11-03, M3U automatické aktualizace:**
  - **`src/core/updater.gd`:**
    - po spuštění menu stáhne `version.json` (dev → `releases/download/dev`, stable → `releases/latest/download`)
    - při vyšším čísle sestavení nabídne aktualizaci, stáhne ji s průběhem vedle hry a ověří SHA-256
    - vymění se: Windows a Linux přejmenováním běžícího souboru na `.old`, Mac výměnou `.app` z ZIPu (bez zápisu mimo složku)
    - restartuje se
    - při startu uklidí `.old` a nedokončená stažení
    - při chybě nabídne „Stáhnout ručně“
  - **Bezpečnost:** jen adresy releasů tohoto repa, kontrola SHA-256 a velikosti manifestu, stará verze zůstává při jakékoli chybě
  - **Zapnutí:** jen v exportech z CI (ne v editoru). Debug přepínač `-- --update-test=URL` pro testy.
  - **CI:** generuje `version.json` (verze, sestavení, kanál, URL a SHA-256 pro každý systém) a nahraje ho až po souborech hry
  - **Menu:** panel aktualizace. 9 nových textů. `tests/test_updater.gd` (5 testů).
- **2026-11-03, M3 krok 2 + `v0.1.0`:**
  - **Snapshot:** odpočet, životy, nezranitelnost (`PROTOCOL_VERSION` 3)
  - **`Session`:** fáze `RESULTS`, `end_match()`, `return_to_lobby()`
  - **`match_controller.gd`:** životy, vypadávání, odpočet, konec zápasu, pořadí
  - **`src/ui/match_hud.gd`** (životy a odpočet), **`src/ui/results.*`**
  - **`match_net.gd`:** po konci zápasu nic neposílá (žádné chyby „Node not found“), obě strany čekají 0,5 s před změnou scény
  - **README:** průběh hry
- **2026-11-03, úpravy podle uživatele:**
  - střely pomalejší (pistole 1500 → 1000 px/s) s delší stopou (40 px)
  - pohled zmenšen na 70 % (zoom 0,85 → 0,6), `kill_rect` rozšířen za okraj obrazovky
  - **postavy se nepřekrývají** (kolidují spolu, mohou stát na sobě)
  - **střelba zblízka funguje** (`hit_from_inside`)
  - větší jména nad postavami
  - plán: mapy také pixel art, animace postav (PLAN.md Q)
- **2026-11-03, M3 krok 1 (střelba):**
  - **Data:** `WeaponData` + `data/weapons/pistol.tres`; `CharacterData.weapons` a `knockback_friction` (odhoz klouže i po zemi)
  - **Logika:** `src/combat/combat_rules.gd` (odhoz, zpětný ráz, rozptyl, kadence), `src/combat/projectile.gd` (raycast každý tick), `src/combat/weapon_system.gd` (střelba na hostu, události pro klienty)
  - **Propojení:** `ContentDB.get_weapon()`, `match_net.gd` (reliable `projectile_spawned/removed`), `LagSimulator` neztrácí reliable zprávy
  - **Trénink:** cvičný panák (peer −1)
  - **Testy:** `tests/test_combat_rules.gd` (5) + test odhozu po zemi
- **2026-11-03, čitelné verze:**
  - CI zapisuje číslo sestavení (počet commitů na main), menu ukazuje „Verze 0.0.0 (sestavení 31)“ místo kódu commitu. Commit zůstává uvnitř `build_info.json`.
  - `build_id` = `verze+sestavení`, chybová hláška o verzi ukazuje čitelné verze
  - `tests/test_build_info.gd`
- **2026-11-03, styl map:** PLAN.md Q, reference `art_reference/map_style_reference.png` (gitignored, cizí dílo).
- **2026-11-03, CI bez nových buildů pro dokumentaci:** `paths-ignore` (`docs/**`, `**/*.md`). Důvod: uživatel měl `d265616`, kamarádi `2cec77d` (liší se jen dokumentací), a kontrola verze je nepustila k sobě.
- **2026-11-03, Windows bez ZIPu (přání uživatele):** CI publikuje `gun_game-windows.exe` přímo (~110 MB místo ZIPu ~39 MB) a starý `gun_game-windows.zip` z release `dev` maže. macOS zůstává ZIP (.app je složka), Linux ZIP (zachová oprávnění ke spuštění). README upraven.
- **2026-11-03, M2 krok 5:**
  - **`src/net/lag_simulator.gd`:** zpoždění, jitter a ztráta paketů, zachovává pořadí. Jen debug buildy.
  - napojeno v `match_net.gd` na vstupy a snapshoty, [TEST] nápis v HUD
  - **Vlastní postava klienta má kratší interpolační zpoždění** (40 ms místo 100 ms): reakce 138 → 96 ms bez lagu
  - `tests/test_lag_simulator.gd`
- **2026-11-03, M2 krok 4b:**
  - **`Session`:** fáze `IN_MATCH`, `start_match()` (host, min. 2 hráči), RPC `_begin_match` se sloty
  - **Lobby:** tlačítko *Začít zápas*, „Čekáme na hostitele“, přechod do zápasu
  - **`InputFrame`:** `seq`, `aim` (u16 úhel ke kurzoru), `sample_local(origin)` s myší. Postava se otáčí podle míření.
  - **`src/net/net_codec.gd`:** binární vstupy (3 snímky kvůli ztrátám, 14 B) a snapshoty (18 B na hráče), kontrola velikosti, `seq_newer`
  - **`src/match/match_net.gd`:** jediné RPC zápasu
    - vstupy klient → host a snapshoty host → klienti (unreliable_ordered)
    - „loaded“ handshake s opakováním
    - rate-limit 150 paketů/s
  - **`match_controller.gd`:** společný průběh pro trénink i síť
    - host simuluje všechny ze vstupů (fronta max. 6, při výpadku opakuje poslední vstup)
    - snapshot 30 Hz
    - klient posílá vstup 60 Hz
    - odchod hráče
  - **`src/player/remote_interpolator.gd`:** zobrazení se zpožděním 100 ms, prolínání, okamžitý skok při respawnu
  - **`player.gd`:** `simulate`, `snapshot_state`, `receive_state`, jméno, barva slotu, čára zbraně ve směru míření
  - **`PROTOCOL_VERSION = 2`**
  - **Testy:** `tests/test_net_codec.gd` (7 testů) + test „postava se dívá podle míření“
- **2026-11-03, oprava skoku a zoom:**
  - `PlayerMotor`: místo coyote time počítadlo `jumps_left = 1 + air_jumps` (reset na zemi). Po sejití z hrany i po odhození jsou vždy 2 skoky, ve vzduchu jen nový stisk, buffer jen pro dopad.
  - Odstraněno `coyote_time` z `CharacterData` a `jiskra.tres`.
  - Test regrese `test_walking_off_ledge_keeps_both_jumps`.
  - Aréna má `Camera2D` se zoomem 0,85 (vše na 85 %, uprostřed). Mění se v `arena_rooftops.tscn` → uzel Camera → Zoom.
- **2026-11-03, Tailscale místo UPnP (rozhodnutí uživatele):**
  - odstraněn `src/net/upnp_helper.gd` a UPnP z konektoru, `Session` a lobby
  - `share_addresses()` vrací jen Tailscale a LAN, Tailscale se na Windows pozná podle „friendly“ názvu rozhraní
  - README: návod Tailscale (sekce Bezpečnost později na přání uživatele odstraněna)
  - PLAN.md: sekce S a M7 je volitelný
- **2026-11-03, plán postav:** 4 postavy, 2 přepínatelné zbraně a schopnost (PLAN.md G.0).
- **2026-11-03, M2 krok 4a:** handshake přesunut do `src/net/handshake.gd`, testy `tests/test_handshake.gd`.
- **M0–M2 krok 3** (shrnutí, detaily v gitu):
  - kostra, pohyb, CI
  - `Session` + `EnetDirectConnector`
  - menu a lobby + `Settings`
  - kód hry a bezpečnostní opatření

## Známé problémy
- **Changelog je zatím jen lokální změna.** V aktuálním veřejném sestavení 27 ještě není; publikace čeká na uživatele, bez automatického commitu/pushe od Codexu.
- **Stejná Wi-Fi: výrazné sekání všech klientů kromě hosta** (nahlášeno uživatelem 2026-11-04). Příčina neměřená, oprava výslovně odložená; viz PLAN.md M4.1. Lokální headless síťové testy tento problém nevyvracejí.
- **Každá změna hry = nová verze:** hra ji od M3U sama nabídne v menu. Verze bez aktualizátoru (≤ sestavení 24) je potřeba naposledy stáhnout ručně.
- **`session.gd` má 306 řádků** (limit ~300). Kandidát na rozdělení: přesunout fázové RPC (start, konec, návrat) do samostatného uzlu nebo skriptu.
- **Tailscale postup v README** (Share počítače, firewall na Windows) je napsaný podle dokumentace, prakticky zatím neověřený. Ověřit při prvním testu s kamarádem.
- **Predikce je zatím ověřená automaticky lokálně.** Skutečný internet a ruční hodnocení plynulosti korekcí čekají na hráče. Střelbu, zpětný ráz a odhoz dál potvrzuje host; M4 predikuje jen pohyb.
- **Kolize s pohybujícími se soupeři při replay používají jejich aktuální interpolované pozice.** Mohou vyvolat korekce od hostu; historické přetáčení soupeřů není součást M4.
- **Hostitel nemá zpoždění** (výhoda hostitele, PLAN.md M).
- **Interpolace neextrapoluje:** při výpadku snapshotů postava stojí na poslední pozici.
- **Knihovní Wi-Fi** (síť uživatele) používá rozsah 100.64.x.x a často blokuje provoz mezi zařízeními. Ověřovat raději doma nebo přes Tailscale.
- **Velikost buildů:** Windows ZIP ~39 MB, macOS ZIP ~62 MB (dáno šablonami Godotu 4.7).
- Ikona hry je výchozí ikona Godotu (vlastní přijde v M8).
- **Grafika:** cílový pixel-art styl (PLAN.md, sekce Q) vyžaduje sprity. Zdroj zatím nerozhodnutý, proto placeholdery.
- `EDITING_GUIDE.md` zatím neexistuje (M5). `ArenaData` zatím neexistuje, aréna je pevně v `match_controller.gd` (M6).
- Testovací skripty při ukončení hlásí „resources still in use at exit“. Je to pravděpodobně artefakt testovacích skriptů, ve hře neověřeno.

## Stav testů
- **2026-11-04, kadence 3 → 9:** 6/6 stávajících combat testů OK; přímá runtime kontrola `ContentDB.default_character()` → `Player.current_weapon()` potvrzuje pistoli s `shots_per_second = 9.0` a intervalem `1/9 s`. Import, lokalizace 94 klíčů / 0 chybějících a `git diff --check` OK. Ověřovací skript `.tools/verify_pistol_rate.gd`; žádná změna logiky střelby ani nový test ve sledovaných souborech.
- **2026-11-04, changelog:** 74/74 unit testů OK (9 nových: aktuální metadata, lokální dev, filtrování budoucích záznamů, shoda menu/poznámek, pořadí a úplnost textů, izolace dat a formátování). Dosavadní testy aktualizátoru součástí běhu. Import a lokalizace 93 klíčů / 0 chybějících OK.
- **Dialog changelogu:** 35/35 kontrol OK při 1280×720 (dialog 840×560) a 640×360 (576×324): otevření tlačítkem, shoda se společným formátovačem, pořadí, čeština, doslovné zobrazení bez BBCode, rolování a návrat na začátek, zavření tlačítkem/Esc, vrácení fokusu, prázdný stav a oddělení obsahu od tlačítka. Updater zůstává odpojený. Skript `.tools/changelog_ui_smoke.gd`; headless, nikoli ruční test stažené hry.
- **Poznámky vydání:** skutečný headless generátor ověřen lokálně pro syntetické dev i stable metadata v `.tools/changelog_release_validation/`, správná verze/build, jen nejnovější změny, stejné názvy souborů a odkaz na README. Žádná publikace se neprováděla.
- **Export a offline data:** Windows `--export-pack` bez stahování šablon, samostatný PCK běh z adresáře bez zdrojového projektu: 18/18 kontrol OK (zabalená historie a čeština, nadpisy/odrážky všech záznamů, offline session). Report `.tools/changelog_offline_run/changelog_pack_results.json`.
- **Distribuce:** programově porovnáno celé workflow s HEAD po vynechání kroku Release notes — shodné. Žádné změny updateru, číslování ani export presetů. Skutečný CI běh a nová end-to-end instalace aktualizace se neprováděly; nic nebylo pushnuté.
- **2026-11-04, dokumentace/plán:** ověřeno, že release workflow, updater, menu a export presety nemají rozdíl mezi `a067293` a `da40eac` ani lokální změny. `git diff --check` OK; herní testy se pro pouhou dokumentaci neopakovaly. CI pro `da40eac` dříve ověřeno jako úspěšné, manifest dev má build 27; nová end-to-end instalace aktualizace neproběhla.
- **2026-11-04, skóre/odhoz, automaticky lokálně na Windows, Godot 4.7.2:** **65/65 unit testů OK**. Přibylo 9 testů přiřazení zabití/sérií (včetně odpojení, respawnu a poslední kulky), test skutečného signálu zásahu/nezranitelnosti a test přenosu rozsahu skóre. Snapshot roundtrip ověřuje i K/D a odmítnutí starého formátu.
- **UI skóre:** **225/225 kontrol OK** na skutečných scénách při 1280×720: čtyři šestnáctiznaková česká jména, seřazení a barvy slotů, životy/vypadnutí, tréninkové ∞, počty zabití/smrtí, hlášky/časování a výsledky. Buňky a výsledky se nepřekrývají. Skript lokálně `.tools/ui_score_smoke.gd`.
- **Síťové skóre:** **38/38 kontrol OK**, host + 3 skuteční ENet klienti na localhostu (14 kontrol hosta, po 8 na klienta). Skutečně vystřelené projektily zasáhly tři cíle; jejich pády v jednom ticku připsaly hostovi 3 zabití. Všichni klienti obdrželi po řadě KILL / DOUBLE KILL / TRIPLE KILL, stejné K/D ve snapshotech, HUD i výsledcích a vrátili se do stejného lobby se čtyřmi hráči. Reporty/logy lokálně `.tools/score_smoke_20261104_140132/`, skripty `.tools/{score_smoke.gd,run_score_smoke.ps1}`. Bez funkčních/scriptových/síťových chyb; přetrvávají známé zprávy sandboxu o certifikátech a ukončovací resource warnings.
- **Lokalizace:** 71 použitých klíčů, 0 chybějících. Import projektu a `git diff --check` OK.
- **Hlášení uživatele 2026-11-04:** na skutečné stejné Wi-Fi všem klientům kromě hosta hra výrazně seká. Uloženo do plánu, nikoli opraveno.
- **Dříve v této session, M4:** 54/54 testů OK (predikce, replay, přetečení sekvencí, obnova motoru, odpočet, smrt/respawn, omezená historie a odložené/staré snapshoty).
- **M4, dvě skutečné ENet instance na 127.0.0.1 (Windows, headless, 120 FPS limit):** 57/57 kontrol OK, po 8 na hostu a 11 na klientovi pro každý profil. Ověřeno: držený vstup během odpočtu, okamžitý běh/skok/dvojskok/seskok, odhoz od hostu, skrytí při smrti, respawn s nezranitelností, eliminace, výsledky a návrat do stejného lobby.

  | Simulace pouze na klientovi | První pohyb po stisku | Největší vizuální offset během běhu | Offset 0,45 s po zastavení |
  |---|---|---|---|
  | bez lagu / 0 % ztrát | 20,7 ms | 0 px | 0 px |
  | +100 ms / 5 % ztrát | 17,6 ms | 10,5 px | 0 px |
  | +200 ms / 10 % ztrát | 14,8 ms | 0 px | 0 px |

  - Ve všech případech jde o **první fyzikální snímek**. Časy jsou jednotlivá měření při souběhu headless procesů, nikoli statistický benchmark nebo měření zobrazení na monitoru.
  - Testovací skripty, JSON výsledky a logy jsou lokálně v gitignored `.tools/`: `m4_smoke.gd`, `run_smoke.ps1`, `m4_validation_summary.json`, `m4_final_*`. Původní dočasný měřicí skript z M2 není v repozitáři; použit nový ekvivalent.
  - Logy bez `SCRIPT ERROR` nebo síťových chyb. Sandbox hlásí nedostupný systémový seznam certifikátů; testovací procesy při ukončení také známá varování o neuvolněných prostředcích/časovačích.
- **CI publikovaných herních změn:** commit `da40eac`, úspěšný běh a dev sestavení 27 (push provedl uživatel). Nový changelog není commitnutý ani pushnutý. Ruční Windows testy a Tailscale zůstávají odložené.
- **Dříve:** 44/44 OK (+ aréna: otevřený horní okraj, volný spawn)
- **Dříve:** 42/42 OK (+ updater: manifest, výměna souboru, obnova při chybě, Linux ZIP, Mac `.app` a ochrana proti `..` v ZIPu)
- **Dříve:** 37/37 OK (+ snapshot s životy a odpočtem)
- **Dříve:** 37/37 OK (+ souboj a odhoz po zemi)
- **Dříve:** 30/30 OK (+ LagSimulator)
- **Dříve:** 27/27 OK (+ kodek vstupů a snapshotů, podvržené pakety, přetečení seq, míření, interpolace)
- **Dříve:** 19 testů
  - pohyb (8)
  - adresy (6)
  - handshake (5): kód hry, rozdělení adresy, shoda buildu a kódu, podvržené a nesmyslné zprávy
- **Kontrola lokalizace:** 0 chybějících klíčů. Při chybě skončí s exit 1.
- **Síť lokálně** (headless procesy a okna se snímky, macOS):
  - host + 3 klienti
  - plné lobby, jiná verze, špatný a chybějící kód
  - odchod klienta i hostitele, nedostupný host, obsazený port
  - lobby UI host i klient, hlášky v menu
- **Pohyb:** smoke testy se simulovanými klávesami (běh, skok, respawn, seskok, průskok plošiny).
  - Bug s dvojskokem: po opravě simulace v aréně dává 2 skoky ve všech scénářích (skok ze země, sejití a hned skok, sejití a skok po 10 snímcích).
  - Zoom 0,85 ověřen snímkem obrazovky.
- **Společný zápas lokálně** (2 okna nebo 2 headless procesy, 127.0.0.1, macOS):
  - start z lobby
  - pozice obou hráčů na hostu a klientovi shodné po pohybu obou
  - pád z arény a respawn synchronizovaný
  - odchod klienta (host pokračuje s 1 hráčem) i hostitele (klient do menu s hláškou)
  - trénink beze změny (scénáře skoků a seskoku)
- **Opravy 2026-11-03** (scéna, headless):
  - panák položený na hlavu sklouzne a stojí vedle (40 px)
  - totéž obráceně
  - vyhození na `y=-910` nezabije
  - pod arénou: po 0,3 s ještě ve hře, po 0,7 s vypadl
  - celý síťový zápas beze změny
- **Aktualizace end-to-end na Macu** (export debug „sestavení 1“ + lokální server s „sestavením 2“):
  - stažení, ověření a výměna `.app`
  - restart spustí novou verzi ze stejného místa (opravena chyba: Mac po přejmenování hlásil cestu ke staré kopii)
  - nová verze smaže `.app.old`
  - **Špatný otisk:** nic se nevymění, stažený soubor se smaže
  - **Windows a Linux výměna neotestována** (odložené testy na Windows). Rizika: antivirus, složka bez práva zápisu.
- **Celý zápas (M3 krok 2, 2 okna na Macu, i s `--fake-lag=100` u klienta):**
  - odpočet: klient se nepohne (0 px)
  - pád: 4 životy a nezranitelnost
  - po 5. pádu výsledky u obou („Hostitel – vítěz“, „Kamarad“)
  - za ~8 s oba zpět v lobby a hostitel může začít znovu
  - žádné síťové chyby
  - snímky HUD a výsledků
- **Střelba (M3 krok 1, okna na Macu):**
  - trénink: 1 s palby do panáka ho posune 880 → 1207 px a shodí z okraje, střelec ucukne o 5 px
  - síť: host střílí po klientovi, klient je odhozen 880 → 1272 na obou obrazovkách, klient vidí letící střely
  - skoky beze změny
- **Měření latence** (M2 krok 5, host + klient lokálně, klient s `--fake-lag`, vlastní postava s 40 ms interpolací):

  | Simulované připojení | Ostatní hráči | Reakce vlastní postavy klienta |
  |---|---|---|
  | bez lagu | 0 zaseknutí | 96 ms |
  | +100 ms, 5 % ztrát | 0 zaseknutí | 172 ms |
  | +200 ms, 10 % ztrát | 0 zaseknutí | 295 ms |

  - Pohyb ostatních je plynulý i při ztrátách.
  - **Doporučení:** při běžném internetu (30–80 ms) bude reakce kolem 130–180 ms, tedy znatelné u skákání. Proto **predikci vlastního pohybu (M4) udělat hned po M3.**
- **Export a CI:** 3 exporty lokálně i v CI OK. Stažený macOS build má správnou verzi, je podepsaný a spustí se.
- **NETESTOVÁNO:**
  - Windows (exe, SmartScreen, firewall)
  - Linux
  - Gatekeeper se staženým ZIPem
  - ruční hraní
  - tlačítko Kopírovat
  - podrobné měření/ověření opravy sekání mezi počítači; Tailscale (Wi-Fi problém pouze nahlášen uživatelem)

## Rozhodnutí
- **Changelog (uživatel 2026-11-04) je implementovaný lokálně před dalším M4.** Menu a poznámky používají společné texty; zachovat pořadí releasů a mechanismus aktualizací, CI mění pouze generování poznámek.
- **Codex nesmí pushovat bez nového výslovného souhlasu (2026-11-04); nyní žádný souhlas není.** Všechny změny této session zůstávají bez commitu a bez pushe.
- **Skóre (2026-11-04):** zabití podle poslední účinné kulky před každou smrtí, bez timeoutu do pádu; série zabití stejného střelce do 2 s. Skóre pouze host, protokol 5. Silnější pistole 550 → 800. Oprava Wi-Fi sekání je nyní pouze v plánu.
- **M4:** vlastní pohyb se predikuje sdíleným motorem, opravy se přehrávají pouze během fyziky; odhoz, střelba a průběh zápasu zůstávají na hostu. Snapshot používá protokol 4.
- **Build jen při změně hry:** `paths-ignore` pro `docs/**`, `**/*.md`, `LICENSE`, `.gitignore` a `.gitattributes`. README a dokumentace tedy nemění verzi a nenutí hráče aktualizovat.
- **Nikdo nestojí na hlavě jiného hráče** (sklouznutí), **horní okraj arény je otevřený** a **život se ubírá až po 0,5 s mimo arénu.**
- **Aktualizace jen na vyšší číslo sestavení a jen ze stejného kanálu** (dev/stable). Manifest se nahrává poslední. Restart používá cestu zapamatovanou před výměnou.
- **Podpis `version.json` zatím není:** vyžaduje klíč v GitHub Secrets od uživatele. Integritu zajišťuje SHA-256 a HTTPS z GitHubu tohoto repa.
- **Licence PolyForm Noncommercial 1.0.0** místo MIT (uživatel 2026-11-03): stahovat, hrát a upravovat smí každý, prodávat ani vydělávat nesmí nikdo. Pull requesty slučuje jen uživatel.
- **Číslo sestavení místo kódu commitu** (uživatel nerozuměl kódům): hráči porovnávají „sestavení N“. Číslo jen roste, což se hodí i pro automatické aktualizace.
- **Celá hra v pixel artu včetně map** (uživatel 2026-11-03). Mapy kompozicí jako reference 2 (plovoucí ostrov, vesmír), ale víc pater. **Postavy mají animace:** klid, běh, skok, pád, seskok, střelba, zásah, schopnost (PLAN.md Q).
- **Automatické aktualizace** (zadání 2026-11-03, PLAN.md I.8, milník M3U hned po M3): hra po spuštění porovná svůj `build_id` s `version.json` na GitHubu, nabídne aktualizaci, stáhne ji (ověření SHA-256, doporučený podpis) a restartuje se. Windows záměnou exe, macOS výměnou `.app` se záložní cestou.
- **Lobby se po zápase vrací** (zadání 2026-11-03, PLAN.md T): výsledky → stejné lobby, žádné nové hostování. **V lobby se vybírá postava (každý) a mapa (hostitel).** Zatím jen v plánu: návrat v M3, postavy v M5, mapy v M6. Otevřená otázka: smí mít dva hráči stejnou postavu? (návrh: ano)
- **Internet = Tailscale** (uživatel 2026-11-03): zdarma pro až 6 uživatelů, Windows, macOS i Linux.
  - Hamachi zamítnuto: jen 5 členů a Linux jen v příkazové řádce.
  - UPnP odstraněno kvůli bezpečnosti a skrytí IP.
  - Relay (M7) je jen volitelný.
- **Postavy a zbraně (PLAN.md G.0):** první verze 4 postavy, každá má 2 přepínatelné zbraně (SMG až sniper) a 1 schopnost. Bedny se zbraněmi zrušeny.
- **Bezpečnost online hry (PLAN.md S):**
  - kód hry
  - `server_relay` vypnutý
  - žádné objekty ze sítě
  - limity velikosti zpráv
  - žádné otevírání portů a žádná veřejná IP
- **Míření ke kurzoru myši:** `aim` se posílá ve vstupu od M2 kroku 4.
- **Pixel-art styl** podle reference v `art_reference/` (cizí dílo, gitignored, jen reference).
- **Testy na Windows až na konci projektu.** Kód musí zůstat multiplatformní.
- **Godot 4.7.2 + GDScript, připnutý v `.tools/`:** CI používá stejný `setup_env.sh`. CI je bez actions třetích stran (kromě checkout a cache).
- **Host-autoritativní listen server, ENet.** Vlastní snapshot 30 Hz místo `MultiplayerSynchronizer`.
- **Handshake přes autentizaci `SceneMultiplayer`, ne RPC:** RPC se párují podle indexu metody.
- **Kód hry se sdílí v adrese za `#`:** jedno kopírování obsahuje vše a zpracuje ho `Session`.
- **ENet `MAX_CLIENTS = 4`** (o 1 víc než hráčů): klient navíc dostane hlášku „Hra je plná“.
- **`PlayerMotor.compute_velocity()` bez vedlejších efektů:** testovatelné, připravené na predikci. `InputFrame` nese jen držená tlačítka.
- **Skoky jako počítadlo (2 skoky do dopadu) místo coyote time:** po sejití i po odhození má hráč vždy oba skoky. Oprava bugu nahlášeného uživatelem.
- **README neobsahuje sekci o bezpečnosti** (přání uživatele 2026-11-03, aby nikoho nenabádala). Bezpečnostní pravidla zůstávají interně v PLAN.md, sekce S.
- **Velikost pohledu = zoom `Camera2D` v aréně** (0,85): každá aréna si může nastavit vlastní.
- **Knockback nad max. rychlostí brzdí jen tření.**
- **Vlastní mini test runner** místo GUT. **Lokalizační klíče se hledají regexem.**
- **Rolling prerelease tag `dev`** (ne `latest`).
- **Commity jen s dokumentací nevytvářejí nový build**, aby se zbytečně neměnila verze, se kterou se hráči spojují.
- **Windows se stahuje jako `.exe` přímo** (jeden soubor, PCK uvnitř). Mac a Linux zůstávají jako ZIP.
