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
| `src/ui/main_menu.gd/.tscn` | hlavní menu s verzí |
| `tests/` | vlastní mini test runner (`run_tests.gd`, `TestCase`) |
| `tools/` | `setup_env.sh` + `godot` (připnutý engine), `check_localization.gd` |

## Kolizní vrstvy
1 `world` (pevné plošiny) · 2 `platform_oneway` · 3 `players` · 4 `projectiles` (od M3)

## Autoloady
Zatím žádné. V M2 přibude `Session` (síťová session) a `Settings` (nastavení).
