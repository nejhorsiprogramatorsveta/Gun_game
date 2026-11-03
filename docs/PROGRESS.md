# Stav projektu

## Kde jsme skončili
**M2 krok 4b (start zápasu a synchronizace pohybu) je hotový, otestovaný lokálně, commitnutý a pushnutý.**
- Poprvé jde hrát spolu: hostitel klikne v lobby *Začít zápas* a všichni vidí pohyb a míření ostatních.
- Ještě se nestřílí (M3). Klientova postava reaguje se zpožděním (bez predikce, viz Známé problémy).
- Necommitnuté soubory: žádné.

## Další krok
**M2 krok 5: `LagSimulator` a test na dvou počítačích.**
- `src/net/lag_simulator.gd`: debug zpoždění a ztráta paketů pro vstupy a snapshoty (PLAN.md D.11).
  - Zapnutí parametrem `-- --fake-lag=100 --fake-loss=5`, jen v debug buildech.
  - Napojit v `match_net.gd` (jediné místo, kudy jdou).
- Ověřit lokálně se 100 ms a 5 % ztrát: plynulost interpolace vzdálených hráčů, reakce vlastní postavy.
- Pak test s uživatelem:
  - 2 počítače na stejné Wi-Fi, ideálně doma (knihovna často blokuje provoz mezi zařízeními)
  - nebo přes Tailscale s kamarádem
  - Postup a co sledovat napsat česky.
- Po M2 následuje **M3 souboj** (zbraň, střely ke kurzoru, knockback, životy, výsledky → `v0.1.0`).

## ODLOŽENO NA KONEC PROJEKTU (uživatel 2026-11-03: „Windows ověříme až na konci, pokud neřeknu jinak“)
**Neptat se na to v každé session.**
- Ruční test staženého `gun_game-windows.zip` na Windows PC:
  - SmartScreen
  - menu s verzí
  - trénink
  - firewall při hostování
  - Tailscale
- Případně i `gun_game-macos.zip` stažený v prohlížeči (Gatekeeper).
- Do té doby se hra na Macu spouští lokálně: `tools/godot --path .` z kořene projektu.

## Aktuální stav
- **Milník:** M2, kroky 1–3 a 4a hotové. M1 je hotový včetně CI (chybí jen ruční test na Windows, viz ODLOŽENO).
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
- **Nefunguje zatím:** střelba, životy a konec zápasu (M3).

## Poslední změny
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
- **Tailscale postup v README** (Share počítače, firewall na Windows) je napsaný podle dokumentace, prakticky zatím neověřený. Ověřit při prvním testu s kamarádem.
- **Vlastní postava klienta reaguje se zpožděním** (cesta k hostu a zpět + ~100 ms interpolace). Na LAN skoro nepoznatelné, přes internet znatelné. Predikce vlastního pohybu je naplánovaná v M4 (PLAN.md D.4), architektura je připravená (`last_seq` ve snapshotu, sdílený `PlayerMotor`).
- **Hostitel nemá zpoždění** (výhoda hostitele, PLAN.md M).
- **Interpolace neextrapoluje:** při výpadku snapshotů postava stojí na poslední pozici.
- **Knihovní Wi-Fi** (síť uživatele) používá rozsah 100.64.x.x a často blokuje provoz mezi zařízeními. Ověřovat raději doma nebo přes Tailscale.
- **Velikost buildů:** Windows ZIP ~39 MB, macOS ZIP ~62 MB (dáno šablonami Godotu 4.7).
- Ikona hry je výchozí ikona Godotu (vlastní přijde v M8).
- **Grafika:** cílový pixel-art styl (PLAN.md, sekce Q) vyžaduje sprity. Zdroj zatím nerozhodnutý, proto placeholdery.
- `EDITING_GUIDE.md` zatím neexistuje (M5). `ArenaData` zatím neexistuje, aréna je pevně v `match_controller.gd` (M6).
- Testovací skripty při ukončení hlásí „resources still in use at exit“. Je to pravděpodobně artefakt testovacích skriptů, ve hře neověřeno.

## Stav testů
- **Unit testy:** 27/27 OK (+ kodek vstupů a snapshotů, podvržené pakety, přetečení seq, míření, interpolace)
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
- **Export a CI:** 3 exporty lokálně i v CI OK. Stažený macOS build má správnou verzi, je podepsaný a spustí se.
- **NETESTOVÁNO:**
  - Windows (exe, SmartScreen, firewall)
  - Linux
  - Gatekeeper se staženým ZIPem
  - ruční hraní
  - tlačítko Kopírovat
  - síť mezi dvěma počítači a přes Tailscale

## Rozhodnutí
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
