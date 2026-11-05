# Architektura (stručně)

Podrobný návrh je v [PLAN.md](PLAN.md), sekce D a F. Tento soubor popisuje, **co v kódu skutečně existuje**.

## Vrstvy
- **Data** (`data/`, `localization/`): jen hodnoty a texty, žádná logika. Upravuje se ručně.
- **Pravidla a simulace** (`src/player/player_motor.gd`, `src/match/`, `src/combat/`): host rozhoduje o souboji a průběhu zápasu. `PlayerMotor` používá host i klient pro predikci vlastního pohybu.
- **Síť**: `src/autoload/session.gd`, `src/net/`, `src/match/match_net.gd`. RPC nikde jinde.
- **Prezentace** (`src/ui/`, kreslení v `player.gd` a `platform.gd`): nic nerozhoduje.

## Co je kde (M4: predikce vlastního pohybu + skóre)

| Soubor | Odpovědnost |
|---|---|
| `src/core/build_info.gd` | verze, číslo sestavení a commit buildu (z `build_info.json`, který zapisuje CI), `PROTOCOL_VERSION = 5` |
| `src/core/updater.gd` | automatické aktualizace: `version.json` z GitHubu, stažení, SHA-256, výměna exe/.app, restart, úklid |
| `src/core/changelog.gd`, `data/changelog.tres` | změny pro offline menu a poznámky vydání; menu i poznámky ukazují **jen nejnovější verzi** (`Changelog.latest()`), aktuální záznam podle `BuildInfo`, starší buildy nezobrazí budoucí změny |
| `src/core/content_db.gd` | načte `data/characters/*.tres`, `data/weapons/*.tres` a `data/match_rules.tres`, vyhledávání podle id |
| `src/data_types/*.gd` | definice datových Resource (`CharacterData`, `WeaponData`, `MatchRules`, `ChangelogData`) |
| `src/player/input_frame.gd` | vstup hráče za jeden tick: směr, tlačítka, úhel míření ke kurzoru (u16), pořadové číslo. Klienti ho posílají hostu. |
| `src/player/remote_interpolator.gd` | plynulé zobrazení vzdálených postav na klientovi: snapshoty se zpožděním 100 ms a prolínáním; při výpadku drží poslední stav |
| `src/player/client_prediction.gd` | okamžitý vlastní pohyb, historie až 120 nepotvrzených vstupů a stavů, obnova stavu hosta a přehrání vstupů; malé korekce vyhlazuje vizuální offset |
| `src/player/player_motor.gd` | sdílený pohyb: běh, skok + dvojskok, buffer skoku, seskok z plošiny, sklouznutí z hlavy; stav uchovává i kontakt se zemí pro reconciliation |
| `src/player/player.gd/.tscn` | uzel postavy: `simulate()` a `restore_state()` pro hosta/predikci, `receive_state()` pro vzdálené postavy; vizuální korekce, jméno, barva slotu, čára zbraně |
| `src/arenas/arena.gd` | základ arény: spawn body (`SpawnPoints/*`), `free_spawn_point()`, `kill_rect` (horní okraj otevřený), kamera `Camera` (zoom = velikost pohledu) |
| `src/arenas/platform.gd` | obdélníková plošina (pevná nebo jednosměrná), nastavitelná v editoru |
| `src/match/match_controller.gd` | host simuluje všechny ze vstupů a posílá snapshoty 30 Hz; klient posílá vstupy 60 Hz, predikuje sebe a aplikuje nejnovější čekající snapshot ve fyzikálním ticku; respawn, odchod hráčů |
| `src/match/match_score.gd` | host připisuje každou smrt poslednímu účinnému střelci, počítá zabití/smrti a série killů v okně 2 s; po smrti nebo odchodu čistí přiřazení |
| `src/combat/combat_rules.gd` | čisté vzorce: odhoz, zpětný ráz, rozptyl, kadence |
| `src/combat/projectile.gd` | střela: přímý let, raycast každý tick (host: svět + hráči, klient: jen svět) |
| `src/combat/weapon_system.gd` | střelba na hostu (kadence, zpětný ráz, odhoz) a zobrazení střel u klientů z událostí |
| `src/match/match_net.gd` | jediné RPC zápasu: vstupy klient → host, snapshoty host → klienti, spolehlivé události střel a kill hlášek, „loaded“, rate-limit |
| `src/net/net_stats.gd` | jen klient: ping = čas od odeslání vstupu po snapshot s jeho `last_seq` (vyhlazený); žádné nové síťové zprávy |
| `src/match/input_buffer.gd` | host: fronta vstupů jednoho klienta, 1 vstup za tick; strop 6, dohánění (když fronta za 0,5 s neklesne na 1, přebytek nejstarších se přeskočí a jejich tlačítka se přenesou), čte se i u mrtvého hráče; po 0,25 s bez vstupu neutrální vstup (postava stojí) |
| `data/weapons/*.tres`, `data/characters/*.tres` | 12 zbraní (`pellets` pro brokovnice), 6 postav, každá **jedna zbraň** (`CharacterData.weapon`, bez přepínání; 6 zbraní zatím nepoužitých); `CombatRules` limity knockbacku a minimum zpětného rázu (hlídá `tests/test_weapons.gd`); protokol 11 |
| `src/data_types/ability_data.gd`, `src/abilities/*.gd`, `data/abilities/*.tres`, `src/combat/ability_system.gd` | schopnosti: bezstavový resource (cooldown, trvání, `activate`, `knockback_scale`, `allows_firing`), podtřídy `ShieldAbility`, `ShockwaveAbility`, `DashAbility`, `TeleportAbility`; aktivace na stisk, cooldown a účinek na vlastní pohyb (`AbilityData.start`) běží v `Player.tick_ability()` uvnitř `simulate()` → host i predikce klienta počítají stejně; úskok je stav v `PlayerMotor.State` (`dash_time_left`, `dash_direction`); `AbilitySystem` (host) jen účinky na ostatní (`activate`) a připsání zásahů; snapshot: cooldown v tickách (u16), `FLAG_ABILITY_ACTIVE`, `FLAG_DASH_LEFT`, čas úskoku (39 B na hráče, protokol 8); HUD řádek se schopností |
| `src/combat/{area_effects,slow_cloud,temp_platform}.gd`, `src/abilities/{slow_cloud,platform}_ability.gd` | objekty schopností ve světě: `AbilityData.start()` (host i predikce majitele) volá `AreaEffects.spawn`, klíč schopnost/majitel/seq brání zdvojení při replay, host rozešle `send_effect_spawned` (reliable, validace v `match_net.gd`), u majitele vyhraje pozice hostitele; zpomalení = `PlayerMotor.State.speed_scale/jump_scale` nastavené v `Player.simulate` z `AreaEffects.slow_for` (majitel imunní); `ContentDB.get_ability` |
| `src/net/character_choice.gd` | výběr postavy v lobby: uzel `/root/Session/CharacterChoice`, klient pošle `_request(id)`, host ověří fázi, odesílatele, existenci, volnost (každá postava jednou) a limit 8 žádostí/s, uloží do `Session.players[peer].character` a rozešle; `first_free()` pro nové hráče (host preferuje postavu z menu, klient si o ni zažádá v lobby); `LobbyValidator.players` kontroluje postavy na klientech; `MatchController._spawn` použije zvolenou postavu |
| `src/data_types/arena_data.gd`, `data/arenas/*.tres`, `src/arenas/arena_{rooftops,temple_steps,hanging_bridges}.tscn`, `src/net/arena_choice.gd` | arény: `ContentDB.arena_ids()`/`arena_or_default()`; mapu vybírá jen host v lobby (`/root/Session/ArenaChoice`, reliable `_receive`, opakuje se při změně hráčů); `Session.arena_id` se zafixuje v `_begin_match(slots, arena)`, takže všichni hrají stejnou mapu; trénink `Settings.practice_arena` (zároveň první mapa při hostování); lobby v `ScrollContainer` |
| `src/match/teams.gd`, `src/net/team_choice.gd`, `src/match/match_ranking.gd`, `src/ui/score_table.gd` | režim 2 v 2: `Session.team_mode` přepíná jen host v lobby (`/root/Session/TeamChoice`, opakuje se při změně hráčů, zafixuje se v `_begin_match(slots, arena, teams)`); každý hráč má v `Session.players[peer].team` 0 = Červený / 1 = Modrý (nový jde do menšího týmu, klient o změnu jen žádá, host ověří fázi, rozsah a limit 8/s); v lobby se dá přejít kamkoli, start vyžaduje 1–2 hráče v každém týmu; sloty: červení 0 a 2, modří 1 a 3 (spawny vlevo/vpravo); `Player.team` – střely spoluhráčem proletí, tlaková vlna a plyn (`AreaEffects.teams`) spoluhráče nezasáhnou; konec zápasu a pořadí `MatchRanking` (celý vítězný tým 1. místo, výsledky nesou `team`); HUD = `ScoreTable` na tým (červený vlevo, modrý vpravo), jinak jedna tabulka vpravo |
| `src/net/character_choice.gd` (potvrzení), `src/ui/lobby.gd`, `src/ui/arena_preview.gd` | lobby: kliknutí na kartu postavy jen vybere (karta s náhledem prvního snímku spritu), „Potvrdit postavu“ ji zabere (`players[peer].ready`); nepotvrzená postava nikoho neblokuje – potvrzení ji vezme a držiteli host dá jinou volnou; start jen když `CharacterChoice.all_confirmed`; pozadí lobby = vybraná aréna v `SubViewport` (`ArenaPreview`, vlastní kamera, ztmavená) |
| `src/player/player_visual.gd`, `tools/art/generate_sprites.py`, `tools/art/reference_characters.py`, `assets/sprites/` | pixel art: `CharacterData.sprite_sheet` (10 snímků 32×40: idle 2, walk 4, jump, fall, shoot 2), `WeaponData.sprite` (2 snímky 34×12: normální, záblesk); `reference_characters.py` kreslí Krügermanna ve svetru a Architekta s knírem v obleku podle uživatelových stylizovaných předloh, které se do hry nebalí; `PlayerVisual` (dítě Playeru) volí animaci podle `motor_state.on_floor`, rychlosti a `is_firing()`, otáčí zbraň za míření; vzdálení hráči dostávají rychlost, `on_floor` a příznak `FLAG_FIRING` ze snapshotu (protokol 13); bez sprite sheetu se kreslí původní obdélník |
| `tools/art/generate_world.py`, `src/arenas/arena_background.gd`, `assets/ui/theme.tres` | grafika světa: `Platform` kreslí dlaždice (kámen / dřevěný trám, ×2, `color` = tónování); `ArenaBackground` (CanvasLayer −10, uzel `Background` v každé aréně i v menu/lobby/výsledcích, volitelné ztmavení `dim`) roztáhne pozadí a posouvá mraky; globální UI téma v `project.godot` `gui/theme/custom` (tlačítka, pole, panely, obrys všech Labelů) |
| `src/ui/kill_popup.gd`, `src/ui/match_hud.gd` | „KILL!“ jako dítě Playeru, který zabil (vyskočí, stoupá, mizí; host i klienti z `kill_announced`); HUD: scoreboard `PanelContainer` → `GridContainer` (ikona hlavy z `sprite_sheet`, jméno, životy, zabití, smrti), odpočet, zbraň/schopnost, ping/FPS; písmo hry Jersey 15 (`project.godot` `gui/theme/custom_font`, import bez vyhlazování) |
| `src/player/ability_fx.gd`, `tools/art/generate_effects.py`, `assets/sprites/effects/` | pixel efekty schopností: `PlayerVisual` při náběžné hraně `ability_active` přidá jednorázový efekt (prstenec ve velikosti dosahu vlny, stopa úskoku a kouř přesunu zůstanou ve světě) a po dobu štítu ukazuje bublinu; `SlowCloud` kreslí pás z animovaných obláčků |
| `src/net/net_log.gd`, `src/net/connection_log.gd`, `src/net/diag_log.gd` | diagnostika do `user://logs/godot.log` (každý řádek s časem, bez IP a jmen – `DiagLog.mask`): `[sys]` informace o počítači a buildu při startu; `[conn]` připojování (druh adresy, handshake, odmítnutí s důvodem, doba připojení, odpojení s délkou, fáze); `[net]` každých 5 s zápasu – klient: ping, ENet RTT/rozptyl/ztráta/throttle, snapshoty (počet, zahozené, mezery), korekce, FPS, záseky; host: FPS, záseky a na slot ENet + fronta, přijaté vstupy, hladové ticky, výpadky, přeskočené vstupy (`InputBuffer.take_stats`); okamžitý řádek při mezeře snapshotů > 250 ms; tlačítko menu „Složka s logy“; návod `docs/PLAYTEST.md` |
| `src/net/lobby_validator.gd` | kontrola dat lobby/průběhu zápasu od hostitele na klientech (hráči, sloty, výsledky) a čištění jmen; neplatná data se zahodí |
| `src/net/lag_simulator.gd` | jen pro vývoj: simulace zpoždění a ztrát paketů (`-- --fake-lag=100 --fake-loss=5`) |
| `src/net/net_codec.gd` | binární protokol 5: vstup 14 B, snapshot 6 B + 33 B na hráče včetně stavu motoru a počtů zabití/smrtí; kontrola velikosti, slotů a konečných hodnot, `seq_newer()` |
| `src/ui/main_menu.gd/.tscn` | hlavní menu: jméno, trénink, Hostovat, adresa + Připojit, offline dialog „Co je nového“, chybové hlášky (`Session.last_end_message`) |
| `src/ui/match_hud.gd` | scoreboard vedle jmen: životy, zabití, smrti; odpočet a hlášky KILL / DOUBLE / TRIPLE / MULTI KILL; v tréninku nekonečné životy; vlevo dole malým písmem FPS a ping (jen klient), F3 skryje/zobrazí |
| `src/ui/results.gd/.tscn` | výsledky po zápase včetně zabití/smrtí, návrat do stejného lobby (tlačítko hostitele nebo za 8 s) |
| `src/ui/lobby.gd/.tscn` | lobby: seznam hráčů, u hostitele adresy ke sdílení s tlačítkem Kopírovat, Odejít |
| `src/autoload/settings.gd` | **autoload `Settings`**: jméno a poslední adresa v `user://settings.cfg` |
| `src/autoload/session.gd` | **autoload `Session`**: hostování a připojení, handshake verze, seznam hráčů v lobby (rozesílá host), odpojení a timeouty, české chybové hlášky přes signál `ended(message)` |
| `src/net/connectors/connector.gd` | rozhraní způsobu připojení: `host(port)` a `join(info)` vrací `MultiplayerPeer` |
| `src/net/connectors/enet_direct_connector.gd` | přímé UDP spojení (ENet) přes IP:port, rozbor adresy (IPv4, IPv6, hostname), timeouty peerů, `share_addresses()` (jen Tailscale a LAN, Tailscale se pozná podle rozhraní) |
| `src/net/handshake.gd` | `Handshake`: zprávy handshaku (sestavení, dekódování s limitem velikosti, kontrola verze a kódu hry), generování kódu hry |
| `tests/` | vlastní mini test runner (`run_tests.gd`, `TestCase`) |
| `tools/` | `setup_env.sh` + `godot` (připnutý engine), `check_localization.gd`, `write_build_info.gd` (verze projektu + identita sestavení), `write_release_notes.gd`, `publish_release.sh` (aktualizace jediného vydání) |

## Changelog a vydávání

- Texty změn jsou jen v `localization/translations.csv`, metadata a pořadí v `data/changelog.tres`. `build = 0` označuje aktuální zdrojový strom a při zobrazení/generování převezme skutečnou verzi a build. Před další změnou se aktuální záznam archivuje pod již publikovaným buildem a založí se nový.
- Menu zobrazí aktuální a dostupné starší záznamy, nejnovější první. `tools/write_release_notes.gd` po vytvoření `build_info.json` zapíše stejné nejnovější změny a dosavadní instrukce ke stažení do `notes.md`.
- Verze pochází z `application/config/version` v `project.godot`: nyní `0.1.1`, příště `0.1.2`. Před novým vydáním se mění výslovně; nesouvisí s počtem commitů. Samostatné číslo sestavení dál roste podle počtu commitů na main a hlídá pořadí aktualizací.
- CI po pushi na main aktualizuje jediné existující vydání s interním tagem `dev`, názvem `gun_game vX.Y.Z` a příznakem stable/latest. Nevytváří vydání ani neposouvá tagy. Původní `v0.1.0` převede na koncept až po úspěšné publikaci a ověření nového vydání.
- Adresy `releases/download/dev/*` zůstávají funkční pro staré klienty; `releases/latest/download/*` vede na stejné vydání. Nové sestavení má kanál stable, takže starý dev klient po aktualizaci přejde na latest. Aktualizátor ani síťový protokol se nemění.
- Před publikací se ověřuje následující patch/minor/major i vyšší build, případně opakování stejné dvojice. Přeskakování verzí je zakázané. Soubory hry se nahrávají před `version.json`; souběžné publikace jsou zakázané. Pevný historický tag není zdrojem aktuálního sestavení: poznámky odkazují na jeho skutečný commit.

## Handshake (kontrola verze)
1. Klient se připojí. Než se stane plnohodnotným peerem, pošle přes **autentizaci SceneMultiplayer** (surová data, ne RPC) zprávu `{protocol, build, code, name}`.
2. Host ji ověří: `PROTOCOL_VERSION`, `build_id` a kód hry musí sedět, lobby nesmí být plné a nesmí běžet zápas.
3. **Shoda:** host odpoví `{ok: true}` a oba zavolají `complete_auth`. Teprve pak vznikne `peer_connected` a mohou chodit RPC. Host rozešle seznam hráčů.
4. **Neshoda:** host pošle důvod a svůj build, za 0,5 s klienta odpojí a klient zobrazí českou hlášku.

RPC se v Godotu párují podle indexu metody, proto by RPC handshake mezi různými buildy nebyl spolehlivý.

## Pohyb a reconciliation (M4)

1. Klient v každém fyzikálním ticku (60 Hz) jednou načte vstup. Stejný vstup použije pro vlastní pohyb i paket hostu; paket opakuje poslední tři vstupy proti ztrátám.
2. Host aplikuje nejvýše jeden vstup hráče za tick, při výpadku opakuje poslední. Snapshoty (30 Hz) nesou `last_seq`, pozici, rychlost, příznaky a stav motoru: kontakt se zemí, předchozí tlačítka, zbývající skoky a časovače bufferu/seskoku. Během odpočtu zachovává `seq`, ale dovolí jen míření.
3. Klient zahodí staré/duplicitní snapshoty podle ticku a nejnovější uloží do fronty. **Reconciliation běží až na začátku dalšího `_physics_process()`**, před novým vstupem. `move_and_slide()` tak při přehrávání používá fyzikální delta.
4. Pro vlastní postavu klient obnoví úplný stav hosta, odstraní potvrzené vstupy a zbytek přehraje sdíleným motorem. Novější snapshot zpracuje i při stejném `last_seq`, protože host mohl opakovat poslední vstup. Malé rozdíly vyhladí jen vizuálně; kolize používají opravenou pozici.
5. Predikce čeká na první snapshot a neběží pro neaktivní postavu. Změna životů/aktivity nebo neúplná historie zahodí předchozí přehrávání. Knockback, zpětný ráz, respawn, životy a nezranitelnost přicházejí z hosta. Vzdálené postavy dál interpolují se zpožděním 100 ms.

Další práce v M4: dokončit měření a RTT v debug overlay, zhodnotit korekce při ztrátách a skutečném připojení podle zpětné vazby hráčů. Uživatel nahlásil sekání klientů na stejné Wi-Fi; další měření/oprava a ruční Windows testy zůstávají odložené podle PROGRESS.md a PLAN.md M4.1.

## Skóre a hlášky zabití

- Každý autoritativní projektil si pamatuje `shooter_peer_id`. Účinný zásah zaznamená host přes `WeaponSystem.player_hit`; nezranitelnost zásah nepřipíše.
- Každý pád zvýší počet smrtí. Zabití dostane poslední účinný střelec v daném životě, bez časového limitu mezi zásahem a smrtí. Pád bez zásahu nikomu zabití nepřidá; odpojený střelec kredit nemá. Počty přetrvají respawn, další zápas začíná od nuly.
- Skóre se doručuje ve snapshotech, takže pozdě načtený klient dostane aktuální součty. Hlášky killů se posílají samostatně spolehlivou autoritativní událostí; zabití stejného střelce do 2 s zvýší sérii na double/triple/multi kill. Výsledky obsahují stejné součty.
- Nahlášené sekání klientů na stejné Wi-Fi se nyní neopravuje; postup měření a budoucí opravy je v PLAN.md M4.1.

## Bezpečnost (PLAN.md, sekce S)
- Handshake vyžaduje **kód hry** (6 znaků z kryptograficky bezpečného generátoru). Ten se sdílí jako součást adresy `ip:port#KÓD`.
- `server_relay = false`: klienti mohou posílat RPC jen hostiteli.
- `allow_object_decoding` zůstává `false`. Zprávy handshaku jsou omezené na 512 B a dekódují se bez objektů.
- Hra neotevírá žádné porty v routeru a nesdílí veřejnou IP. Internet jde přes Tailscale, lobby nabízí jen Tailscale a LAN adresy.

## Plánovaný průběh (PLAN.md, sekce T)
- **Smyčka:** lobby → zápas → výsledky → **zpět do stejného lobby**. Session se nezavírá, nové hostování není potřeba.
- **V lobby:** každý hráč si vybírá postavu (host ji ověří), hostitel vybírá mapu.
- **Hotovo (M3):** výsledky a návrat do lobby. **Zatím neimplementováno:** výběr postavy (M5), výběr mapy (M6).

## Kolizní vrstvy
1 `world` (pevné plošiny) · 2 `platform_oneway` · 3 `players` · 4 `projectiles` (od M3)

## Autoloady
- `Settings` (nastavení, načítá se jako první)
- `Session` (síťová session musí přežít přechody mezi scénami)
