# Plán projektu: 2D online multiplayerová arénová střílečka (Godot 4 + GDScript)

## Kontext

Cílem je originální 2D platformová arénová střílečka s knockbackem, inspirovaná mechanikami Gun Mayhem, kterou si kamarádi stáhnou jako ZIP z GitHubu a zahrají si spolu **přes internet**. Tento dokument je schválený plán projektu a hlavní reference pro všechny milníky. Postup práce je popsaný v sekci P.

**Upřesnění od uživatele (3. 11. 2026):**
- Kamarádi hrají hlavně na **Windows PC**. Windows je hlavní cílová a testovací platforma. macOS build vzniká v CI dál (nic nestojí), ale testuje se s nižší prioritou.
- MVP se ovládá **jen klávesnicí**. Gamepad přijde nejdřív v M8.
- Pracovní název hry je **`gun_game`**.

**Ověřená fakta (k 3. 11. 2026):**
- Nejnovější stabilní Godot je **4.7.2-stable** (vydán 18. 8. 2026). Verze 4.8 je teprve v betě (4.8-beta2, 29. 10. 2026), proto ji nepoužijeme. Zdroj: oficiální archiv godotengine.org.
- Pro NAT punch-through a relay existuje open-source server **noray** (foxssake) a addon `netfox.noray` (MIT). Podle Asset Library je aktuální verze 1.35.3.
- macOS Sequoia už neumí otevřít nepodepsanou aplikaci přes pravé tlačítko → Otevřít. Funguje jen cesta Nastavení systému → Soukromí a zabezpečení → „Přesto otevřít“.
- **Neověřeno:** aktuální limity bezplatných plánů Tailscale a ZeroTier, ceny VPS a chování Gatekeeperu na macOS 26 (Tahoe). U těchto bodů to v textu vždy uvádím.

---

## A. Přehled projektu

**Žánr:** rychlá 2D platformová střílečka z boku pro 2–4 hráče. Postavy nemají životy v procentech. Zásahy odhazují soupeře (knockback) a cílem je vystrčit je z arény.

**Herní smyčka:**
1. Host založí lobby, ostatní se připojí a vyberou si postavu.
2. Zápas začne odpočtem 3–2–1.
3. Hráči běhají, skáčou (i dvojskok), seskakují z jednosměrných plošin, střílí a používají schopnost.
4. Kdo spadne mimo arénu, ztratí život. Po 1,5 s se znovu objeví (respawn) a chvíli je nezranitelný.
5. Komu dojdou životy, vypadává. Vyhrává poslední hráč, který přežil.
6. Následuje obrazovka výsledků a návrat do lobby (odvetu spustí jedno kliknutí).

**Pracovní název:** `gun_game` (ZIPy `gun_game-windows.zip` atd.). Je to provizorní název, finální lze změnit později.

---

## B. Technologie

**Volba: Godot 4.7.2 (standardní verze bez .NET) + GDScript + Git + GitHub + GitHub Actions.**

| Kritérium | Godot + GDScript | Godot + C# | Unity + C# |
|---|---|---|---|
| 2D výkon a 2D fyzika | výborný, nativní 2D engine | stejný | dobrý, 2D je ale postavené nad 3D |
| Síťování | vestavěné ENet, RPC, `MultiplayerPeer`, `UPNP` | stejné | Netcode for GameObjects a Unity Relay (placený nad free tier) |
| Export Win/macOS | ano, export z Linuxu i pro macOS (universal) | macOS universal a .NET jsou složitější, výstup je větší | vyžaduje build na macOS nebo GameCI a aktivaci licence |
| Velikost ZIPu | ~35–50 MB | +.NET runtime, ~70–100 MB | ~60–150 MB |
| Jednoduchost vývoje | nejvyšší, bez externího SDK | potřebuje .NET SDK | těžký editor, licence |
| Udržovatelnost kódu od AI | dobrá díky statickému typování a krátkým skriptům | dobrá | dobrá, ale víc boilerplate |
| CI | stačí stáhnout jeden binár a šablony | + .NET SDK | licence Unity v CI, nejvíc křehké |
| Runtime závislosti | žádné | .NET je přibalený | žádné |

**Proč tato volba:** GDScript nepotřebuje žádný SDK, export běží celý na levném Linux runneru (včetně macOS universal buildu) a ZIPy jsou nejmenší. Výkon GDScriptu na hru pro 4 hráče s desítkami projektilů bohatě stačí.

**Zamítnuto:**
- **C#:** přinese výkon, který nepotřebujeme, za cenu složitějšího CI a větších buildů.
- **Unity:** licence, těžkopádné CI a placený relay.

**Další rozhodnutí:**
- **Renderer:** *Compatibility* (OpenGL 3 / ANGLE). Pro jednoduchou 2D grafiku je nejlehčí a nejlépe podporovaný na integrovaných GPU a starších Macích.
- **Verze enginu:** pevně 4.7.2 v CI i lokálně. Přechod na 4.8 zvážíme až po vydání stable a jen jako samostatný úkol.

---

## C. Herní design a MVP

### Mechaniky
- **Pohyb:** `CharacterBody2D` s během, skokem, dvojskokem, „coyote time“, bufferem skoku a seskokem dolů přes jednosměrné plošiny.
- **Knockback:** zásah přičte impulz k rychlosti. Ve vzduchu se rychlost tlumí odporem vzduchu. Každá postava má `weight`, které knockback zmenšuje.
- **Silnější současné zbraně (zadání 2026-11-04):** zvýšit sílu odhozu dostupné pistole z 550 na 800; pravidla váhy postav a zpětného rázu zůstávají zachována.
- **Míření myší (ZMĚNA ZADÁNÍ 2026-11-03):** na rozdíl od Gun Mayhem se nestřílí jen vodorovně. Střela letí **směrem ke kurzoru myši**, střílí se levým tlačítkem myši. Postava se otáčí podle kurzoru, ne podle směru pohybu. Knockback zasaženého jde ve směru letu střely.
- **Zpětný ráz (recoil):** výstřel posune střelce **proti směru míření**. Výstřel dolů tak trochu nadzvedne, takže zbraně mají i pohybovou roli.
- **Smrt:** pád pod `kill_y` nebo opuštění hranic arény (`kill_rect`).
- **Životy:** výchozí 5 (nastaví se v `match_rules.tres`). Respawn po 1,5 s a 1,5 s nezranitelnosti.
- **Zbraně (ZADÁNÍ 2026-11-03):** každá postava má **2 vlastní zbraně** a během hry mezi nimi přepíná (kolečko myši, Q nebo 1/2). Škála od malých rychle střílejících SMG přes útočnou pušku (typ AK-47) po odstřelovací pušku. Původní nápad s bednami se zbraněmi je zrušený. MVP (M3) začne s jednou zbraní, systém dvou slotů přijde v M5.

### MVP (milníky M1–M3)
1 aréna, pohyb a skok, 1 zbraň, projektily s kolizemi, knockback, pád z arény, životy a respawn, lobby (hostovat / připojit přes IP), jednoduchá obrazovka výsledků, verze v menu a ZIP build na GitHubu. Ověřuje se **mezi dvěma počítači přes internet**.

### Po MVP
- 3 postavy se schopnostmi a výběr postavy
- více zbraní (bedny)
- 2–3 arény
- 3–4 hráči
- vylepšená menu, zvuk a efekty
- predikce pohybu (pokud bude potřeba)
- připojení kódem

### Výslovně odloženo
Účty, databáze, žebříčky, matchmaking, dedikovaný backend, placená infrastruktura, boti/AI, replaye, spectator, gamepad rebinding UI, mobilní a webová verze, Steam a anti-cheat nad rámec validace na hostu.

---

## D. Multiplayerová architektura

### D.1 Autorita
- **Listen server, host-autoritativní.** Host (peer 1) simuluje vše: pohyb všech hráčů, střelbu, projektily, knockback, schopnosti, cooldowny, eliminace, životy a skóre.
- Klienti posílají jen **vstupy** a zobrazují stav, který jim host pošle.

### D.2 High-level API vs. vlastní snapshoty

**Rozhodnutí:** použijeme vestavěné `MultiplayerAPI` (RPC) s `ENetMultiplayerPeer` jako dopravu. Pro pohyb ale **nepoužijeme `MultiplayerSynchronizer`**. Místo toho host posílá jeden kompaktní **snapshot** všech hráčů, a to jedním `unreliable_ordered` RPC.

Důvody:
- `MultiplayerSynchronizer` nemá interpolaci (stejně bychom ji psali sami) a posílá samostatná data za každý uzel.
- Jeden snapshot = jeden paket za tick, je to přehledné a jde snadno měřit.
- Snapshot nese i `last_input_seq`, který budeme potřebovat pro případnou predikci (M4).
- Všechen pohybový provoz prochází jedním místem. Tam lze snadno vložit simulaci lagu (D.8).

`MultiplayerSpawner` také nepoužijeme. Spawny řídí match logika deterministicky ze seznamu hráčů, který host rozešle při startu zápasu. Je to jednodušší a bez „skrytých“ replikací.

### D.3 Frekvence a velikost zpráv

**Fyzikální tick:** 60 Hz pevně (`physics_ticks_per_second = 60`).

**Vstup klienta → host:** každý fyzikální tick (60 Hz), `unreliable_ordered`. Obsah:
- `seq` (u16)
- `move_x` (i8)
- `buttons` (bitmaska u8: skok, střelba, schopnost, dolů)
- `aim` (u16, úhel míření kvantovaný na 65536 kroků, ~0,005°): směr od postavy ke kurzoru. Host podle něj střílí a ve snapshotu ho posílá ostatním, aby viděli, kam kdo míří (zbraň v ruce).

Zpráva navíc nese **poslední 3 vstupy** jako redundanci proti ztrátě paketů, celkem ~12 B. Host použije nejnovější ještě nezpracované vstupy. Stisk tlačítka (hrana) se odvozuje na hostu z posloupnosti `seq`, takže krátký stisk skoku se neztratí.

**Snapshot host → klienti:** 30 Hz (každý 2. tick), `unreliable_ordered`. Na hráče přibližně:
- `slot` u8
- `pos` 2× f32
- `vel` 2× i16
- `flags` u8 (směr, na zemi, štít, nezranitelnost)
- `anim` u8
- `lives` u8
- `ability_cd_ticks` u16
- `last_input_seq` u16

To je ~20 B na hráče, pro 4 hráče s hlavičkou ~90 B. Při 30 Hz to dělá ~3–4 KB/s na klienta i s režií UDP/ENet. Zanedbatelné i pro relay.

Proč 30 Hz: polovina ticku dává plynulou interpolaci s malou zátěží. 60 Hz by zdvojnásobilo provoz bez viditelného rozdílu, 20 Hz by zvětšilo interpolační zpoždění.

**Kódování:** `PackedByteArray` s metodami `encode_*`/`decode_*`, vše v jednom souboru `src/net/net_codec.gd` (implementováno v M2 kroku 4b).

### D.4 Latence, interpolace a predikce

**Vzdálení hráči:** klient drží buffer snapshotů a vykresluje je se zpožděním ~2 intervalů (≈66–100 ms). Mezi snapshoty lineárně interpoluje. Když snapshot chybí, krátce extrapoluje (max. 100 ms).

**Vlastní hráč (upřímně):** bez predikce bude hráč na klientovi reagovat se zpožděním RTT plus interpolace. Při 30 ms je to v pořádku, při 80–120 ms to u skákací hry bude **znatelně tuhé**. Postup:
1. **M2–M3:** bez predikce. Ověříme síťování a změříme pocit.
2. **M4:** predikce **jen vlastního pohybu** s reconciliation:
   - Klient simuluje sebe stejnou funkcí jako host (`PlayerMotor.step(body, input, delta)`).
   - Ukládá historii vstupů. Po snapshotu nastaví stav na hodnotu z hostu pro `last_input_seq` a přehraje nepotvrzené vstupy.
   - Knockback a respawn přijdou z hostu jako korekce. Malé chyby se vyhlazují vizuálním offsetem.

Architektura s tím počítá od začátku: pohyb je **jedna sdílená funkce** bez síťových závislostí a vstup je samostatná struktura s `seq`. Proto M4 přidá jen ~1 skript a úpravu `player.gd`.

**Lag compensation (zpětné přetáčení zásahů):** neplánuje se. Host má malou výhodu, což je u přátelské hry přijatelné. Zapíšeme to do rizik.

### D.5 Střelba a projektily
- Klient pošle ve vstupu tlačítko „střelba“ a **úhel míření** (ke kurzoru). **Host** rozhoduje podle `fire_rate` (cooldown) a střílí pod posledním přijatým úhlem. Úhel jen normalizuje, žádná jiná validace není potřeba, protože libovolný směr je legální.
- Host vytvoří projektil a pošle **reliable event** `projectile_spawned(id, pos, dir, weapon_id, tick)`. Klienti si projektil simulují **jen vizuálně** stejnou přímočarou funkcí.
- Zásahy počítá **jen host**: raycast z předchozí na novou pozici každý tick, aby rychlé střely neprošly skrz.
- Při zásahu host pošle `projectile_hit(id, pos)` kvůli efektu a smazání. Knockback se projeví ve snapshotu (rychlost a pozice zasaženého).
- Kvůli odezvě se záblesk z hlavně a zvuk přehrají u střelce lokálně hned. Kulka ale vznikne až podle hostu.

### D.6 Události zápasu (reliable RPC host → všichni)
- `match_started(arena_id, players[], seed)`
- `countdown(n)`
- `player_eliminated(slot, lives_left)`
- `player_respawned(slot, pos)`
- `ability_used(slot, ability_id)` (jen kvůli efektu)
- `match_ended(results)`

Lobby stav (jména, postavy, připravenost) drží host a při každé změně ho celý rozešle (reliable).

### D.7 Validace na hostu
- Identita odesílatele se bere **vždy** z `multiplayer.get_remote_sender_id()`, nikdy z obsahu zprávy. Tím je zablokované podvržení peer ID.
- RPC, která smí volat jen host (`@rpc("authority")`), klient sám spustit nemůže. U `any_peer` RPC host kontroluje, zda odesílatel patří k hráčům.
- Hodnoty se ořezávají (`move_x` do −1..1) a neznámé bity se ignorují.
- Starší nebo duplicitní `seq` se zahodí. Klient smí poslat max. ~2× tolik vstupů za sekundu, kolik je ticků, zbytek host zahodí.
- Fire rate, cooldowny i výběr postavy (musí existovat v `ContentDB`) jsou výhradně na hostu, takže klient je nemůže zrychlit.
- Zprávy během špatné fáze (např. vstup v lobby) host ignoruje.

### D.8 Kontrola verze a protokolu
Po připojení klient pošle `hello(protocol_version, build_id, player_name)` **přes autentizaci SceneMultiplayer** (`auth_callback` / `send_auth`), ne přes RPC. RPC metody se párují podle indexu, takže u jiného buildu by RPC hello nemuselo jít ani přečíst. Dokud handshake neskončí, peer nemůže posílat ani přijímat RPC. (Upřesněno při implementaci v M2.)
- `build_id` = `verze+commit` (např. `0.2.0+a1b2c3d`) vygenerované v CI.
- Host porovná obojí. Při neshodě odpoví `rejected("ERROR_VERSION_MISMATCH", host_build_id)` a po chvíli klienta odpojí.
- Klient uvidí česky: *„Máš jinou verzi hry (0.2.0+a1b2c3d) než hostitel (0.2.1+ff00aa1). Stáhněte si oba nejnovější verzi.“*
- Ostatní důvody odmítnutí: plné lobby, probíhající zápas.

Stejný commit znamená stejná herní data, takže `build_id` pokrývá i shodu `.tres` dat. Buildy spuštěné z editoru mají `dev` a připojí se jen k jiným `dev` buildům.

### D.9 Odpojení a timeouty
- ENet timeout nastavíme na ~5–8 s (`ENetPacketPeer.set_timeout`).
- **Klient odejde v lobby:** host ho odebere ze seznamu a rozešle nový stav.
- **Klient odejde v zápasu:** jeho postava zmizí a všem se zobrazí „Hráč X se odpojil“. Pokud zbude méně než 2 hráči, zápas končí.
- **Host odejde:** klientům přijde `server_disconnected`, vrátí se do menu a uvidí česky „Hostitel ukončil hru nebo spojení spadlo“.
- **Nepodařené připojení:** signál `connection_failed` plus vlastní timeout ~10 s, poté česká chybová hláška s odkazem na nápovědu.

### D.10 Vyměnitelná vrstva připojení
Gameplay pracuje jen s `multiplayer`, `get_unique_id()` a RPC. Způsob připojení řeší výhradně `src/net/connectors/`:

```
Connector (base, RefCounted)
  host(port) -> MultiplayerPeer   / signál: host_info_ready(text_to_share)
  join(join_info) -> MultiplayerPeer
EnetDirectConnector   – IP:port, + UPnP pokus (M2–M3)
NorayConnector        – join kód přes noray (M7)
```

Autoload `Session` jen vezme vrácený `MultiplayerPeer` a nastaví `multiplayer.multiplayer_peer`. Noray používá ENet, takže M7 nemění ani řádek gameplaye.

### D.11 Simulace lagu a ztráty paketů
- **Ve hře (debug):** `LagSimulator` v místě, kudy prochází vstupy a snapshoty. Umí zadržet doručení o X ± jitter ms a zahodit Y % paketů. Zapíná se v debug menu nebo parametrem `--fake-lag=100 --fake-loss=5`.
  - Omezení: neovlivní reliable události (ty ale lag snesou).
- **Na úrovni OS (pro úplnost):**
  - macOS: *Network Link Conditioner* (součást Additional Tools for Xcode)
  - Windows: *clumsy* (open source)

---

## E. Připojení přes internet

### Základy (proč to je problém)
- **NAT:** domácí router má jednu veřejnou IP. Nevyžádané příchozí spojení na hosta se zahodí, pokud neexistuje přesměrování portu (port forwarding).
- **CGNAT:** poskytovatel (často mobilní data, některé optiky a Wi-Fi sítě) dá routeru jen sdílenou neveřejnou adresu (100.64.0.0/10). Port forwarding pak **vůbec nejde**, ať se nastaví cokoli.
- **Firewall:** i se správným forwardingem musí Windows Firewall nebo macOS firewall propustit hru.
- **IPv6:** pokud ho mají host i klient, NAT obvykle odpadá. Hra může IPv6 adresu nabídnout jako alternativu. Funguje to jen někdy (záleží na firewallu routeru).

### Srovnání

| Možnost | Úspěšnost | Co musí kamarádi | Infrastruktura / cena | Údržba | Dopad na kód |
|---|---|---|---|---|---|
| **A. LAN** | 100 % lokálně | nic | 0 | 0 | 0 (jen pro testy) |
| **B. Přímá IP + port forwarding / UPnP** | vysoká, *pokud host nemá CGNAT* a router jde nastavit nebo má zapnuté UPnP. Odhadem 50–70 % domácností (neověřený odhad). Pod CGNAT 0 %. | jen zadat IP. **Host** nastavuje router nebo spoléhá na UPnP. | 0 Kč | žádná | malý (`UPNP` třída ve vlákně) |
| **C. Tailscale / ZeroTier** | velmi vysoká (vlastní NAT traversal a relay DERP) i přes CGNAT | nainstalovat aplikaci, přihlásit se, připojit se do sítě hosta | 0 Kč na free plánu (*limity uživatelů a zařízení ověřit*) | malá | **žádný** (jen jiná IP) |
| **D. Punch-through + relay (noray)** | velmi vysoká: punch-through funguje často, relay vždy | nic, jen opsat kód | malý VPS: zdarma (Oracle Always Free) nebo ~4–6 €/měs. (*cenu ověřit*). Provoz relaye je minimální (~5 KB/s na hráče). | střední (server, aktualizace, monitoring) | nový `NorayConnector` (+ addon `netfox.noray` MIT nebo vlastní malý klient) |
| **E1. Steam networking** | výborná | Steam účet | 100 USD Steam Direct poplatek a vydání na Steamu, GodotSteam (GDExtension) | střední | velký: nová závislost, jiné buildy |
| **E2. WebRTC + signaling + TURN** | vysoká | nic | signaling server + TURN (coturn) na VPS. TURN přenáší data. | vyšší | velký: desktop vyžaduje GDExtension `webrtc-native`, nutný signaling |

### Doporučení pro MVP: **B + C jako záloha**
1. **Host klikne „Hostovat“.** Hra na pozadí zkusí UPnP: namapuje UDP port (výchozí `24642`, lze změnit) a zjistí veřejnou IP.
2. **Lobby ukáže adresu k sdílení** s tlačítkem **„Kopírovat“**, např. `85.12.34.56:24642`.
   - Pokud UPnP selže, hra to česky oznámí a nabídne odkaz na návod k port forwardingu.
   - Pokud veřejná adresa routeru vypadá jako CGNAT (100.64.x.x nebo privátní rozsah), hra rovnou doporučí Tailscale.
3. **Záloha pro CGNAT a nepřístupné routery:** Tailscale. Hostitel napíše kamarádům svou Tailscale IP (100.x.y.z). Pro hru je to obyčejné IP připojení.

### Upgrade na „připojení kódem bez routeru“ (M7)
- Self-hostovaný **noray** server: host dostane krátký kód, klient ho zadá. Noray zkusí NAT punch-through a když selže, provoz jde přes relay.
- **Náklady:** 0 Kč (Oracle Always Free VM, nevýhody: nutná registrace kartou a riziko odebrání nečinné instance) nebo ~4–6 €/měsíc za levný VPS. Doménu nepotřebujeme, stačí IP.
- **Pracnost:** ~1 milník střední složitosti. Server je hotový (Node.js nebo Docker), na straně hry jde jen o jeden nový konektor a pole „Kód hry“ v UI.
- **Upozornění:** server je pak jediný bod selhání. Když nepoběží, zůstává funkční přímé připojení přes IP. Obě cesty ponecháme.

### Návod pro kamarády (MVP, zkrácená verze do README)
**Hostitel (jen jeden z vás):**
1. Stáhni ZIP pro svůj systém (viz I), rozbal ho a spusť hru.
2. Klikni *Hostovat*. Na Windows při dotazu firewallu **povol přístup** (zaškrtni i „Veřejné sítě“, pokud je máš).
3. V lobby klikni *Kopírovat adresu* a pošli ji kamarádům (Discord apod.).
4. Pokud se nikdo nepřipojí: hra ti ukáže, jestli selhalo UPnP. Přesměruj v routeru **UDP port 24642** na svůj počítač, nebo použijte Tailscale (níže).

**Hráč:**
1. Stáhni stejnou verzi ZIPu (číslo verze je vidět v menu) a spusť hru.
2. Klikni *Připojit*, vlož adresu a potvrď.

**Když to nejde (Tailscale):**
1. Všichni nainstalujte Tailscale z tailscale.com a přihlaste se.
2. Hostitel vás pozve do své sítě (nebo vám nasdílí svůj počítač).
3. Hostitel v Tailscale aplikaci zkopíruje svou adresu `100.x.y.z` a pošle ji ostatním.
4. Připojte se ve hře na `100.x.y.z:24642`.

---

## F. Softwarová architektura

### F.1 Strom adresářů
```
project.godot
export_presets.cfg            # commitnutý, bez tajemství
CLAUDE.md  README.md  LICENSE  CREDITS.md  .gitignore  .gitattributes
.github/workflows/build.yml   # export + rolling prerelease + tagy
docs/
  PROGRESS.md                 # živá paměť projektu (česky)
  ARCHITECTURE.md             # krátký přehled architektury
  EDITING_GUIDE.md            # jak upravovat data a texty (česky)
assets/
  fonts/                      # Noto Sans (OFL), diakritika OK
  sprites/  audio/  vfx/
data/                         # VŠE, co edituješ ručně (balanc)
  characters/  scout.tres ...
  weapons/     pistol.tres ...
  abilities/   dash.tres ...
  arenas/      rooftops.tres ...
  match_rules.tres            # životy, respawn, odpočet
localization/
  translations.csv            # keys,cs
src/
  autoload/
    session.gd                # AUTOLOAD: lobby stav, connect/disconnect, handshake, fáze
    settings.gd               # AUTOLOAD: uživatelská nastavení (user://settings.cfg)
  core/
    build_info.gd             # static: verze, commit, protocol_version
    content_db.gd             # static: načte data/*.tres, lookup podle id
  net/
    connectors/connector.gd, enet_direct_connector.gd, (noray_connector.gd)
    upnp_helper.gd            # UPnP ve vlákně, výsledek signálem
    snapshot.gd               # pack/unpack snapshotu a vstupu
    lag_simulator.gd          # debug zpoždění/ztráta
  data_types/                 # class_name Resource definice
    character_data.gd  weapon_data.gd  ability_data.gd  arena_data.gd  match_rules.gd
  player/
    player.tscn, player.gd    # uzel postavy: host simuluje, klient zobrazuje/interpoluje
    player_motor.gd           # ČISTÁ funkce pohybu (sdílená host/predikce)
    input_frame.gd            # vstup za tick (směr + bitmaska tlačítek), sample_local() čte klávesnici
    remote_interpolator.gd    # buffer snapshotů pro vzdálené hráče
  combat/
    projectile.tscn, projectile.gd
    combat_rules.gd           # static: výpočet knockbacku, recoil
  abilities/
    dash_ability.gd  shield_ability.gd  pulse_ability.gd   # extends AbilityData
  match/
    match.tscn, match_controller.gd   # pravidla na hostu: tick, eliminace, respawn, konec
    match_net.gd              # RPC vrstva zápasu (vstupy, snapshoty, události)
  arenas/
    arena.gd, platform.gd     # základ arény (spawny, kill_rect) + nastavitelná plošina (pevná/jednosměrná)
    arena_rooftops.tscn ...   # Platform uzly, SpawnPoints/Marker2D
  ui/
    main_menu.tscn/.gd  lobby.tscn/.gd  hud.tscn/.gd  results.tscn/.gd
    settings_menu.tscn/.gd  message_dialog.tscn/.gd
tests/
  run_tests.gd, test_case.gd  # headless runner (extends SceneTree) + základ testů
  test_combat_rules.gd  test_snapshot.gd  test_cooldown.gd
tools/
  setup_env.sh                # „venv“ projektu: stáhne připnutý Godot 4.7.2 do .tools/ (+ ověří SHA512)
  godot                       # wrapper: spustí Godot z .tools/ (používat místo systémového godot)
  check_localization.gd       # najde chybějící/nepoužité klíče
.tools/                       # gitignored: stažený Godot (a volitelně export templates)
```

### F.2 Autoloady (jen 2)
- **`Session`:** síťová session musí přežít přechody scén (menu → lobby → zápas → lobby) a je opravdu globální.
- **`Settings`:** nastavení (hlasitost, jméno, poslední IP, port, fake lag) potřebuje menu i hra.

`BuildInfo` a `ContentDB` nejsou autoloady, ale statické třídy (`class_name` se `static` funkcemi). Nemají stav ani životní cyklus.

### F.3 Oddělení vrstev
- **Síť** (`autoload/session.gd`, `net/`, `match/match_net.gd`): jediná místa s RPC.
- **Pravidla na hostu** (`match_controller.gd`, `combat_rules.gd`, `player_motor.gd`, abilities): běží na hostu. Motor sdílí i predikce.
- **Prezentace** (`ui/`, animace, VFX a audio v `player.gd` reagující na stav): nic nerozhoduje.
- **Data** (`data/`, `localization/`): žádná logika.

### F.4 Klíčové toky
1. **Spawn:** `Session` vlastní seznam hráčů. Host zavolá `match_started`, všichni načtou `match.tscn` a `MatchController` vytvoří postavy ve stejném pořadí podle `slot`. Uzly mají jména `Player_<slot>`.
2. **Tick na hostu:** pro každého hráče vezme poslední vstup → `PlayerMotor.step` → zbraň → projektily → kontrola `kill_rect` → každý 2. tick snapshot.
3. **Na klientovi:** odešle vstup → přijme snapshot → vzdálené postavy interpoluje, vlastní nastaví (v M4 predikuje) → HUD čte stav.

### F.5 Konvence
- Statické typování všude.
- Skript má max. ~250–300 řádků, jinak se rozdělí podle odpovědnosti.
- `snake_case` pro soubory a funkce, `PascalCase` pro `class_name`.
- Signály pro UI, přímá volání v rámci jedné vrstvy.
- Žádné hardcodované texty: všechny řetězce pro hráče jdou přes `tr("KEY")`.
- Kolizní vrstvy pojmenované v `project.godot`: `world`, `platform_oneway`, `players`, `projectiles`.

---

## Q. Vizuální styl (ZADÁNÍ 2026-11-03)
- **Celá hra bude v detailním pixel-art stylu** podle referenčního obrázku od uživatele: postavy z japonského prostředí (samuraj v plné zbroji, róninka s maskou kitsune a katanou, ninjové s kusarigamou a s velkým šurikenem).
  - Postavy jsou vysoké ~90–110 px, mají tmavé obrysy, výrazné stínování, sytou omezenou paletu a měkký elipsovitý stín pod nohama.
- Referenční obrázek je lokálně v `art_reference/` (gitignored). **Je to cizí dílo (@GEORGE_TTOWERS), slouží jen jako stylová reference a nesmí se kopírovat, commitovat ani distribuovat.** Postavy hry musí být vlastní originální návrhy v podobném stylu.
- **MAPY (ZADÁNÍ 2026-11-03): také v pixel artu.** Celá hra má jednotný pixel-art styl.
  - Druhá reference (`art_reference/map_style_reference.png`, Brawlhalla, cizí dílo) ukazuje jen **kompozici**: masivní plovoucí ostrov s rozeklaným okrajem, detailní spodek se svítícími prvky, vesmírné pozadí s planetami ve více vrstvách (parallax).
  - Navíc **více pater plošin** jako v demo aréně. Plošiny musí být čitelné na první pohled.
- **ANIMACE POSTAV (ZADÁNÍ 2026-11-03):** každá postava má pixel-art animace:
  - klid, běh
  - skok, pád, **seskok** (přes plošinu)
  - **střelba**, **zásah** (odhození)
  - **speciální schopnost**
  - Proveditelnost: ano. `AnimatedSprite2D` + `SpriteFrames` na postavu (soubor `.tres` s obrázky snímků) a malý přepínač animací podle stavu.
  - **Síť:** klienti stav nepočítají, odvodí ho ze snapshotu. Do `flags` přibudou bity „na zemi“, „právě střílí“, „právě zasažen“, „schopnost aktivní“. Výstřel a zásah navíc víme z událostí. Rychlost (ve snapshotu) rozliší skok a pád.
  - Zbraň je samostatný sprite otočený podle míření, aby střelba šla jakýmkoli směrem bez kreslení 360° variant postavy.
  - **Náročnost:** kód malý, hlavní práce je kreslení snímků (cca 6–10 animací × 4–8 snímků na postavu).
- **Technicky, až přijdou první sprity:**
  - projektové nastavení `default_texture_filter = Nearest`, přichytávání 2D transformací a vrcholů k pixelům
  - celočíselné škálování okna (`window/stretch/scale_mode = integer`) a nízké základní rozlišení (např. 640×360, nebo aréna kreslená ve 2× pixelech)
  - `AnimatedSprite2D` se `SpriteFrames` (idle, běh, skok, pád, výstřel); zbraň jako samostatný sprite otáčený podle míření
- **ROZHODNUTÍ 2026-11-05 (uživatel: „přidáme konečně pixel art“): postavy a zbraně kreslí generátor `tools/art/generate_sprites.py`** (vlastní pixel art pixel po pixelu: obrysy, stínování; snímky 32 × 40 px, ve hře ×2). Animace: klid (2), chůze (4), skok, pád, střelba (2) + zbraň otočená za kurzorem se zábleskem. Návrhy: Jiskra – róninka s maskou kitsune a katanou; Balvan – samuraj ve zbroji s kabutem; Vichr – ninja s šálou a kusarigamou; Stín – ninja s velkým šurikenem; Krügermann – potrhlý vynálezce (plášť, brýle, tlaková láhev; NE podle dodané fotky v nacistické uniformě); Architekt – stavitel se slaměným kloboukem a kladivem (NE podle dodané fotky skutečného člověka). **Hotovo 2026-11-05 (0.2.2): mapy, pozadí a menu** – `tools/art/generate_world.py`: dlaždice (kámen s mechem pro pevné plošiny, dřevěný trám pro jednosměrné), pozadí 480×270 pro každou mapu (Střechy: noční město pagod s měsícem; Chrámové schody: západ slunce, hory, torii; Visuté mosty: mlhavé údolí, skalní sloupy, vodopád) + plující mraky (`ArenaBackground`), UI téma `assets/ui/theme.tres` (rámečky tlačítek, polí, panelů, obrysy textů), logo „DOJO KNOCKOUT“, pozadí v menu/lobby/výsledcích. **Efekty schopností (0.2.5):** `tools/art/generate_effects.py` + `src/player/ability_fx.gd` – plyn z animovaných obláčků, bublina štítu, rostoucí prstenec tlakové vlny (dosah zvýšen 160 → 320 px na přání uživatele „ať nemusí melee“), stopa úskoku, kouř přesunu. Zbývá: animace zásahu.
- **Pixelové písmo a HUD (uživatel 2026-11-05, 0.2.4):** písmo Pixelify Sans (OFL, má celou češtinu; vlastní kreslení písma s diakritikou by bylo nekvalitní) bez vyhlazování pro celou hru (`gui/theme/custom_font`); scoreboard v pixelovém panelu s ikonou hlavy postavy; „KILL! / DOUBLE KILL! / TRIPLE KILL! / MULTI KILL ×n!“ vyskočí nad hráčem, který zabil (`src/ui/kill_popup.gd`), místo hlášky uprostřed obrazovky.
- **Zdroj grafiky (původně otevřená otázka):** vlastní kreslení (Aseprite, LibreSprite), objednávka u pixel artisty, nebo assety s licencí CC0 / CC BY. Do té doby zůstávají barevné placeholdery. Každý asset se zapíše do `CREDITS.md`.
- **Návrh mapování na postavy (G.3):**
  - samuraj ↔ Balvan (štít)
  - róninka s kitsune maskou ↔ Jiskra (úskok)
  - ninja s kusarigamou ↔ Vichr (tlaková vlna), případně nová schopnost „přitáhnutí řetězem“
  - ninja se šurikenem ↔ 4. postava později

## S. Bezpečnost online hry (POŽADAVEK UŽIVATELE 2026-11-03, platí pro každou síťovou změnu)
Cíl: přes hru se nikdo nesmí jednoduše dostat do počítače hráče ani do jeho domácí sítě (Wi-Fi).

**ROZHODNUTÍ UŽIVATELE (2026-11-03): připojení přes internet = Tailscale.**
- Hra **neotevírá porty v routeru (UPnP odstraněno)** a **nikde nezobrazuje skutečnou veřejnou IP** (sdílí jen Tailscale a LAN adresy).
- Kamarádi se k počítači hostitele dostanou přes sdílení zařízení v Tailscale (*Share*), ne pozvánkou do celé sítě.
- Relay server (noray) je jen volitelný pozdější krok, pokud by instalace Tailscale vadila.

**Pravidla v kódu:**
1. **Žádné objekty ze sítě.** `SceneMultiplayer.allow_object_decoding` zůstává `false` (výchozí). Handshake používá `bytes_to_var()` (objekty nedekóduje) s limitem velikosti zprávy. Ze sítě nikdy nespouštět kód ani nenačítat soubory a cesty.
2. **`server_relay = false`.** Klienti mluví jen s hostitelem a nemohou si posílat RPC navzájem.
3. **Validace všeho od klienta na hostu:** identita z `get_remote_sender_id()`, typy, rozsahy, velikosti, rate-limit vstupů (sekce D.7). Neplatné zprávy se zahodí.
4. **Kód hry (heslo místnosti).** Host vygeneruje náhodný šestiznakový kód (kryptograficky bezpečný generátor), který se sdílí spolu s adresou (`85.12.34.56:24642#K7Q2MX`). Bez kódu se cizí člověk, který náhodou najde otevřený port, do hry nepřipojí.
5. **Žádné UPnP ani jiné otevírání portů do internetu.** Odstraněno na přání uživatele, kód je v historii gitu (commit `48b5ac4`). Veřejné IPv4/IPv6 adresy hra nesdílí.
6. **Hra nikdy nepotřebuje práva správce.** Nastavení se ukládají jen do `user://`.
7. **Buildy jen z GitHub Actions** (oficiální release stránka), žádné ručně posílané exe.
8. **Godot držet aktuální** (bezpečnostní opravy enginu) a při upgradu pročíst changelog.

**Upřímně o rizicích (pro README a hráče):**
- **Co hra otevírá:** jen jeden UDP port na počítači hostitele, jen po dobu hostování. Nedává přístup k souborům, ostatním programům ani k jiným zařízením ve Wi-Fi. Klienti port neotevírají vůbec, jen se připojují ven.
- **Zbytkové riziko A, chyba v enginu:** případná chyba v síťovém kódu Godotu nebo ENetu. Je nízké, snižuje ho aktualizace Godotu.
- **Zbytkové riziko B, sdílení IP adresy:** kdo zná veřejnou IP hostitele, může jeho připojení zahltit (DoS, „shození internetu“) a zhruba určit jeho lokalitu. Proto sdílet adresu jen s kamarády.
- **UPnP na routeru:** obecně usnadňuje otevírání portů i jiným programům v síti. Pokud ho má hráč vypnuté, je to bezpečnější. Hra pak nabídne ruční port forwarding nebo Tailscale.
- **Nejbezpečnější varianta je Tailscale:** nic se neotevírá do internetu a připojit se mohou jen pozvaní lidé. Pozor: sdílený počítač je pro pozvané dostupný na všech portech, které nechrání firewall. Doporučit nechat zapnutý firewall a sdílet jen s důvěryhodnými lidmi.
- **Windows Firewall:** při dotazu povolit hru pro **soukromé sítě**. Veřejné sítě (kavárna, knihovna) povolovat nedoporučujeme.
- **Připojení kódem přes relay (M7):** skryje IP hostitele před ostatními hráči. Další bezpečnostní přínos tohoto kroku.

## T. Lobby a průběh zápasů (ZADÁNÍ UŽIVATELE 2026-11-03)

**Cíl:** jednou vytvořené lobby slouží pro libovolný počet zápasů. Hráči nemusí po každé hře zakládat novou.

### T.1 Smyčka hry
```
Menu → Hostovat/Připojit → LOBBY ──(host: Začít zápas)──► ZÁPAS ──(konec)──► VÝSLEDKY ──(automaticky / tlačítko)──► LOBBY ↺
```
- **Po konci zápasu:** všichni uvidí obrazovku výsledků (pořadí, zbývající životy). Pak se **vrátí do stejného lobby** po ~8 s nebo dřív tlačítkem *Zpět do lobby*.
- **Session se nezavírá.** Spojení, kód hry, seznam hráčů i jejich výběr postav zůstávají. Hostitel může hned spustit další zápas.
- Hráč, který se odpojí během zápasu, v lobby chybí. Nový hráč se může připojit jen v lobby (během zápasu ho handshake odmítne, `ERROR_MATCH_IN_PROGRESS`).
- **Esc v zápase:**
  - klient opustí session
  - hostitel dostane volbu „Ukončit zápas pro všechny“ (návrat do lobby), nebo „Opustit hru“
- **Technicky:** `Session` dostane fázi `RESULTS`. Host pošle reliable RPC `match_ended(results)` a po návratu `_return_to_lobby()`, obě změní fázi u všech. Lobby scéna se načte znovu ze stavu `Session`, nic se nezakládá znovu.

### T.2 Výběr postavy a mapy v lobby
- **Postava:** každý hráč si v lobby vybere postavu z nabídky (karty se jménem, popisem, 2 zbraněmi a schopností z `CharacterData`).
  - Klient pošle hostu žádost `request_character(id)`. Host ověří, že postava existuje v `ContentDB`, uloží ji a rozešle.
  - Mohou mít dva hráči stejnou postavu? Výchozí návrh: **ano** (rozlišení barvou slotu). Rozhodne uživatel.
- **Mapa (aréna):** vybírá **hostitel** v lobby. Ostatní výběr vidí. Volitelně později možnost „náhodná“.
- **Připraven/a:** později volitelné tlačítko *Připraven* u každého hráče. Host pak může začít, až jsou všichni připraveni.
- **Data:**
  - `Session.players[peer] = {"name", "character"}` (host rozesílá jako dnes)
  - `Session.lobby_settings = {"arena": id}`
  - `start_match()` pošle sloty, postavy a arénu v jedné zprávě `_begin_match`
- **Obsah:**
  - `data/arenas/*.tres` (`ArenaData`: `id`, `name_key`, `scene`, náhled)
  - `data/characters/*.tres` (4 postavy dle G.0)
  - `ContentDB` vrací seznamy pro výběr
- **Bezpečnost (sekce S):** výběr je jen žádost. Host ověřuje id proti `ContentDB` a fázi (jen v lobby). Neznámé id ignoruje.

### T.3 Zařazení do roadmapy
- **M3:** výsledky, návrat do lobby, opakované zápasy (T.1)
- **M5:** výběr postavy v lobby (T.2)
- **M6:** výběr mapy hostitelem (T.2), 2–3 arény

### T.4 Skóre a hlášení zabití (ZADÁNÍ UŽIVATELE 2026-11-04)
- Vedle jména každého hráče v HUD zobrazovat počty zabití a smrtí v aktuálním zápase.
- Zabití připíše host hráči, jehož kulka zasáhla oběť jako poslední před její smrtí; nezavádět časové vypršení zásahu. Smrt bez předchozího zásahu nepřidá nikomu zabití. Při respawnu se poslední střelec vynuluje.
- Zobrazit hlášení `Kill`, `Double kill`, `Triple kill` (a další počet při více zabitích). Pro seskupení blízkých zabití použít okno 2 s mezi zabitími stejného střelce; to neomezuje platnost posledního zásahu.
- Skóre i oznámení určuje host a klienti je zobrazují. Na začátku nového zápasu se skóre a série vynulují.

## G. Postavy a schopnosti

### G.0 Zadání uživatele (2026-11-03), má přednost před G.3
- Hra má **více postav**. **První hratelná verze nabídne 4 postavy.**
- **Každá postava má 2 unikátní zbraně**, mezi kterými hráč ve hře přepíná, a **1 speciální schopnost**.
- **Zbraně:** od malých rychle střílejících SMG přes útočnou pušku (typ AK-47) po odstřelovací pušku (sniper).
  - Herní názvy budou vlastní nebo obecné (např. „Útočná puška“), ne obchodní značky.
- **Speciální schopnosti se ještě doladí.** Návrhy v G.3 jsou jen výchozí bod.
- **Vizuálně** (sekce Q) se nabízí 4 archetypy: samuraj, róninka s maskou kitsune, ninja s kusarigamou, ninja se šurikenem. Musí to ale být vlastní originální návrhy.
- **Data:**
  - `CharacterData.weapons: Array[WeaponData]` (přesně 2) + `ability: AbilityData`
  - `WeaponData` (id, `name_key`, `fire_rate`, `projectile_speed`, `damage_knockback`, `recoil`, `spread`, `pellets`, případně zásobník a nabíjení) v `data/weapons/*.tres`
- **Síť:**
  - Přepnutí zbraně je vstup od klienta (aktivní slot ve vstupu, 1 bit). Host ho ověří (cooldown přepnutí) a pošle ve snapshotu (`weapon_slot`), aby ostatní viděli správnou zbraň.
  - Střelba se řídí parametry aktivní zbraně jen na hostu.
- **Rozšiřitelnost:** nová zbraň = nový `.tres` (+ sprite). Nová postava = `.tres` s odkazy na 2 zbraně a schopnost.


### G.0a Rozhodnutí uživatele 2026-11-04 (M5)
- **ZMĚNA (uživatel 2026-11-04, večer): odstraníme možnost dvou zbraní – každá postava bude mít jen JEDNU zbraň.** Má přednost před bodem „2 vlastní zbraně“ níže i v G.0. Přepínání zbraní (Q / 1 / 2 / kolečko) zmizí. **Hotovo (0.1.12, 2026-11-05):** Architekt – dvouhlavňová brokovnice, Balvan – útočná puška, Jiskra – samopal, Krügermann – lehký kulomet, Stín – odstřelovačka, Vichr – bojová puška. `CharacterData.weapon` (jedna). Nepoužité zbraně (pistole, brokovnice, nýtovačka, revolver, kompaktní samopal, karabina) zůstávají v `data/weapons/` pro případné pozdější použití – uživatel 2026-11-05: zatím je nechat v datech.
- **Soupiska (zatím, data v `data/characters/`):** Jiskra (róninka, lehká) – samopal + pistole, úskok; Balvan (samuraj, těžký) – brokovnice + útočná puška, štít; Vichr (ninja s kusarigamou) – bojová puška + karabina, tlaková vlna; Stín (ninja se šurikenem, lehký) – odstřelovačka + kompaktní samopal, přesun (teleport ~250 px ke kurzoru, cd 7 s).
- **Každá postava má 2 vlastní zbraně (8 celkem).** Přepínání: Q, 1 / 2 a kolečko myši; po přepnutí 0,3 s bez střelby.
- **Stejnou postavu nesmí mít dva hráči** v jednom zápase (výběr v lobby M5.3 obsazené postavy zablokuje).
- **Knockback nesmí být příliš vysoký:** limity `CombatRules.MAX_KNOCKBACK_PER_SHOT` = 1400 (všechny broky dohromady) a `MAX_KNOCKBACK_PER_SECOND` = 7500 (měřítko: pistole 800 × 9/s), hlídá `tests/test_weapons.gd`.
- **Rozhodnutí 2026-11-04 (pokračování):** zpomalovací plyn a dočasná plošina patří **2 novým originálním postavám** (celkem 6): **Krügermann** (původně „Mlha“, přejmenováno na pokyn uživatele; vlastní kreslený návrh – potrhlý vynálezce, NE podle fotografie a bez nacistické symboliky; lehký kulomet + revolver; arkádový zpomalovací oblak ke kurzoru, mizí po 3 s) a **Architekt** (stavitel chrámů; nýtovačka + dvouhlavňová brokovnice, 8 broků; dočasná plošina pod sebou). Kroky M5.2: a) systém + štít + tlaková vlna (hotovo, 0.1.7), b) úskok + přesun s predikcí (hotovo, 0.1.8), c) oblak + plošina (objekty ve světě, replikace na klienty; hotovo, 0.1.9).
- **BUDOUCÍ PRÁCE – chování zbraní (pokyn uživatele 2026-11-04, zatím neplánováno do kroku):** fungování zbraní ještě detailně ošetříme. Ne všechny zbraně mají mít dosah přes celou mapu (např. brokovnice jen na krátko). Dnes: `WeaponData.max_range` (brokovnice 650, dvouhlavňová 500, odstřelovačka 3000 px) a střela prostě zmizí. Ke zvážení: úbytek knockbacku se vzdáleností, viditelný konec dostřelu, zásobník a přebíjení, rozptyl při pohybu/skoku, různé rychlosti a velikosti střel, zvuk a efekty. Rozhodnout s uživatelem, nejpozději v M5.4 nebo M6 (balanc zbraní).
- **Pokyny 2026-11-04:** vše má být **arkádové** (výrazné, svižné efekty); rychlopalné zbraně musí mít znatelný zpětný ráz (`CombatRules.MIN_RECOIL` = 100, hlídá test).
- **Původní zadání (2026-11-04):** uživatel navrhl schopnosti „zpomalovací plyn ve směru kurzoru, mizí po 3 s“ a „dočasná plošina pod sebou“ (postava „Architekt“). Mechaniky jsou v pořádku; postavu podle fotografie v nacistické uniformě s plynem Claude odmítl a fotografie skutečných lidí se jako předlohy nepoužijí (postavy musí být vlastní originální návrhy, sekce Q). Čeká na rozhodnutí, kterým postavám schopnosti přidělit.
- **Kroky M5:** M5.1 zbraně + přepínání + data postav (hotovo, 0.1.6) → M5.2a/b/c schopnosti + cooldown v HUD (hotovo, 0.1.9) → M5.3 výběr postavy v lobby, každá jen jednou (hotovo, 0.1.11) → M5.4 `EDITING_GUIDE.md` a ladění.
- **Krügermann – vzhled (2026-11-04):** uživatel chtěl obličej podle dodané fotografie (muž v nacistické uniformě). Claude odmítl: podobu podle té fotky u postavy s plynem nevytvoří ani bez symbolů. Postava zůstává vlastní originální návrh. Plyn je na přání uživatele dlouhý vodorovný pás místo kruhu, od 0.1.13 540 × 90 px (uživatel: delší).

### G.1 Systém
- `AbilityData extends Resource` obsahuje `id`, `name_key`, `description_key`, `cooldown` a metody:
  - `can_activate(player) -> bool`
  - `activate(player) -> void` (jen host)
  - `physics_tick(player, delta)` (pro schopnosti s trváním)
- Každý *druh* schopnosti je jedna podtřída se `@export` parametry (např. `DashAbility` má `dash_speed`, `duration`).
- **Nová varianta existujícího druhu = jen nový `.tres`. Nový druh = jeden malý skript.**
- Runtime stav (zbývající cooldown v ticích, zbývající trvání) drží `player.gd`, ne resource. Resource je sdílený, proto zůstává bezstavový.
- `CharacterData` obsahuje `id`, `name_key`, `description_key`, `sprite/scene`, `color`, `weight`, `move_speed`, `jump_velocity`, `ability: AbilityData` a `starting_weapon: WeaponData`.

### G.2 Síť
- Aktivace = bit `ability` ve vstupu. Host ověří cooldown, provede schopnost a pošle `ability_used` (jen kvůli efektu).
- Cooldown se posílá ve snapshotu (`ability_cd_ticks`) a HUD z něj kreslí ukazatel. Klient si cooldown nikdy neodpočítává sám.

### G.3 Tři postavy

| Postava | Schopnost | Herní dopad | Implementace / síťová náročnost |
|---|---|---|---|
| **Jiskra** (lehká, rychlá) | **Úskok (dash):** 0,15 s rychlý přesun ve směru pohybu, i ve vzduchu. Cooldown 4 s. | záchrana po odhozu, agresivní nájezdy | **nízká:** jen nastaví rychlost a pohyb jde snapshotem. Při predikci (M4) ji musí motor simulovat i u klienta, proto bude dash součástí `PlayerMotor`. |
| **Balvan** (těžký, pomalý) | **Štít:** 1,5 s, příchozí knockback ×0,2, nemůže střílet. Cooldown 8 s. | přečkání palby, kontra-hra | **nízká:** příznak ve `flags` ve snapshotu. Knockback počítá jen host. |
| **Vichr** (střední) | **Tlaková vlna:** okamžitý radiální impulz soupeřům v okruhu 120 px. Cooldown 10 s. | vytlačení soupeřů z hrany | **střední:** hledání cílů v okruhu na hostu a efekt přes `ability_used`. Kvůli interpolaci soupeři „odletí“ o ~100 ms později, než to klient vidí (přijatelné). |

Čísla jsou výchozí a nastavují se v `.tres`.

---

## H. Editovatelná data a lokalizace

### H.1 Formáty

| Co | Formát | Proč |
|---|---|---|
| Balanc (postavy, zbraně, schopnosti, arény, pravidla) | **`.tres`** | typované, editor je zobrazí jako formulář, ve VS Code je to čitelný text `klíč = hodnota`, Godot hlídá typy |
| Texty | **CSV** (`localization/translations.csv`, sloupce `keys,cs`) | Godot ho nativně importuje jako překlad, jde snadno upravit a přidat jazyk = přidat sloupec |
| JSON | nepoužijeme | bez typů a bez editoru, vlastní parser by byl zbytečný kód |

**Potvrzuji tvůj odhad:** `.tres` pro data a CSV pro texty.

### H.2 Klíče a texty
- Klíče jsou centrální, např. `MENU_PLAY`, `LOBBY_COPY_ADDRESS`, `CHARACTER_JISKRA_NAME`, `ABILITY_DASH_DESCRIPTION`, `ERROR_VERSION_MISMATCH`.
- Texty s proměnnými používají `{name}` a `.format()`.
- CSV musí být v UTF-8 s uvozovkami u textů s čárkou.
- Výchozí locale je `cs`.

### H.3 Font
**Noto Sans** (SIL Open Font License 1.1, volně šiřitelný) s plnou podporou české diakritiky. Licenci zapíšeme do `CREDITS.md`.

### H.4 Kontrola úplnosti
`tools/check_localization.gd` běží headless v CI. Najde všechny `*_key` v `.tres` a všechny `tr("...")` a `text = "KEY"` ve scénách a skriptech a ověří, že každý klíč má český text. Když něco chybí, CI selže.

### H.5 `docs/EDITING_GUIDE.md` (česky)
Bude obsahovat návody:
- **Přidat postavu:** zkopírovat `data/characters/scout.tres`, změnit `id` a hodnoty, přidat 2 řádky do CSV.
- **Změnit schopnost:** upravit `data/abilities/*.tres`.
- **Přebalancovat zbraň:** upravit `data/weapons/*.tres` (`knockback`, `fire_rate`, `projectile_speed`, `recoil`, `spread`).
- **Upravit text:** změnit řádek v CSV.
- **Pravidlo:** po změně dat musí všichni hrát stejný build (zajišťuje kontrola verze).

---

## I. Distribuce a buildy

**Rozhodnutí uživatele 2026-11-04 nahrazuje původní rozdělení dev/stable:** jediné průběžně aktualizované
vydání, nyní `v0.1.1`, poté `v0.1.2` atd. Verze je výslovně uložená v `project.godot`; před novým
vydáním ji zvýšit. Číslo sestavení dál slouží pořadí aktualizací, nikoli jako veřejná verze.
Následující I.1–I.3 popisují aktuální postup; historické zmínky o dvou kanálech níže již neplatí.

### I.1 Workflow `.github/workflows/build.yml`
- **Spouštěče:** `push` na `main`, ruční `workflow_dispatch` pouze pro main. Dokumentace nadále nevydává build.
- **Serializace:** jedna skupina `publish-game`, `cancel-in-progress: false`, aby se publikace nepřerušila mezi soubory a manifestem.
- **Jeden job na `ubuntu-latest`** (stačí pro všechny exporty, macOS runner nepotřebujeme, minuty jsou levné):
  1. `actions/checkout` s `fetch-depth: 0` (kvůli rostoucímu číslu sestavení).
  2. Stažení **Godot 4.7.2** (linux headless binár) a **export templates** přímo z oficiálních GitHub releases Godotu. Uložení do `actions/cache` podle verze.
     - Proč bez actions třetích stran: méně závislostí a nečekáme, až je někdo aktualizuje na novou verzi Godotu. Alternativa je `chickensoft-games/setup-godot`.
  3. `godot --headless --import`, tedy kontrola parse a importu.
  4. Spuštění `tests/run_tests.gd` a `tools/check_localization.gd`.
  5. `tools/write_build_info.gd` vygeneruje `build_info.json`: verze z projektu, build z počtu commitů, krátký commit, kanál stable. Stejnou verzi nastaví i do macOS exportních metadat. Testy `tests/test_release_workflow.py` prověří publikaci bez přístupu k GitHubu.
  6. Export presetů: *Windows Desktop* (x86_64, PCK zabalené do exe), *macOS* (universal, ad-hoc podpis vestavěným codesignem Godotu) a volitelně *Linux*.
  7. Windows jako jediný `gun_game-windows.exe`, macOS a Linux jako ZIP; manifest obsahuje jejich SHA-256. Poznámky vznikají ze společného changelogu.
  8. `tools/publish_release.sh` vyžaduje existující release `dev`, následující patch/minor/major a vyšší build (nebo opakování stejné dvojice). Přeskakování verzí nepovolí. Nahraje soubory hry a pak `version.json`; stávající vydání označí stable/latest s názvem `gun_game vX.Y.Z`.
  9. Po ověření úspěchu skryje staré `v0.1.0` jako koncept, bez smazání vydání či tagu. Nové release ani tagy nevytváří a existující tagy neposouvá.
- **Odhad doby:** ~3–6 min na běh. Pro veřejné repo jsou minuty zdarma.

### I.2 Pevné adresy a kompatibilita
- Jediná veřejná stránka: `.../releases/latest`; původní interní tag `dev` zůstává kvůli již staženým hrám.
- `.../releases/download/dev/version.json` i `.../releases/latest/download/version.json` vedou na stejný manifest. Starý dev klient nainstaluje novější build a přejde na stable/latest.
- Tag `dev` se již neposouvá, aby nevznikaly konflikty při pullu. Automatické archivy zdrojů u tagu proto zůstávají historické; poznámky vydání odkazují na skutečný commit aktuální hry.

### I.3 Verzování
- SemVer uložené v projektu: `0.1.1` → `0.1.2` → `0.1.3`; větší změny mohou výslovně zvýšit minor/major. Verze se neodvozuje z náhodného nebo nejbližšího tagu.
- Menu ukazuje stejnou verzi jako vydání, navíc rostoucí číslo sestavení.
- Kontrolu kompatibility v síti dělá `build_id` (D.8) a navíc `PROTOCOL_VERSION` v `build_info.gd`.

### I.4 Windows
- Rozbalit a spustit `gun_game.exe`, žádný instalátor.
- **SmartScreen** („Systém Windows ochránil váš počítač“): klikni *Další informace* → *Přesto spustit*.
  - Odstranit to jde jen code signing certifikátem (~stovky USD ročně) a reputací. Neplánuje se.
- **Firewall** se ptá jen hostitele: povolit, ideálně pro soukromé i veřejné sítě.
- Ikonu exe nastavíme později (ověřit, zda Godot 4.7 upravuje PE ikonu bez `rcedit`).

### I.5 macOS (upřímně)
- Build je universal (Apple Silicon + Intel), **ad-hoc podepsaný a nenotarizovaný**. Apple Silicon vyžaduje aspoň ad-hoc podpis a Godot ho při exportu umí i na Linuxu.
- **Postup pro kamarády (Sequoia 15+, ověřeno z několika zdrojů pro 15.x, pro macOS 26 neověřeno):**
  1. Rozbal ZIP (Safari to udělá samo) a přesuň `gun_game.app` třeba do Aplikací.
  2. Dvakrát klikni. Objeví se „Apple nemůže ověřit…“ → klikni **Hotovo**.
  3. Otevři **Nastavení systému → Soukromí a zabezpečení**, sjeď dolů a u hlášky o gun_game klikni **Přesto otevřít**.
  4. Potvrď heslem nebo Touch ID a pak **Otevřít**.
  5. Záloha, pokud tlačítko chybí: v Terminálu spusť `xattr -dr com.apple.quarantine /Applications/gun_game.app`.
- U každé nové verze se to musí zopakovat. Pokud má Mac zapnutý firewall, může se znovu ptát i na příchozí spojení.
- **Podpis a notarizace:** Apple Developer Program stojí 99 USD/rok. Pak by v CI šel použít Developer ID certifikát a `notarytool` (tajné klíče v GitHub Secrets). Zbavilo by to kamarády všech kroků výše. Doporučuji až když to bude obtěžovat.

### I.6 Zdrojový kód vs. hratelný ZIP
Zelené tlačítko „Code → Download ZIP“ a „Source code (zip)“ u releasů jsou **zdrojáky**, které bez Godotu nespustíš. Kamarádi stahují soubory **`gun_game-<systém>.zip`** ze sekce *Assets*. README to bude zdůrazňovat přímými odkazy.

### I.7 Licence (ZMĚNA 2026-11-03 na přání uživatele)
- **Celý projekt (kód i vlastní grafika a zvuky): PolyForm Noncommercial 1.0.0.** Stahovat, hrát, upravovat a sdílet smí kdokoli, ale jen nekomerčně. Prodej a výdělek jsou zakázané. Původní MIT nahrazeno.
- Cizí assety jen s kompatibilní licencí, vždy se zdrojem v `CREDITS.md` (Noto Sans OFL, Godot MIT).
- Kdo si stáhl starší verzi pod MIT (do `v0.1.0` včetně), smí ji podle MIT dál používat. Změna platí pro nové verze.

### I.8 Automatické aktualizace (ZADÁNÍ UŽIVATELE 2026-11-03, milník M3U)
**Cíl:** hráči nemusí po každé změně ručně stahovat hru a znovu ji povolovat. Hra po spuštění sama zjistí, že na GitHubu je nová verze, nabídne aktualizaci, stáhne ji a restartuje se. Tím zmizí i chyba „Máš jinou verzi hry“.

**Postup:**
1. **CI** ke každému buildu publikuje malý soubor `version.json` v jediném vydání:
   - `version`, `build`, `channel`
   - pro každý systém URL souboru a jeho **SHA-256**
2. **Hra při startu v hlavním menu** stáhne přes `HTTPRequest` (HTTPS) `version.json` z pevné adresy tohoto repozitáře:
   - `https://github.com/nejhorsiprogramatorsveta/Gun_game/releases/download/dev/version.json`
   - Pokud je číslo sestavení vyšší než vlastní, menu ukáže: *„Je dostupná nová verze X. [Aktualizovat] [Později]“*.
   - Bez internetu nebo při chybě se nic nestane a hra jde normálně hrát.
3. **Aktualizace:** stažení s ukazatelem průběhu do dočasného souboru a ověření SHA-256. Pak záměna:
   - **Windows:** běžící `.exe` nejde přepsat, ale jde přejmenovat. `gun_game.exe` → `gun_game.old.exe`, nový soubor → `gun_game.exe`, spustit nový proces (`OS.create_process`) a ukončit se. Starý soubor smaže nová verze při startu. Funguje, pokud hra leží ve složce s právem zápisu (Plocha, Stažené soubory, Dokumenty). Jinak záložní řešení: otevřít stránku ke stažení.
   - **macOS:** stáhnout ZIP, rozbalit (`ZIPReader`) vedle aplikace a vyměnit `.app` za novou. Soubor stažený samotnou hrou nedostane karanténní značku, takže **odpadne opakované povolování v Nastavení**.
     - Omezení: pokud macOS spouští aplikaci z „translokované“ kopie (nebyla přesunutá z Downloads), výměna nejde. Pak hra poradí přesunout aplikaci do *Aplikací*, případně otevře stránku ke stažení.
   - **Linux:** jako Windows (jeden binární soubor).
4. Aktualizace se nabízí **jen v menu, nikdy během hry nebo v lobby**.
5. Pořadí aktualizací hlídá vyšší číslo sestavení. Nové hry kontrolují stable/latest; dosavadní dev klienti zůstávají kompatibilní díky zachované adrese `dev`.

**Bezpečnost (sekce S):**
- Stahuje se jen z pevné HTTPS adresy tohoto repozitáře a ověřuje se SHA-256.
- **Doporučeno navíc:** CI podepíše `version.json` soukromým klíčem z GitHub Secrets a hra má zabudovaný veřejný klíč (`Crypto.verify`, RSA). Podvržená aktualizace by pak neprošla, ani kdyby někdo získal přístup k release stránce.
- Nic se nespouští jako správce.

**Rizika:**
- Antivirus může podezírat program, který přepisuje vlastní exe. Ověřit na Windows (odložené testy).
- Samoaktualizace na macOS je křehčí, proto záložní cesta „otevřít stránku ke stažení“.
- Při chybě aktualizace musí zůstat funkční stará verze (nový soubor se použije až po úspěšném ověření).

---

## J. Projektová paměť

### `CLAUDE.md` (počáteční obsah, anglicky jako konvence pro AI, krátký)
```
# gun_game – project guide for Claude Code
## Session start (mandatory)
1. Read this file and docs/PROGRESS.md (docs/PLAN.md = approved plan, read relevant sections). 2. `git status` + `git log --oneline -10`.
3. Briefly confirm the current state in Czech (milestone, last finished task, next step).
## Resume protocol ("přečti si progress a pokračuj")
If the user only says to read progress and continue: do the session start, then execute exactly the task in
PROGRESS.md "Další krok" – nothing more. If "Další krok" is unclear, blocked, or needs a user decision, ask instead of guessing.
If PROGRESS.md and git disagree (e.g. uncommitted changes, task half-done), report it first.
## End-of-task protocol (mandatory after EVERY task, also when interrupted or unfinished)
1. Update docs/PROGRESS.md: "Kde jsme skončili" (what part of which milestone is done / half-done, uncommitted files),
   "Další krok" (one concrete next task, specific enough to start without asking), "Poslední změny", "Stav testů", "Známé problémy".
2. Give the user a Czech overview: which part of the plan (milestone/step) was completed, what remains in the milestone,
   changed files, how to test, what was NOT tested, proposed commit message.
3. Stop. Do not start the next step on your own.
## Communication
Respond to the user in Czech. Code, identifiers, commits in English. Player text only via tr() keys in localization/translations.csv.
## Purpose
Online 2–4 player 2D knockback arena shooter. Host-authoritative listen server. Friends download ZIP from GitHub Releases.
## Stack
Godot 4.7.2-stable (non-.NET), GDScript (static typing), Compatibility renderer.
## Commands (pinned Godot lives in .tools/, never use a system-wide godot)
- Setup dev env (once): `tools/setup_env.sh` (add `--with-templates` for local exports)
- Run: `tools/godot --path .`   - Two local instances: run twice, one Host, one Join 127.0.0.1
- Tests: `tools/godot --headless --path . -s tests/run_tests.gd`
- Loc check: `tools/godot --headless --path . -s tools/check_localization.gd`
- Export: `tools/godot --headless --path . --export-release "<preset>" <out>`
## Architecture (key files)
src/autoload/session.gd, src/net/*, src/match/match_controller.gd, src/player/player_motor.gd, data/*.tres
## Rules
Host decides all gameplay. RPC only in session.gd / net/ / match_net.gd. Connection only via src/net/connectors/.
Scripts < ~300 lines, one responsibility. No new autoloads/addons/assets without approval. Record assets in CREDITS.md.
Never claim something works unless tested.
```

### `docs/PROGRESS.md` (česky, počáteční obsah)
```
# Stav projektu
## Kde jsme skončili
Milník M0 hotový: plán schválen (docs/PLAN.md), vývojové prostředí připraveno (tools/setup_env.sh → .tools/, Godot 4.7.2).
Rozpracováno: nic. Necommitnuté soubory: (vypsat).
## Další krok
M1 celý (prompt P1 v docs/PLAN.md, sekce P).
## Aktuální stav
Milník: M0. Funguje: lokální Godot 4.7.2 přes tools/godot. Hra: zatím nic.
## Poslední změny
- (datum) Vytvořen plán projektu.
## Co je potřeba udělat
1. M1: kostra projektu, lokální pohyb, CI build s ZIPy.
## Známé problémy
- žádné
## Stav testů
- Nic netestováno.
## Rozhodnutí
- Godot 4.7.2 + GDScript – nejmenší buildy, export všech platforem z Linuxu.
- Host-autoritativní listen server, ENet – jednoduché, bez serveru.
- Vlastní snapshot 30 Hz místo MultiplayerSynchronizer – kontrola nad interpolací a velikostí.
- MVP připojení: IP + UPnP, záloha Tailscale; později noray kódy.
- Rolling prerelease tag `dev` (ne `latest`) – /releases/latest ukazuje jen stable.
```

---

## K. Roadmapa

### Changelog – vydáno v sestavení 28 (zadání uživatele 2026-11-04)
- **Stav:** offline „Co je nového“ v menu a společný generátor poznámek vydání jsou implementované, otestované a publikované uživatelovým pushem `2560ebb`. Navazuje sjednocení vydávání na `0.1.1`, potom debug měření RTT/korekcí v M4.
- **Funkce:** přehled „Co je nového“ dostupný z hlavního menu, přiřazený ke konkrétní verzi a číslu sestavení. Česky stručně uvést novinky, opravy a změny ovládání; nejnovější změny zobrazit první. Stejný přehled použít v poznámkách odpovídajícího vydání.
- **Data a údržba:** `data/changelog.tres` uchovává aktuální záznam (`build = 0`) a historii od sestavení 25; texty jsou v CSV. Aktuální záznam přebírá skutečnou verzi/sestavení z `BuildInfo`. Před další obsahovou změnou archivovat tento záznam pod skutečně publikovaným buildem a založit nový aktuální záznam. Starší build nesmí zobrazovat budoucí změny.
- **Distribuce dle nového zadání:** jediné vydání s výslovně rostoucí verzí (`0.1.1`, `0.1.2` atd.), viz I.1–I.3. Zachovat stávající adresy aktualizátoru, SHA-256, rostoucí buildy a pořadí nahrávání: nejdřív soubory hry, poslední `version.json`.
- **Ověření:** changelog odpovídá zobrazené verzi/sestavení a je dostupný i bez internetu; české texty a zobrazení projdou kontrolami. Ověřit poznámky vydání a regresi aktualizátoru. Nic nepublikovat ani nepushovat bez nového výslovného souhlasu.
- **Odložené:** opravu sekání na stejné Wi-Fi (M4.1) nyní nespouštět.

### M1 – Kostra, lokální pohyb, CI s ZIPy *(střední)*
- **Cíl:** spustitelná hra stažitelná z GitHubu.
- **Funkce:** projekt, `.gitignore`, README, CLAUDE.md, PROGRESS.md, LICENSE a CREDITS; hlavní menu s verzí; jedna testovací aréna; `PlayerMotor` a postava ovládaná klávesnicí (lokálně, bez sítě); lokalizace CSV a font; `build_info`; testovací runner; workflow s exporty a prereleasem `dev`.
- **Soubory:** `project.godot`, `export_presets.cfg`, `build.yml`, `main_menu`, `player_motor.gd`, `player.gd`, `input_frame.gd`, `arena_rooftops.tscn`, `data/characters/*.tres`, `translations.csv`.
- **Závislosti:** GitHub repo (veřejné, viz O1).
- **Testy:** CI zelené; ZIP stažený z `releases/tag/dev` jde spustit na Windows (hlavní platforma), na Macu podle možností (Gatekeeper postup); pohyb a skok fungují; diakritika se zobrazuje správně.
- **Akceptace:** kamarád stáhne ZIP, spustí ho a vidí menu s verzí.

### M2 – Síťové jádro: lobby a synchronizovaný pohyb *(vysoká)*
- **Funkce:** `Session` (host/join, fáze, seznam hráčů), `EnetDirectConnector`, UPnP pomocník, lobby UI s kopírováním adresy, handshake verze, spawn a despawn, vstupy 60 Hz, snapshoty 30 Hz, interpolace, odpojení a timeouty, `LagSimulator`, české chybové hlášky.
- **Testy:**
  - 2 instance na jednom PC
  - fake lag 100 ms / 5 % ztrát
  - **2 počítače v LAN**
  - **první internetový test:** UPnP nebo port forward, případně Tailscale
  - různé buildy → hláška o verzi
  - pád hosta i klienta
- **Akceptace:** 2 hráči na různých počítačích přes internet vidí plynulý pohyb toho druhého. Neshoda verzí dá jasnou hlášku.

### M3 – Souboj = MVP *(vysoká)*
- **Funkce:** pistole, projektily (raycast na hostu, vizuální kopie na klientech), knockback a recoil, `kill_rect`, životy, respawn s nezranitelností, odpočet, konec zápasu, výsledky, **návrat do stejného lobby a opakované zápasy bez nového hostování (sekce T.1)**, HUD (životy), návod „Jak hrát s kamarády“ v README a na release stránce.
- **Testy:** unit testy `combat_rules` a `snapshot`; konzistence knockbacku (host i klient vidí stejný výsledek); podvržené vstupy (rychlá palba se ignoruje); **zápas přes internet s kamarádem Windows↔Windows** (Windows↔macOS volitelně).
- **Akceptace:** celý herní cyklus přes internet. Vydat tag **`v0.1.0`**.

### M3U – Automatické aktualizace *(střední)* — ZADÁNÍ UŽIVATELE 2026-11-03
- **Kdy:** hned po M3 (první hratelná verze `v0.1.0`), před M4. Od té chvíle kamarádi hrají pravidelně a ruční stahování každé verze (a chyba „jiná verze“) je největší překážka.
- **Funkce:**
  - `version.json` v CI (+ volitelný podpis)
  - `src/core/updater.gd` (kontrola, stažení, ověření, záměna, restart)
  - nabídka v menu
  - úklid `.old` souboru
- **Testy:** simulovaná nová verze (lokální `version.json`); poškozený soubor (špatný hash) → aktualizace se neprovede; bez internetu → hra běží normálně. Mac lokálně, Windows v odložených testech.
- **Akceptace:** po pushnutí nové verze se hráčům při dalším spuštění nabídne aktualizace a po jejím přijetí běží nová verze bez ručního stahování.

### M4 – Odezva online *(vysoká)*
- **Funkce:** měření (RTT v debug overlay), podle výsledku **predikce vlastního pohybu a reconciliation**, ladění interpolačního zpoždění, zpevnění validace (rate limit, fáze), okrajové případy odpojení.
- **Testy:** 30/80/120 ms a 2 % ztrát přes `LagSimulator` a skutečný internet; hodnocení „pocitu“ od kamarádů.
- **Akceptace:** při ~100 ms se vlastní postava ovládá bez znatelného zpoždění a korekce nejsou rušivé.

#### M4.1 – Sekání klientů na stejné Wi-Fi (nahlášeno 2026-11-04, odloženo)
- **Pozorování uživatele:** všem připojeným hráčům kromě hostitele se aktuální verze na stejné Wi-Fi výrazně seká. Příčina dosud nebyla změřena; nelze ji připsat samotné Wi-Fi, predikci ani připojování bez reprodukce a měření.
- **Rozsah nynějšího úkolu:** pouze zapsat problém a plán. Síťování, pohyb, predikci ani interpolaci kvůli tomuto problému nyní neopravovat; realizace až v samostatně zadaném úkolu.
- **Reprodukce:** stejný build na 2–4 počítačích ve stejné LAN/Wi-Fi, vystřídat hostitele a porovnat klid, pohyb, skoky, střelbu a zásahy. Zaznamenat konfiguraci, počet hráčů a přesný scénář; porovnat s localhostem a podle dostupnosti s kabelovou LAN.
- **Měření na hostu i klientech:** časy renderovacích a fyzikálních snímků (včetně špiček), RTT/jitter/ztráty a intervaly příchozích vstupů a snapshotů; délku a stáří front vstupů, potvrzování `last_input_seq`, historii predikce a četnost/velikost korekcí. Ověřit také zaplnění a výpadky interpolačního bufferu.
- **Izolace a následná oprava:** porovnat měření bez simulovaného zpoždění se stejnými scénáři při přidaném lagu a ztrátě paketů. Určit, zda zasekávání souvisí s výkonem snímků, doručováním, frontami nebo korekcemi, a až podle prokázané příčiny provést nejmenší opravu v navazujícím úkolu.
- **První test přes Tailscale (2026-11-04, verze 0.1.4, Mac host + kamarád klient, každý na své Wi-Fi):**
  - Připojení nejdřív selhalo oběma směry: každý byl ve vlastní Tailscale síti (`tailscale status` bez dalších zařízení). Po nasdílení Macu hostitele (Share) připojení funguje, spojení bylo **přímé** (IPv6, ne relay).
  - `tailscale ping`: 26–51 ms, občas 104–125 ms (výkyvy Wi-Fi). Herní ping u klienta ~100–150 ms, FPS v pořádku u obou.
  - Klient: „občas lag, spíš byl pohyb zpožděný“. Neupřesněno, zda vlastní postava, nebo postavy ostatních. Log hostitele bez chyb (hra do logu tehdy síťová čísla nezapisovala).
  - Od 0.1.5 hra každých 5 s zapisuje do logu řádek `[net]` (klient: ping, FPS, nejdelší pauza snapshotů, největší korekce vlastní postavy; host: FPS, fronta vstupů po slotech). Log: macOS `~/Library/Application Support/Godot/app_userdata/gun_game/logs/`, Windows `%APPDATA%\Godot\app_userdata\gun_game\logs\`.
  - **Kandidáti na opravu (zatím neschválené):** (a) postavy ostatních jsou zobrazené o RTT/2 + 100 ms interpolace pozadu → snapshoty 60 Hz místo 30 Hz a interpolace ~50 ms (data ~8 kB/s na klienta); (b) pokud jde o vlastní postavu, jsou to korekce predikce (odhoz, zpětný ráz, střelba se nepredikují) → zjistit z `correction_max` v logu.
- **Ověření budoucí opravy:** zopakovat původní reprodukci i lag/loss scénáře, porovnat metriky před/po, ověřit autoritu hostitele a plynulost místní i vzdálených postav při 2–4 hráčích. Samotný průchod headless testy nenahrazuje praktické ověření na stejné Wi-Fi.

### M5 – Postavy a schopnosti *(střední)*
- **Funkce:** `AbilityData` a podtřídy, **4 postavy se 2 zbraněmi a přepínáním (G.0)**, **výběr postavy v lobby (T.2, validuje host)**, cooldown v HUD, `EDITING_GUIDE.md`.
- **Testy:** unit test cooldownu; spam aktivace z klienta host ignoruje; schopnosti fungují online; kontrola lokalizace.
- **Akceptace:** novou postavu jde přidat jen přes `.tres` a CSV (vyzkoušíme).

### M6 – Obsah: zbraně, arény, 4 hráči *(střední)*
- **Stav (2026-11-05):** M6.1 + M6.2 hotové (0.1.14): `ArenaData` + `data/arenas/*.tres`, nové arény Chrámové schody a Visuté mosty (originální rozložení, zatím barevné plošiny), výběr mapy hostitelem v lobby (`ArenaChoice`, mapa se posílá i se startem zápasu), výběr mapy pro trénink v menu. Zbraně: uživatel zvolil 1 zbraň na postavu (G.0a), balanc zbraní = „budoucí práce“. **M6.3 (2026-11-05):** automatický test 4 hráčů (boti, 1 klient s lagem 100 ms / 3 %) na všech 3 mapách – celý zápas až k výsledkům a zpět do lobby bez chyb; host v zápase žádný snímek nad 16,7 ms (headless i s oknem, 120 FPS), max. ~34 střel naráz. **Vydáno jako `v0.2.0` (2026-11-05)** na pokyn uživatele; ruční test 4 lidí (aspoň 2 přes internet) zatím neproběhl.
- **Název hry (uživatel 2026-11-05: „pojmenuj ji příhodně“): Dojo Knockout.** Viditelný všude pro hráče (menu, okno, název vydání `GAME_TITLE` v CI, README). Interní `gun_game` zůstává v `config/name` (složka s nastavením `user://`), v názvech souborů ke stažení a v repozitáři – změna by rozbila aktualizace starších verzí a smazala uložené volby.
- **Funkce:** další zbraně a doladění balancu (SMG až sniper, G.0); 2 další arény (`ArenaData`); **výběr mapy hostitelem v lobby (T.2)**; 3–4 hráči.
- **Testy:** 4 hráči online (aspoň 2 přes internet); profilace výkonu na slabším notebooku a Macu.
- **Akceptace:** 4 hráči hrají plynule, ~60 FPS. Vydat `v0.2.0`.

### M7 – Připojení kódem (noray) *(střední–vysoká)* — **VOLITELNÉ (uživatel 2026-11-03 zvolil Tailscale). Realizovat jen na požádání.**
- **Funkce:** nasazení noray na VPS (návod v `docs/`), `NorayConnector`, pole „Kód hry“, přímá IP zůstává jako záloha.
- **Testy:** host za CGNAT (mobilní hotspot) ↔ klient doma; relay fallback; výpadek serveru → srozumitelná hláška.
- **Akceptace:** připojení bez nastavování routeru u hostitele pod CGNAT. Náklady jsou zapsané v PROGRESS.

### M8 – Polish a 1.0 *(střední)*
- **Funkce (ZADÁNÍ UŽIVATELE 2026-11-03: až na konci vývoje):**
  - **Zvuk:**
    - **hudba** (menu, zápas)
    - **zvuky postav** (skok, dopad, zásah, vypadnutí, schopnost)
    - **zvuky zbraní** (každá zbraň vlastní výstřel)
    - Licence všech zvuků zapsat do `CREDITS.md`.
  - **Menu Nastavení:**
    - **hlasitost** (hudba / efekty zvlášť)
    - **omezení FPS** (např. 30/60/120/bez limitu) a V-Sync
    - **celá obrazovka / okno / maximalizované okno**
    - **ovládání s přenastavením kláves** (rebinding, uložení do `user://settings.cfg`)
    - jméno
  - efekty (částice, třesení kamery, volitelně), ikony
- **Testy:** čistý stroj Windows i macOS; kompletní regresní test online.
- **Akceptace:** vydat `v1.0.0`.

---

## L. Výkon

### Od začátku
- Compatibility renderer.
- Základní rozlišení 1280×720 se stretch módem `canvas_items`.
- Pevný fyzikální tick 60 Hz.
- Pojmenované kolizní vrstvy a masky: projektily kontrolují jen `world` a `players`.
- Projektily jako lehké `Node2D` s raycastem, ne `RigidBody2D`.
- `_process` jen tam, kde se kreslí. Logika běží v `_physics_process` jen na hostu.
- UI se aktualizuje přes signály a změny, ne každý snímek.
- Žádné alokace polí a slovníků v tick smyčce, kde to jde snadno: buffer snapshotu se znovu použije.
- Kompaktní binární zprávy.

### Až podle profileru
- **Pooling projektilů:** až když profiler ukáže špičky (u desítek kulek to téměř jistě nebude potřeba).
- Optimalizace partiklů a atlasy sprite.

### Nástroje
Godot Profiler, Network Profiler / Monitors (bandwidth, RPC) a debug overlay s FPS, RTT a velikostí snapshotu.

---

## M. Rizika a kompromisy

| Riziko | Dopad | Opatření |
|---|---|---|
| Latence a tuhé ovládání klienta | vysoký | M4 predikce, sdílený `PlayerMotor`, testy s lagem od M2 |
| Výhoda hosta (0 ms) | střední | přijímáme; volitelně lze hostu přidat umělé zpoždění vstupu (rozhodne se v M4) |
| Desync | střední | jediná autorita (host); klient nic nerozhoduje, takže desync je jen vizuální |
| NAT/CGNAT znemožní hostování | **vysoký** | detekce CGNAT ve hře, Tailscale návod, M7 noray |
| Náklady a údržba relaye | nízký–střední | Oracle Free / ~5 €/měs., IP připojení zůstane jako záloha |
| Složitost schopností s predikcí | střední | pohybové schopnosti (dash) uvnitř motoru, ostatní jen na hostu |
| macOS Gatekeeper | střední | upřímný návod, `xattr` záloha, notarizace jako placená volba |
| Křehké CI (změna URL šablon, verze actions) | střední | pevná verze Godotu, cache, minimum actions třetích stran, ruční spuštění |
| Rozbujení kódu od AI | střední | limit délky skriptů, malé prompty, review diffů, PROGRESS.md, zákaz nových autoloadů a addonů bez souhlasu |
| Firewall při každé nové verzi | nízký | zmíněno v návodu |

---

## N. Práce s Claude Code
- **Jeden prompt = jeden ucelený krok milníku** (např. „Session + handshake“ zvlášť od „lobby UI“). Ideálně do ~300–500 změněných řádků.
- Na začátku každé session se načte `CLAUDE.md` a `PROGRESS.md` a ověří se `git status` a `git log`. Šablona promptu (P2) to vynucuje.
- **Po každém tasku (i nedokončeném nebo přerušeném)** Claude:
  1. aktualizuje `docs/PROGRESS.md`, hlavně sekce **„Kde jsme skončili“** a **„Další krok“**;
  2. napíše česky přehled: kterou část plánu (milník a krok) splnil, co v milníku zbývá, co netestoval a návrh commit zprávy.
- **Návrat k práci:** díky tomu stačí napsat jen *„Přečti si progress a pokračuj“* (prompt P3). Claude pak udělá přesně krok ze sekce „Další krok“ a zastaví se. Tento postup je zapsaný v `CLAUDE.md` (Resume a End-of-task protocol), takže platí v každé nové session.
- Pokud se session blíží ke konci kontextu nebo ji chceš ukončit, napiš *„ulož progress“*. Claude okamžitě zapíše rozpracovaný stav.
- **Review:** před commitem projít `git diff`. Hledat nové soubory a autoloady, duplicitní logiku a hardcodované texty. Případně spustit `/code-review` nebo `/simplify`.
- Commit po každém funkčním kroku (Conventional Commits). PROGRESS se aktualizuje ve stejném commitu.
- **Testovat hned:** dvě instance lokálně po každé síťové změně, internetový test aspoň jednou za milník.
- Pokud Claude navrhne velkou architektonickou změnu, nejdřív ji vysvětlí a čeká na rozhodnutí.

---

## O. Otázky (odpovědi mohou změnit plán; mezitím platí uvedený předpoklad)

1. **Bude GitHub repo veřejné?** U soukromého repa kamarádi bez přístupu ZIP nestáhnou a minuty Actions jsou omezené.
   *Předpoklad: veřejné.*
2. **Máš (jako hostitel) veřejnou IPv4, nebo CGNAT? Jde u tvého routeru nastavit port forwarding nebo UPnP?** Pokud jsi pod CGNAT, MVP poběží rovnou přes Tailscale a noray (M7) by se vyplatilo posunout dřív, hned po M3.
   *Předpoklad: jde to nastavit.*

**Zodpovězeno:**
- **Platforma:** hlavně Windows. macOS universal build zůstává v CI, Linux je volitelný.
- **Ovládání:** klávesnice v MVP, gamepad v M8.
- **Název:** `gun_game` (provizorní).

---

## P. Prompty

### P1 – Start milníku M1 (copy-ready)
```
Read docs/PLAN.md (the approved project plan), and CLAUDE.md and docs/PROGRESS.md if they exist. Respond in Czech.
Implement milestone M1 only: "Skeleton, local movement, CI with ZIP builds".
Scope:
- Initialize git repo, Godot 4.7.2 project (Compatibility renderer, 60 Hz physics, 1280x720 canvas_items stretch, named collision layers), Godot .gitignore, .gitattributes, MIT LICENSE, CREDITS.md, Czech README.md (with download links to releases/tag/dev and a short "Jak hrát s kamarády" stub), keep the existing CLAUDE.md and docs/PROGRESS.md (already created per section J), docs/ARCHITECTURE.md (short).
- src/core/build_info.gd (reads res://build_info.json, falls back to "dev"), localization/translations.csv with cs column, Noto Sans font (record license in CREDITS.md).
- Main menu showing version via tr() keys; one test arena; player with PlayerMotor (pure, reusable movement step: run, jump, double jump, coyote time, jump buffer, one-way platform drop) driven by local keyboard input. Data in data/characters/*.tres and data/match_rules.tres.
- tests/run_tests.gd minimal headless runner with one PlayerMotor test; tools/check_localization.gd.
- export_presets.cfg (Windows x86_64 embedded pck, macOS universal ad-hoc signed, Linux x86_64) and .github/workflows/build.yml: pinned Godot 4.7.2 + templates downloaded from official releases with cache, import check, tests, loc check, build_info.json generation, export, zip as gun_game-<platform>.zip, publish to rolling prerelease tag `dev` on main and a full release on v* tags, concurrency cancel-in-progress.
Dev environment already exists: use tools/godot (pinned 4.7.2 in .tools/, created by tools/setup_env.sh); keep .tools/ in .gitignore. Never use a system-wide godot.
Verify CI details (template URLs, export CLI flags) against official docs before relying on them. No networking yet. Do not add addons.
When done: run available checks locally, list what you could not test, update the existing CLAUDE.md (verified commands) and docs/PROGRESS.md per section J and fill "Kde jsme skončili" and "Další krok", summarize in Czech (which part of the plan is done, changes, files, how I test), and propose a Conventional Commit message. Then stop.
```

### P2 – Šablona pro další milníky
```
Start of session: read CLAUDE.md and docs/PROGRESS.md, run `git status` and `git log --oneline -10`, and briefly confirm the current state in Czech before changing anything.
Task: implement milestone <MX – name> / step: <specific step> from docs/PLAN.md (read the relevant sections).
Constraints: change only what this step needs; reuse existing systems; no new autoloads, addons or third-party assets without asking; keep scripts focused (<~300 lines); static typing; all player-facing text via tr() keys in localization/translations.csv; host-authoritative gameplay; networking only in session.gd / src/net / match_net.gd; connection setup only in src/net/connectors.
Process: 1) explain the plan of changes in Czech and wait if it involves an architectural change; 2) implement; 3) run tests and the localization check; 4) state clearly what could not be tested (especially internet multiplayer and other OSes); 5) update docs/PROGRESS.md (and CLAUDE.md only if commands/conventions/architecture changed); 6) summarize in Czech: what was done, changed files, how I can test it (including two-instance and fake-lag steps where relevant); 7) propose a Conventional Commit message. Follow the End-of-task protocol in CLAUDE.md ("Kde jsme skončili" + "Další krok" in PROGRESS.md). Stop at the end of this step.
```

### P3 – Pokračování v další session (nejčastější prompt)
```
Přečti si progress a pokračuj.
```
Funguje díky protokolům v `CLAUDE.md`. Claude načte `CLAUDE.md`, `PROGRESS.md` a git stav, krátce shrne, kde jsme, udělá **jen** „Další krok“, uloží progress a zastaví se. Když chceš změnit pořadí nebo přidat něco mimo plán, použij místo něj P2.

---

## Ověření tohoto plánu (jak poznáme, že plán funguje)
- **M1:** CI vytvoří ZIPy a ty jdou spustit na čistém Windows (Mac volitelně).
- **M2:** dva počítače přes internet vidí pohyb toho druhého.
- **M3:** odehraný zápas přes internet s kamarádem (Windows↔Windows; macOS volitelně) a tag `v0.1.0`.

Každý milník končí záznamem testů v `docs/PROGRESS.md` s uvedením platforem.

## Zdroje
- Archiv vydání Godotu: https://godotengine.org/download/archive/
- Vydání Godotu na GitHubu: https://github.com/godotengine/godot/releases
- noray/netfox: https://github.com/foxssake/netfox/tree/main/addons/netfox.noray
- setup-godot: https://github.com/chickensoft-games/setup-godot
- godot-export: https://github.com/firebelley/godot-export
- Apple, otevření aplikace od neznámého vývojáře: https://support.apple.com/guide/mac-help/open-a-mac-app-from-an-unknown-developer-mh40616/mac
- Gatekeeper v Sequoii: https://www.macworld.com/article/2457844/what-to-do-when-you-cant-open-an-app-you-just-installed-in-macos-sequoia.html
