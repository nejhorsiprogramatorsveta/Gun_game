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
| `src/core/content_db.gd` | načte `data/characters/*.tres` a `data/match_rules.tres`, vyhledávání podle id |
| `src/data_types/*.gd` | definice datových Resource (`CharacterData`, `MatchRules`) |
| `src/player/input_frame.gd` | vstup hráče za jeden tick (směr a bitmaska tlačítek). Od M2 se posílá hostu. |
| `src/player/player_motor.gd` | pohyb: běh, skok, dvojskok, coyote time, buffer skoku, seskok z plošiny |
| `src/player/player.gd/.tscn` | uzel postavy: propojuje vstup, data, pohyb a placeholder grafiku |
| `src/arenas/arena.gd` | základ arény: spawn body (`SpawnPoints/*`), `kill_rect` |
| `src/arenas/platform.gd` | obdélníková plošina (pevná nebo jednosměrná), nastavitelná v editoru |
| `src/match/match_controller.gd` | průběh zápasu; v M1 lokální trénink s respawnem po pádu |
| `src/ui/main_menu.gd/.tscn` | hlavní menu: jméno, trénink, Hostovat, adresa + Připojit, chybové hlášky (`Session.last_end_message`) |
| `src/ui/lobby.gd/.tscn` | lobby: seznam hráčů, u hostitele adresy ke sdílení s tlačítkem Kopírovat, Odejít |
| `src/autoload/settings.gd` | **autoload `Settings`**: jméno a poslední adresa v `user://settings.cfg` |
| `src/autoload/session.gd` | **autoload `Session`**: hostování a připojení, handshake verze, seznam hráčů v lobby (rozesílá host), odpojení a timeouty, české chybové hlášky přes signál `ended(message)` |
| `src/net/connectors/connector.gd` | rozhraní způsobu připojení: `host(port)` a `join(info)` vrací `MultiplayerPeer` |
| `src/net/connectors/enet_direct_connector.gd` | přímé UDP spojení (ENet) přes IP:port, rozbor adresy (IPv4, IPv6, hostname), timeouty peerů, `share_addresses()` (LAN, Tailscale podle rozhraní, IPv6) |
| `src/net/upnp_helper.gd` | UPnP ve vlákně: otevře jeden UDP port s limitem 2 h, při odchodu ho zavře (neblokuje); `wait_for_all()` při zavření hry |
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
- UPnP otevírá jen jeden port s časovým limitem a zavírá ho při odchodu i při zavření okna.

## Kolizní vrstvy
1 `world` (pevné plošiny) · 2 `platform_oneway` · 3 `players` · 4 `projectiles` (od M3)

## Autoloady
- `Settings` (nastavení, načítá se jako první)
- `Session` (síťová session musí přežít přechody mezi scénami)
