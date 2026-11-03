# Architektura (stručně)

Podrobný návrh je v [PLAN.md](PLAN.md), sekce D a F. Tento soubor popisuje, **co v kódu skutečně existuje**.

## Vrstvy
- **Data** (`data/`, `localization/`): jen hodnoty a texty, žádná logika. Upravuje se ručně.
- **Pravidla a simulace** (`src/player/player_motor.gd`, `src/match/`): od M2 poběží jen na hostu. `PlayerMotor` je sdílená funkce pohybu, kterou v M4 využije i predikce na klientovi.
- **Síť** (od M2): `src/autoload/session.gd`, `src/net/`, `src/match/match_net.gd`. RPC nikde jinde.
- **Prezentace** (`src/ui/`, kreslení v `player.gd` a `platform.gd`): nic nerozhoduje.

## Co je kde (stav po M1)

| Soubor | Odpovědnost |
|---|---|
| `src/core/build_info.gd` | verze a commit buildu (z `build_info.json`, který zapisuje CI), `PROTOCOL_VERSION` |
| `src/core/content_db.gd` | načte `data/characters/*.tres`, `data/weapons/*.tres` a `data/match_rules.tres`, vyhledávání podle id |
| `src/data_types/*.gd` | definice datových Resource (`CharacterData`, `WeaponData`, `MatchRules`) |
| `src/player/input_frame.gd` | vstup hráče za jeden tick: směr, tlačítka, úhel míření ke kurzoru (u16), pořadové číslo. Klienti ho posílají hostu. |
| `src/player/remote_interpolator.gd` | plynulé zobrazení postav na klientovi: snapshoty se zpožděním 100 ms (vlastní postava 40 ms) a prolínáním |
| `src/player/player_motor.gd` | pohyb: běh, skok + dvojskok (počítadlo skoků do dopadu), buffer skoku, seskok z plošiny |
| `src/player/player.gd/.tscn` | uzel postavy: na hostu `simulate()` z vstupu, na klientovi `receive_state()` ze snapshotu; jméno, barva slotu, čára zbraně |
| `src/arenas/arena.gd` | základ arény: spawn body (`SpawnPoints/*`), `kill_rect`, kamera `Camera` (zoom 0,85 = velikost pohledu) |
| `src/arenas/platform.gd` | obdélníková plošina (pevná nebo jednosměrná), nastavitelná v editoru |
| `src/match/match_controller.gd` | průběh zápasu pro trénink i síť: host simuluje všechny ze vstupů a posílá snapshoty 30 Hz, klient posílá vstupy 60 Hz; respawn, odchod hráčů |
| `src/combat/combat_rules.gd` | čisté vzorce: odhoz, zpětný ráz, rozptyl, kadence |
| `src/combat/projectile.gd` | střela: přímý let, raycast každý tick (host: svět + hráči, klient: jen svět) |
| `src/combat/weapon_system.gd` | střelba na hostu (kadence, zpětný ráz, odhoz) a zobrazení střel u klientů z událostí |
| `src/match/match_net.gd` | jediné RPC zápasu: vstupy klient → host, snapshoty host → klienti, události střel, „loaded“, rate-limit |
| `src/net/lag_simulator.gd` | jen pro vývoj: simulace zpoždění a ztrát paketů (`-- --fake-lag=100 --fake-loss=5`) |
| `src/net/net_codec.gd` | binární formát vstupů a snapshotů s kontrolou velikosti, `seq_newer()` |
| `src/ui/main_menu.gd/.tscn` | hlavní menu: jméno, trénink, Hostovat, adresa + Připojit, chybové hlášky (`Session.last_end_message`) |
| `src/ui/lobby.gd/.tscn` | lobby: seznam hráčů, u hostitele adresy ke sdílení s tlačítkem Kopírovat, Odejít |
| `src/autoload/settings.gd` | **autoload `Settings`**: jméno a poslední adresa v `user://settings.cfg` |
| `src/autoload/session.gd` | **autoload `Session`**: hostování a připojení, handshake verze, seznam hráčů v lobby (rozesílá host), odpojení a timeouty, české chybové hlášky přes signál `ended(message)` |
| `src/net/connectors/connector.gd` | rozhraní způsobu připojení: `host(port)` a `join(info)` vrací `MultiplayerPeer` |
| `src/net/connectors/enet_direct_connector.gd` | přímé UDP spojení (ENet) přes IP:port, rozbor adresy (IPv4, IPv6, hostname), timeouty peerů, `share_addresses()` (jen Tailscale a LAN, Tailscale se pozná podle rozhraní) |
| `src/net/handshake.gd` | `Handshake`: zprávy handshaku (sestavení, dekódování s limitem velikosti, kontrola verze a kódu hry), generování kódu hry |
| `tests/` | vlastní mini test runner (`run_tests.gd`, `TestCase`) |
| `tools/` | `setup_env.sh` + `godot` (připnutý engine), `check_localization.gd` |

## Handshake (kontrola verze)
1. Klient se připojí. Než se stane plnohodnotným peerem, pošle přes **autentizaci SceneMultiplayer** (surová data, ne RPC) zprávu `{protocol, build, name}`.
2. Host ji ověří: `PROTOCOL_VERSION` a `build_id` musí sedět, lobby nesmí být plné a nesmí běžet zápas.
3. **Shoda:** host odpoví `{ok: true}` a oba zavolají `complete_auth`. Teprve pak vznikne `peer_connected` a mohou chodit RPC. Host rozešle seznam hráčů.
4. **Neshoda:** host pošle důvod a svůj build, za 0,5 s klienta odpojí a klient zobrazí českou hlášku.

RPC se v Godotu párují podle indexu metody, proto by RPC handshake mezi různými buildy nebyl spolehlivý.

## Bezpečnost (PLAN.md, sekce S)
- Handshake vyžaduje **kód hry** (6 znaků z kryptograficky bezpečného generátoru). Ten se sdílí jako součást adresy `ip:port#KÓD`.
- `server_relay = false`: klienti mohou posílat RPC jen hostiteli.
- `allow_object_decoding` zůstává `false`. Zprávy handshaku jsou omezené na 512 B a dekódují se bez objektů.
- Hra neotevírá žádné porty v routeru a nesdílí veřejnou IP. Internet jde přes Tailscale, lobby nabízí jen Tailscale a LAN adresy.

## Plánovaný průběh (PLAN.md, sekce T)
- **Smyčka:** lobby → zápas → výsledky → **zpět do stejného lobby**. Session se nezavírá, nové hostování není potřeba.
- **V lobby:** každý hráč si vybírá postavu (host ji ověří), hostitel vybírá mapu.
- **Zatím neimplementováno:** návrat do lobby přijde v M3, výběr postavy v M5, výběr mapy v M6.

## Kolizní vrstvy
1 `world` (pevné plošiny) · 2 `platform_oneway` · 3 `players` · 4 `projectiles` (od M3)

## Autoloady
- `Settings` (nastavení, načítá se jako první)
- `Session` (síťová session musí přežít přechody mezi scénami)
