# Stav projektu

## Kde jsme skončili
**Verze 0.2.16 rozpracovaná – balanc, 6 hráčů, lobby, mapa Hobitín, Nazgûl (Claude, 2026-11-13), NIC NEPUSHOVAT bez souhlasu uživatele.** Uživatel zadal 6 kroků; po každém se ptát, jestli pokračovat. Commity jen lokálně.
- **Uživatel 2026-11-13: ve finálním „Co je nového“ 0.2.16 musí být VŠECHNY změny ze všech kroků** (průběžně se skládají do záznamu build 0 v `data/changelog.tres`, nic nevynechat).
- Kroky (uživatel přidal po kroku 1 menší tabulky, teď 7): **1/7 balanc ✅** · **2/7 menší tabulky hráčů v FFA ✅** · **3/7 oprava teleportu Stína ✅** · **4/7 až 6 hráčů + týmy (2 týmy max 3v3 / 3 týmy po 2) ✅** · **5/7 lobby ✅** (menší karty postav, rámeček „Hráči v lobby (x/6)“, mapa vlevo + režim vpravo, bez tlačítka Ovládání v menu) · **6/7 velká mapa Hobitín s pohyblivými plošinami ✅** · 7/7 Nazgûl (nápis + postava s mečem, odhodí hráče se 4+ zabitími na jeho stranu, animace).
- **Rozhodnutí uživatele 2026-11-13:** na Hobitíně většina plošin pohyblivá, ale ne všechny; Nazgûl od **4 zabití včetně**, **jen na Hobitíně**.
- **Krok 6 hotový:** mapa Hobitín (`arena_hobbiton.tscn`, `hobbiton.tres`, `ARENA_HOBBITON_NAME`): zoom 0,5, 4 pevné plošiny (2 travnaté kopce se spawny 0–3 až pod okraj obrazovky, 2 střední dřevěné se spawny 4–6) a 8 pohyblivých (přívoz nad smrtící propastí, 2 výtahy, 2 houpačky, 2 svislé, dlouhá nahoře; max. 118 px/s). `MovingPlatform` (poloha z ticku hostitele), `Arena.prepare` (nesení hráče v `Player.simulate`: vodorovně o pohyb plošiny, chodidla na horní hranu), `InputFrame.tick` (lokální), `Player.world_tick`, `MatchClient.tick_for` + `ClientPrediction.reconcile(..., tick_for)`. Oprava v `PlayerMotor.step`: po rewindu `apply_floor_snap` (vnitřní „na zemi“ těla se snapshotem neobnovuje → replay ztratil na tik podlahu; na pohyblivé plošině = korekce 13 px). Grafika (`generate_world.py`): `turf_top/turf_fill.png`, `hobbiton.png` (kopce, kulaté dveře a okna, komíny s kouřem, ploty, cesta, květiny, strom), `Platform.turf`. Původní obrázky generátor nezměnil.
- **Krok 5 hotový:** `lobby.tscn` přestavěno (sloupec 1080 px): nahoře řádek Mapa (vlevo) | Režim (vpravo), pod ním tlačítka týmů, uprostřed vlevo rámeček (PanelContainer) „Hráči v lobby (x/6)“ – jména v barvě týmu, dlouhé řádky se zkrátí „…“ (celé v tooltipu) – a vpravo menší karty postav (3 × 2, výška 72 px místo 96, písmo 14, náhled horní půlky postavy 2×) s tlačítkem Potvrdit; dole adresy (jen host), stav a tlačítka Začít / Odejít vedle sebe. Se 6 hráči a 3 týmy se vše vejde na 1280 × 720 bez posouvání (scroll zůstává pro menší okna). Hlavní menu: tlačítko Ovládání a jeho dialog odebrány (klávesy dál v Nastavení), 13 nepoužitých klíčů `CONTROLS_*`/`MENU_CONTROLS` z CSV smazáno.
- **Krok 4 hotový:** `LobbyValidator.MAX_PLAYERS` 6 (lobby, výsledky, sloty 0–5), ENet `MAX_CLIENTS` = 6 (5 klientů + 1 rezerva pro hlášku „Hra je plná“ – dřív 4 a pátý klient se tiše nepřipojil), `NetCodec.MAX_SNAPSHOT_PLAYERS` = 6, `PROTOCOL_VERSION` 24. `Session.team_mode` (bool) → `Session.team_count` (0 / 2 / 3, `Teams.MODES`), `TeamChoice.set_team_count` (hráči z neexistujícího týmu jdou do nejmenšího), `Teams.max_per_team` (3 / 2), `ready_to_start`, `start_slots` (`START_SLOTS`), Zelený tým, `MatchRanking` řadí týmy podle toho, kdo vydržel déle; HUD: zelená tabulka nahoře uprostřed; lobby: výběr 3 režimů + 3 tlačítka týmů (rozvržení až krok 5 – se 6 hráči lobby přetéká a posouvá se); 2 nové barvy slotů; spawny všech 4 map v pořadí vlevo, vpravo, vlevo, vpravo, střed-vlevo, střed-vpravo (Visuté mosty přeskládány, Peklo +2 na střední plošině). Klient posílá vstupy až po prvním snapshotu (méně „Node not found“ na hostu při startu). Test runner: soubor s chybou parsování = selhání, ne zaseknutí.
- **Krok 3 hotový:** příčiny – (a) `move_and_collide` celé dráhy proti světu, proskakovacím plošinám i hráčům: při míření i jen mírně dolů ze země kolize hned na 0 px, hráč v cestě zastavil přesun; (b) cooldown schopnosti se v plovoucí čárce mohl na hostu a v predikci klienta lišit o 1 tik → stisk přesně na konci cooldownu klient předpověděl, host odmítl, Stín skočil zpět. Oprava: `TeleportAbility.destination` – `test_move` jen proti pevným blokům (vrstva world), po kolizi klouže zbytek dráhy po povrchu (max. 4×), proskakovací plošiny a hráči neblokují; `Player.tick_ability` počítá cooldown v celých ticích. Test runner umí `await` (`TestCase.physics_step()`).
- **Krok 2 hotový:** tabulka FFA (i v tréninku) používá kompaktní velikosti jako týmové (písmo 15, ikona 20 px, jméno 110 px, sloupce 38 px); `ScoreTable` má už jen jednu velikost (parametr `compact` zrušen), panely skóre mají menší vnitřní okraj (8 × 5 px místo 16 × 12, `MatchHud.SCORE_PANEL_MARGIN`, platí i pro týmové). Screenshot 1280 × 720 se 4 hráči: tabulka ~ 22 % šířky × 13 % výšky (dřív ~ 40 % × 24 %).
- **Krok 1 hotový:** Balvan – těžký kulomet 75 nábojů, přebíjení 2 s, rozptyl ±1° jen vestoje; při držení A/D/W/S (`InputFrame.is_moving`, nové `WeaponData.move_spread_degrees` = 30) i ve vzduchu (`air_spread_degrees` 15 → 30) ±30°. Rozptyl dál z (slot, seq, broku) + vstupu → predikce = host. Krügermann – `blow_delay` 0,2 → 1,0 s, `lifetime` 3 → 5 s, vyprchání 0,5 → 1,5 s (`GasCloud.FADE_TIME`). Stín – odstřelovačka `knockback` 1300 → 2600; `CombatRules.MAX_KNOCKBACK_PER_SHOT` 1400 → 2600 (výslovný pokyn uživatele). Changelog: 0.2.15 archivována jako build 67 (ověřeno z `version.json`), nový build 0 (`CHANGELOG_BALVAN_0216`, `CHANGELOG_GAS_0216`, `CHANGELOG_STIN_KNOCKBACK`). Verze 0.2.16.

**Verze 0.2.15 – plyn odfoukne až po 0,2 s a slaběji; úklid složky projektu (Claude, 2026-11-09).** Uživatel: „plyn odhodí po 0,2 s pohybu v něm a trochu zmenší odhození. Složka gun_game má přes 2 GB, hra ~180 MB – odstraň nepotřebné soubory nebo vysvětli.“
- **Plyn:** `blow_delay` 0,2 s (= 12 ticků v kuse, `Player.gas_ticks`, vynulování po opuštění plynu, respawnu a při nezranitelnosti), `blow_speed` 1500 → 1250, `blow_lift` 450 → 380. `gas_ticks` jde ve snapshotu (46 B/hráč, **protokol 23**), takže si oběť odfouknutí predikuje sama: korekce klienta při odfouknutí 128–165 px → ≤ 10 px.
- **Úklid (2,1 GB → 378 MB):** smazány `build/` (414 MB, staré lokální exporty z ~0.2.6), `.tools/Godot_v4.7.2-stable_export_templates.tpz` (1,2 GB) a `.tools/Godot_v4.7.2-stable_macos.universal.zip` (177 MB) – jen stažené archivy, rozbalený Godot (`.tools/godot`, 344 MB) i nainstalované šablony zůstaly; `.pytest_cache`, `tests/__pycache__`. Mimo projekt zůstávají šablony exportu `~/Library/Application Support/Godot/export_templates/4.7.2.stable` (1,9 GB, jen pro lokální export – vydání staví CI). `tools/setup_env.sh` by archivy při novém spuštění znovu stáhl.
- `project.godot` přepsal editor Godotu (2026-11-09 21:40, rozepsané vstupy, vypuštěné výchozí hodnoty) – obsahově stejné (ověřeno: fyzika 60 Hz, logování vypnuté, akce reload), commitnuto v tomto tvaru.
- Changelog: 0.2.14 archivována jako build 66 (ověřeno z `version.json`), nový build 0 (`CHANGELOG_GAS_DELAY`). Verze 0.2.15.

**Verze 0.2.14 – nová mapa Peklo se stoupající lávou (Claude, 2026-11-09).** Uživatel: „nová mapa peklo: žádná fixní plošina, všude proskakovací, nahoře jedna velmi dlouhá, pod ní menší. Jakmile má někdo jen 3 životy, začne odspodu stoupat láva; kdo do ní spadne, hned přijde o život. Stoupá až těsně pod nejvyšší plošinu. Ošetři respawn, ať se hráč neoživí v lávě. Kde najdu názvy map?“
- `src/arenas/arena_hell.tscn` + `data/arenas/hell.tres` (`ARENA_HELL_NAME` = Peklo): horní most 1100 px (y 250) a 7 menších proskakovacích plošin, teplý odstín dřeva; 4 spawny dole + 3 na mostě.
- `src/arenas/lava.gd` (`Lava`): od začátku dole (y 880) a zabíjí hned; stoupá 14 px/s (~42 s), když má kdokoli 3 životy (trénink: 2 smrti), do `top_y` 290 (24 px pod mostem). Host posílá hladinu ve snapshotu (hlavička 8 B, **protokol 22**), klient ji jen ukazuje. HUD „Láva stoupá!“ (`MatchHud.show_alert`). Respawn: `Arena.free_spawn_point(occupied, Lava.safe_feet_y())` – při stoupání jen spawny nad konečnou hladinou.
- Grafika: `generate_world.py` → `assets/backgrounds/hell.png` (sopka, spálená torii, jiskry), `assets/sprites/tiles/lava_surface.png` (4 snímky vlny) a `lava_fill.png`.
- Názvy map: `localization/translations.csv` (`ARENA_*_NAME`), data `data/arenas/*.tres`, rozložení `src/arenas/arena_*.tscn` – tabulka v `docs/EDITING_GUIDE.md`.
- Changelog: 0.2.13 archivována jako build 65 (ověřeno z `version.json`), nový build 0 (`CHANGELOG_HELL_MAP`). Verze 0.2.14.

**Verze 0.2.13 – rework Krügermanna (odfukovací plyn) a Balvana (střelba za štítem, těžký kulomet) (Claude, 2026-11-09).** Uživatel: „místo zpomalovacího plynu bude plyn odfoukávat pryč (OP – vstoupení do plynu soupeře odfoukne ihned), nech jej zelený, ale naznač, jakým směrem odfoukává. Balvan ať může během štítu střílet a dej mu zbraň typu negev – 100 nábojů, dobrý knockback, přesná jen na zemi, ve skoku/ve vzduchu velký rozptyl.“
- **Plyn:** `slow_cloud` → `gas_blast` (`GasBlastAbility`, `GasCloud`, `git mv`). `AreaEffects.blow` v `Player.simulate` (host i predikce oběti): kdo se tělem dotkne pásu, dostane hned `blow_speed` 1500 px/s směrem od Krügermanna + `blow_lift` 450 nahoru (dělí se váhou, štít × 0,2, nastavuje se – nesčítá; majitel, spoluhráči a čerstvě respawnutí imunní). Host připíše pád Krügermannovi (`player_blown` → `MatchScore`). Zpomalení z `PlayerMotor` odstraněno. Zpráva o efektu nese směr → **protokol 21**. Vizuál: zelené obláčky + nový pixelový sprite šipky `gas_arrow.png` (generate_effects.py), šipky plují směrem odfouknutí.
- **Balvan:** `ShieldAbility` už nezakazuje střelbu. Nová zbraň `heavy_machine_gun` (Těžký kulomet: 10 ran/s, odhoz 700, 100 nábojů, rozptyl 1° na zemi / 15° ve vzduchu – nové pole `WeaponData.air_spread_degrees`, `CombatRules.spread_degrees`), sprite v `generate_sprites.py` (krabice s náboji, děrovaný plášť hlavně, dvojnožka). Útočná puška zůstává v datech nepoužitá.
- **Rozptyl shodný s hostitelem:** `WeaponSystem._shot_direction` losuje z (slot, seq vstupu, broky) → predikovaná kulka letí stejně jako skutečná (dřív náhoda zvlášť na obou stranách).
- **Oprava:** `WeaponSystem._on_remote_spawned` hlásil „Trying to assign invalid previously freed instance“, když vlastní predikovaná kulka už narazila (stará chyba, plnila logy).
- Changelog: 0.2.12 archivována jako build 64 (ověřeno z `version.json`), nový build 0. Verze 0.2.13.

**Verze 0.2.12 – jen WASD, přebití na Q, schopnost po smrti připravená, chodící cvičný panák (Claude, 2026-11-09).** Uživatel: „odstraň ovládání pomocí mezerníku a šipek – pouze wasd. přidej na Q reload když je zbraň nevystřílená. Přidej, že při smrti se cooldown na abilitce [resetuje]. A do tréninku přidej, že se cviční panák pohybuje… střílet nemusí a hlavně ať sám nepadá.“ (Věta o schopnosti byla useknutá – vyloženo jako „po smrti je schopnost hned připravená“; pokud uživatel myslel opak, změnit jeden řádek v `Player.reset_to`.)
- **Jen WASD:** `project.godot` bez mezerníku a šipek. Settings ukládal všechna přiřazení, proto `KeyBindings.VERSION` 2 + `[meta] controls_version` v `settings.cfg`: uložení verze 1 přijdou o mezerník a šipky (ověřeno na skutečném `settings.cfg` z 0.2.11). Výchozí klávesa nové akce nevezme klávesu, kterou hráč používá jinde.
- **Přebití na Q:** akce `reload`, `InputFrame.RELOAD` (bit 16), `PlayerWeapon.tick(wants_to_fire, wants_reload, delta)` → `can_reload()`/`start_reload()` jen když zásobník není plný a nic se nepřebíjí; náboje zůstávají do konce přebíjení, pak plný zásobník. Běží v `simulate()` → klient predikuje, host potvrzuje. **Protokol 20.** Nápověda Ovládání, Nastavení (řádek Přebití), README.
- **Schopnost po smrti:** `Player.reset_to` nuluje `ability_cooldown` (snapshot ho nese, klienti to vidí).
- **Cvičný panák:** `src/match/practice_dummy.gd` (`PracticeDummy`), `MatchController._inputs_for` – chodí 0,8–2,4 s, stojí 0,5–1,5 s, na místě občas skočí; paprsky 72 px před sebou hledají podlahu (i dřevěnou) a zeď/hráče, jinak se otočí; ve vzduchu neřídí; nestřílí.
- Changelog: 0.2.11 archivována jako build 63 (ověřeno z `version.json`), nový build 0 (`CHANGELOG_MANUAL_RELOAD`, `CHANGELOG_ABILITY_RESET`, `CHANGELOG_WASD_ONLY`, `CHANGELOG_MOVING_DUMMY`). Verze 0.2.12.

**Verze 0.2.11 – rozdělení velkých skriptů, oprava volné paměti v logu, `__pycache__` v .gitignore (Claude, 2026-11-08).** Uživatel: „udělej body 1, 2, 3 všechny“ (1 = rozdělit skripty nad ~300 řádků, 2 = `sys_free`, 3 = `.gitignore`). Chování hry se nemění, protokol zůstává 19.
- **`player.gd` 406 → 270 řádků:** nové `src/player/player_weapon.gd` (`PlayerWeapon` = `player.gun`: kadence, náboje, přebíjení, `count_down`, `show_state`), `src/player/remote_view.gd` (`RemoteView` = `player.remote_view`: přehrávání hráčů z jiných počítačů na `SnapshotTimeline`; nahrazuje `Player.timeline/_interpolator/_display`), `src/player/player_labels.gd` (`PlayerLabels`: jméno + procenta). `Player.tick_weapon` zůstává (přidává zpětný ráz).
- **`match_controller.gd` 354 → 285:** klientská část v `src/match/match_client.gd` (`MatchClient`: `physics_tick` = reconcile + predikce + odeslání vstupu, `receive_snapshot`, `interpolation_text`, `stats`).
- **`session.gd` 337 → 268:** handshake v `src/net/session_auth.gd` (`SessionAuth`, uzel `/root/Session/SessionAuth`; sám poslouchá `peer_authentication_failed`/`peer_disconnected` pro čekající peery).
- **`sys_free`:** ověřeno ve zdrojích Godot 4.7.2 – `available` na všech systémech přičítá swap / stránkovací soubor (Windows = commit limit), oprava v 0.2.10 to řešila jen při zapnutém stránkovacím souboru. Nově vždy `free` (`NetLog.free_ram_mb`, test).
- **Verze 0.2.11**, changelog: 0.2.10 archivována jako build 62 (ověřeno z `version.json`), nový build 0 (`CHANGELOG_DIAG_MEMORY_0211`, `CHANGELOG_CODE_0211`).

**Verze 0.2.10 – co nejnižší ping, plynulí ostatní hráči, procenta poškození (Claude, 2026-11-05).** Uživatel: „fixni ten ping, 180 je skoro nehratelných“; „chci aby ping byl co nejmenší… čím více zásahů, tím víc knockback, nad postavy procenta (100 % = nejvyšší knockback)… prozkoumej další cesty, aby se to ostatním nesekalo s velkou odezvou“.
- **Rozbor pingu 0.2.9 (~175 ms při RTT ~60):** zásoba vstupů na hostu 50–80 ms, čekání na snapshot (30 Hz) 0–33 ms, odeslání až v dalším snímku hostitele 0–16 ms, měření až v dalším ticku klienta 0–16 ms.
- **Opravy:** host simuluje vstup hned a právě jednou (`InputBuffer.take_for_tick`: čeká místo hádání, dohání až 4/tick, nic nezahazuje → predikce klienta bez korekcí), `EnetDirectConnector.flush` po každém odeslání, snapshoty 60 Hz, ack ping při příchodu, vzdálení hráči dostávají každý snapshot (i ze shluku).
- **Plynulost pro ostatní:** `SnapshotTimeline` pro každého vzdáleného hráče – hráči klientů se přehrávají podle **sekvence vlastních vstupů** (dohánění na hostu ani shluky jejich Wi-Fi se neprojeví), krátké mezery se dopočítají (≤ 100 ms), zpoždění zobrazení 40–200 ms (nižší než v 0.2.9 – lépe se trefuje). Host kreslí hráče klientů stejně (`Player._display`), zásahy podle skutečné polohy. Kulky z dohnaných vstupů se posunou o zmeškané ticky.
- **Okamžitá střelba:** klient ukáže vlastní kulky hned (`WeaponSystem.spawn_predicted`), host je potvrdí (RPC nese slot střelce, párování v pořadí).
- **Procenta poškození (PLAN.md T.6):** `WeaponData.damage` / `ShockwaveAbility.damage`, `Player.take_hit`, `CombatRules.damage_multiplier` 1,0–2,5 při 0–100 %, štít škáluje obojí, snapshot u8, štítek „37 %“ nad jménem (bílá → žlutá → červená), reset po respawnu; nápověda Ovládání.
- **Vývoj:** `--fake-burst=MS` v `LagSimulator`. Protokol **19** (snapshot 45 B/hráč, 60 Hz, RPC výstřelu se slotem), verze 0.2.10, 0.2.9 archivována jako build 60.

**Verze 0.2.9 – plynulejší online hra podle analýzy logů (Claude, 2026-11-05).** Uživatel: „oprav a zlepši připojení, ať kamarád má plynulejší hru.“
- **Ověřeno ve zdroji Godot 4.7** (`modules/enet/enet_multiplayer_peer.cpp`): `reliable` jde kanálem 0 a `unreliable_ordered` kanálem 1 → hypotéza o blokování snapshotů spolehlivými zprávami **neplatí**, nic se neměnilo.
- **Plynulost vzdálených hráčů:** `src/net/jitter_clock.gd` + `src/net/snapshot_timeline.gd`: přehrávání podle ticku hostitele místo času doručení, zpoždění 50–250 ms podle 90. percentilu kolísání (dřív pevně 100 ms podle doručení → při shlucích zamrzání).
- **ENet throttle vypnutý** v konektoru (host při připojení klienta, klient po navázání spojení).
- **Predikce zpětného rázu:** `Player.tick_weapon` v `simulate()` (cooldown, náboje, přebíjení, ráz) na hostu i v predikci; host jen `WeaponSystem.spawn_shot`. Snapshot nese přesné časovače (u16 po 0,1 ms) → **protokol 18, 44 B/hráč**; časovače na stejné mřížce (`Player._count_down`).
- **Adaptivní fronta vstupů:** `InputBuffer.target` 1–6 podle kolísání příchodu vstupů (dohánění jen nad cílem, strop target+4).
- **Diagnostika:** přesné milisekundy (unixový čas + časové pásmo), `sys_free` místo `mem=0` v release, klient `interp_delay`/`jitter`, host na slot `target`/`jitter`.
- Changelog: 0.2.8 archivována jako build 56, nový build 0 (bugfixy + ostatní).

**Verze 0.2.8 hotová (Claude, 2026-11-05).** Zadání uživatele: menší scoreboard ve 2v2; logy vždy jen z poslední hry (jeden soubor, Windows i Mac) s diagnostikou hry, připojení, Tailscale a odezvy; rychlejší střely Stína; „Co je nového“ po sekcích (mechaniky a updaty postav / bugfixy / ostatní); přebíjení po zásobníku (1 s, velikost podle zbraně, reset po smrti, animace); nastavení s bindováním pohybu a střelby, nápověda v menu (tlačítko Ovládání) a ne ve hře; nové horní patro na Střechách; prvky map do plánu; pushnout.
- **Přebíjení:** `WeaponData.magazine_size` / `reload_time` (odstřelovačka 3, brokovnice 2, bojová puška 10, útočná 24, samopal 32, kulomet 45 …; všechny 1 s). Host počítá náboje, respawn doplní. Snapshot nese náboje + `FLAG_RELOADING` (40 B/hráč, **protokol 17**). Animace: zbraň se skloní, vypadne pixelový zásobník (`magazine_drop.gd`), ukazatel nad hlavou; HUD „zbraň · 17/24“ / „přebíjení…“.
- **Stín:** odstřelovačka `projectile_speed` 2400 → 3600.
- **Scoreboard 2v2:** kompaktní `ScoreTable` (písmo 15, ikony 20 px, užší sloupce) – asi poloviční plocha.
- **Ovládání:** `src/core/key_bindings.gd` (2 vstupy na akci, fyzické klávesy, Esc/F3 vyhrazené, jeden vstup jen u jedné akce, uloženo v `settings.cfg [controls]`), obrazovka `src/ui/settings_screen.tscn` (+ výchozí ovládání, složka s logem). Menu: řádek Ovládání | Nastavení | Co je nového. Ve hře už žádná nápověda (HintLabel jen pro debug lag). Výchozí skok bez šipky nahoru (max. 2 vstupy na akci).
- **Logy:** vestavěný `godot.log` vypnut, staré `godot*.log` se při startu mažou; jediný `user://logs/last_game.log` (`DiagFileLogger`, Godot `Logger`) – přepíše se při hostování/připojení, limit 4 MB, zachytí i chyby enginu. Nově: síť/Tailscale (bez IP), stejná podsíť, nápověda při vypnutém Tailscale, ping v lobby, sloty/postavy, pády a zabití, provoz kB/s, podtečení interpolace, paměť/uzly/draw calls, fokus okna. Návod `docs/PLAYTEST.md` přepsán.
- **Changelog:** `mechanics_keys` / `fix_keys` / `other_keys`; 0.2.7 archivována jako build 55 (ověřeno z `version.json`), nový build 0.
- **Střechy:** `HighLeftBlock`, `HighRightBlock` (kámen, y 170) a `HighCenter` (dřevo, y 110).
- **PLAN.md T.5:** padající bomby, stoupající láva a další prvky map (jen plán).

**Verze 0.2.7 hotová (Claude, 2026-11-05):** čitelné písmo, potvrzování postavy s náhledy, mapa v pozadí lobby a diagnostické logy pro hraní s kamarádem jako hostitelem. Uživatel: „podívej se, jak se zobrazují čísla a velká písmena… připrav diagnostické logy pro hraní (hostovat bude kamarád)… postavu musíš potvrdit, do obdélníků dej náhledy postav… při výběru mapy mapu do pozadí. Všechno commitni.“
- **Písmo:** Pixelify Sans má 5≈S, 2≈Z, 8≈B a 0 = O (ověřeno na obrysech glyfů, vyhlazení nepomáhá). Uživatel zvolil jiné pixelové písmo → **Jersey 15** (OFL, Google Fonts, kompletní čeština), bez vyhlazování; Pixelify Sans odstraněno.
- **Postavy v lobby:** karty s pixelovým náhledem (1. snímek spritu ×2); klik = výběr, „Potvrdit postavu“ = zabrání (`players[peer].ready`). Nepotvrzená postava nikoho neblokuje (potvrzení ji vezme a držitel dostane jinou volnou). Start až když mají všichni potvrzeno (`LOBBY_NEED_CONFIRM`). Po zápase zůstává potvrzení platné. Klient už si postavu z menu automaticky nezabírá, jen ji má předvybranou.
- **Mapa v pozadí lobby:** `src/ui/arena_preview.gd` (aréna v SubViewportu s vlastní kamerou, ztmavená), mění se s výběrem mapy u všech.
- **Diagnostika:** `src/net/{diag_log,connection_log}.gd`, rozšířený `net_log.gd`, počítadla v `input_buffer.gd`, `EnetDirectConnector.peer_stats`; tlačítko menu „Složka s logy“; `project.godot` drží 10 logů; návod **`docs/PLAYTEST.md`**. Release build zapisuje řádky do `godot.log` (ověřeno lokálním macOS exportem).
- **Verze 0.2.7**, protokol 16 (lobby má `ready`), changelog: 0.2.6 archivována jako build 54 (ověřeno z `version.json`), nový build 0.

**Režim 2 v 2 hotový a vydaný spolu s vzhledy a jetpackem jako `0.2.6` (Claude, 2026-11-05).** Uživatel: „do hostovacího lobby přidej novou možnost hry – 2v2 místo každý proti každému, hráči si vyberou týmy; ve hře má každý tým svůj scoreboard – jeden vlevo, druhý vpravo. Pak to pushni.“
- Hostitel v lobby volí „Režim: Každý proti každému / 2 v 2 (týmy)“; všichni vidí tlačítka Červený tým / Modrý tým (počet x/2). Nový hráč jde do menšího týmu; přejít se dá kamkoli (i do plného – jinak by se 4 hráči nemohli prohodit), start povolí jen 1–2 hráče v každém týmu (2v2, 2v1, 1v1), jinak hláška `LOBBY_NEED_TEAMS`.
- Ve hře: červení začínají vlevo (sloty 0, 2), modří vpravo (1, 3); jména v barvě týmu; **bez friendly fire** (střely spoluhráčem proletí, tlaková vlna ho neodhodí, plyn ho nezpomalí). Vyhrává poslední tým se životy; výsledky: „Vyhrál Červený tým!“ a celý vítězný tým na 1. místě. HUD: scoreboard Červeného týmu vlevo nahoře, Modrého vpravo nahoře; v režimu každý proti každému beze změny.
- Nové soubory: `src/match/{teams,match_ranking}.gd`, `src/net/team_choice.gd`, `src/ui/score_table.gd`, `tests/test_teams.gd`. Změny: `session.gd`, `lobby_validator.gd`, `lobby.gd`, `match_controller.gd`, `match_hud.gd` + `match.tscn`, `results.gd`, `player.gd`, `projectile.gd`, `shockwave_ability.gd`, `area_effects.gd`, CSV, changelog, dokumentace. Protokol zůstává 15 (verze 0.2.6 dosud nevydaná).

**Předchozí (Codex):** vzhled Krügermanna a Architekta podle předloh + jetpack Jiskry, níže.
**Vzhled Krügermanna a Architekta podle uživatelových předloh hotový, lokálně verze `0.2.6`, bez commitu/pushe.** Krügermann má hnědé vlasy, tmavý svetr se světlým zipem a červeným znakem; Architekt střapaté vlasy, knír, tmavý oblek, světlou košili a kravatu. Zachováno 10 snímků 32 × 40 px, samostatná zbraň, kolize, pohyb a obě schopnosti. Předchozí rozpracovaný jetpack Jiskry zachován.
- **2026-11-05 (Codex):** přečteny projektové pokyny a společně s agenty všechny projektové zdrojové, datové, testovací a dokumentační soubory; `git fetch` potvrdil `main == origin/main` (`500f0d0`). Žádný commit ani push.
- **Soubory změněné v tomto úkolu:** `assets/sprites/characters/{krugermann,architekt}.png`, `tools/art/generate_sprites.py`, nový `tools/art/reference_characters.py`, `tests/test_player_visual.gd`, `project.godot`, `data/changelog.tres`, `localization/translations.csv`, `export_presets.cfg`, `CREDITS.md`, `CLAUDE.md`, `docs/{ARCHITECTURE,EDITING_GUIDE,PROGRESS}.md`. Generátor zůstává reprodukovatelný; ostatní postavy i zbraně se proti začátku úkolu nezměnily. Staré `art_reference/*` se při lokálním exportu přibíraly do hry; všechny tři presety je nyní vylučují.
- **Již existující necommitnutá práce při zahájení:** Jiskřin jetpack místo úskoku (sprite Jiskry, `jet_flame.png` + import, `jetpack.tres`, `jetpack_ability.gd` + UID; změny `jiskra.tres`, `build_info.gd`, `ability_data.gd`, `net_codec.gd`, `ability_fx.gd`, `player.gd`, `player_motor.gd`, `player_visual.gd`, testů schopností/predikce/kodeku a generátoru efektů; odstraněný dash včetně efektu/importu a skriptu/UID). Existovaly i předchozí úpravy obou nyní přepracovaných spriteů, generátoru, CSV a vizuálních testů. Tato práce nebyla vrácena ani přestagována.
- **Verzování:** patch navýšen jednou `0.2.5 → 0.2.6`; skutečný publikovaný `version.json` i GitHub release potvrdily `0.2.5`, build `53`, stable. Tento changelog archivován jako 0.2.5/53; nový build 0 obsahuje nové vzhledy a již rozpracovaný jetpack. Nové číslo buildu není odhadováno.
- **Lokální výstupy:** `build/windows/gun_game.exe` (107,34 MiB), `build/linux/gun_game.x86_64` (73,25 MiB), náhled `build/character_preview.png`; pomocné ověřovací skripty a mezivýsledky v `/tmp/gun_game_reference_check/`. Žádné stahování enginu ani šablon. Nový macOS export nebyl spuštěn: žádost o jeho spuštění byla zamítnuta. Staré macOS výstupy nejsou ověřením 0.2.6.

**Předchozí stav 0.2.5:** pixel art postav (0.2.1), map/pozadí/menu (0.2.2), opravy z validace (0.2.3), pixelové písmo + scoreboard + „KILL!“ nad hráčem (0.2.4), efekty schopností + tlaková vlna 320 px (0.2.5).
- **Validace část 1 (2026-11-05):** připojovací chyby (špatný kód, jiná verze, plné lobby, zápas běží – správné české hlášky), 6 scénářů odpojení, 4 boti na mapách, výkon (0 pomalých snímků) – vše OK. Nezávislá kontrola kódu (agent) našla 7 problémů, všechny ověřeny a opraveny:
  1. Esc hostitele během 0,5 s po konci zápasu → všichni uvízli ve výsledcích (reprodukováno na starém kódu, opraveno: scéna podle aktuální fáze, jediné přepnutí; výsledky/lobby po načtení kontrolují fázi).
  2. Lobby po načtení nepřešlo do už běžícího zápasu → opraveno.
  3. Odmítnutý peer mohl během 0,5 s zkoušet další kódy hry → host ignoruje další hello od odmítnutých/čekajících.
  4. Hráč odpojený během načítání zápasu zůstal jako „duch“ → `_remove_departed_players()` v `_ready`.
  5. Plošina/plyn vlastníka dvakrát při dohánění fronty vstupů → párování predikce v okně 8 vstupů, nepotvrzená predikce zmizí po 1 s.
  6. Po výpadku sítě host vyhodnotil držený skok jako nový stisk → neutrální vstup drží tlačítka kromě střelby.
  7. Poskočení při „GO!“ → odpočet ve snapshotu v desetinách s, klient odhadne start pohybu podle pingu (korekce 33–47 → ~24 px při lagu 100 ms). Protokol 14.
  + Visuté mosty: boční ostrovy zarovnány s mosty (dřív kolmý schod 30 px – boti se zasekli, zápas neskončil).
- **Validace část 2:** exporty Windows/macOS/Linux bez chyb (116 / 67 / 80 MB); exportovaná macOS release hra spuštěna (Movie Maker snímky): menu kompletní, bez chyb v logu; herní kód bez OS-specifických cest (jediné větvení podle OS v aktualizátoru je záměrné). Windows/Linux exporty nespuštěny (jen sestaveny) – Windows test zůstává v odložených.
- **0.2.4:** písmo Pixelify Sans (OFL, celá čeština) bez vyhlazování v celé hře; scoreboard v panelu s ikonami hlav; „KILL!“ / „DOUBLE KILL!“ … nad hráčem, který zabil (`kill_popup.gd`); číslo verze v menu se už neuřízne.
- `session.gd` má 319 řádků (limit ~300) – přesunout handshake do `src/net/session_auth.gd` (hotovo v 0.2.11).
- **0.2.5 (uživatel: „proč nemá Krügermann pixelartovou schopnost… a ostatní postavy“; „postavě s energetickým štítem na vystřelení větší range, ať nemusí melee“):** pixelové efekty všech schopností (`ability_fx.gd`, `generate_effects.py`); dosah tlakové vlny Vichra 160 → 320 px (výklad: „energetický štít na vystřelení“ = tlaková vlna; pokud uživatel myslel Balvanův štít, upravit).
- **Před publikací:** změny 0.2.6 jsou necommitnuté, viz seznam výše. Codex necommitoval ani nepushoval. Další patch až po publikaci této verze; build stanoví CI podle skutečného commitu.

## Další krok
**Krok 7/7 (až po souhlasu uživatele): Nazgûl na Hobitíně** – jen na mapě Hobitín: jakmile má hráč **4 a víc zabití** (včetně 4), objeví se nápis „Nazgûl přichází!“ (HUD `show_alert`, CSV) a u takového hráče se jednou za rozumný interval (návrh 12–18 s, náhodně, rozhoduje host) zjeví postava v černé kápi s mečem (vlastní pixel art – `tools/art/generate_effects.py` nebo `generate_sprites.py`, animace příchodu a zmizení), sekne a odhodí hráče do strany (je-li hráč v levé polovině mapy, doleva, jinak doprava), pak zmizí. Host-autoritativní: událost (pozice, směr) přes reliable RPC v `match_net.gd` všem klientům, odhoz jako zásah (oběť ho dostane ve snapshotu). Data do `data/` (interval, síla, práh), testy, síťový test, screenshoty.

**Testovací hraní 0.2.15 s kamarádem** podle `docs/PLAYTEST.md` (oba aktualizovat, hostovat jednou každý), od obou `last_game.log`: ping, `interp_ms`, korekce, `sys_free` na Windows; ručně: WASD, Q, schopnost po respawnu, panák, Krügermannův plyn (zpoždění 0,2 s, síla 1250, šipky), Balvan za štítem a těžký kulomet (přesnost na zemi vs. ve skoku), mapa Peklo (rychlost lávy 14 px/s, jestli je zápas na mostě zábavný, čitelnost plošin).

### Play test 0.2.9 (2026-11-05 17:47–17:52, host Windows Jiskra, klient Mac Stín, Střechy FFA 271 s)
- **Host:** vstupy z Macu plynulé – po zahřátí `starved` 0–3 a `skipped` 0–1 za 5 s (0.2.8 ve stejné roli 1–7 / 1–9), `target` 3–5, `jitter` vstupů 37–68 ms; throttle stále 32/32. `sys_free=57080MB` na Windows je nesmysl (OS.get_memory_info „available“ tam zřejmě vrací virtuální paměť) – opravit nebo vypustit.
- **Klient Mac:** `interp_delay` 85–132 ms, `jitter` 34–84 ms, ale mezery > 100 ms stále 4–10× za 5 s (117–162 ms, 3 spiky 280–348 ms) → `interp_holds` 12–48 za 5 s (0.2.8: 3–38) – **nezlepšeno**. Příčina: zpoždění se řídí 90. percentilem zpoždění (~50 ms), ale první snapshot po každé mezeře mešká ~90–130 ms a takových je ~4 % → pokrýt je potřeba ~98. percentil (zpoždění ~140–150 ms).
- Korekce 0–19 za 5 s (max 67–260 px) – klient hrál Stína (1 rána / 1,25 s), korekce se kryjí s okny, kdy ho zasahoval samopal hosta → zbývající korekce jsou hlavně nepredikovaný odhoz od zásahů; ping vstupu 150–207 ms (o ~15–25 ms víc než 0.2.8 kvůli větší zásobě vstupů na hostu).
- **Návrh:** `SnapshotTimeline` percentil 0.9 → 0.98 (JitterClock s parametrem), delší vyhlazení velkých korekcí (MAX_SMOOTH_DISTANCE 200 → 320 px), opravit `sys_free` na Windows.

### Analýza prvního ostrého hraní (0.2.8, 2026-11-05, host Mac na Wi-Fi, 1 klient Windows notebook na Wi-Fi, Tailscale)
- **Počítače nejsou úzké hrdlo:** host 120 FPS, klient 60 FPS (vsync), 0 záseků, žádné chyby v logu.
- **Linka:** ENet RTT v zápase 55–65 ms (rozptyl 10–40 ms), ztráta 0,5–2 %; v lobby (málo provozu) 130–470 ms a ztráta až 3 % u obou stran současně → typicky úsporný režim Wi-Fi (rádio usíná při nízkém provozu). Připojení přes Tailscale trvalo 1,6 s.
- **Nárazové doručování v obou směrech:** klient má 4–9× za 5 s mezeru mezi snapshoty 117–168 ms (normálně 33 ms) při 0 ztracených → pakety chodí ve shlucích po ~100 ms (odpovídá Wi-Fi power save, beacon ~102 ms). Host: vstupy klienta také ve shlucích (fronta 5, starved 5–42 a skipped 5–32 za 5 s).
- **Důsledky:** vzdálený hráč u klienta zamrzá (`interp_holds`, mezery > interpolační zpoždění 100 ms); ping vstupu ~150 ms při RTT ~60 ms (host drží ve frontě ~4 vstupy); korekce vlastní postavy 1–24× za 5 s, typicky 50–130 px (nepredikovaný zpětný ráz – klient hrál Architekta s rázem 550 – a hladovění/přeskakování vstupů na hostu), jednou 334 px (pád).
- **ENet throttle (potvrzeno v obou logech, 17:04:23–29):** host snížil throttle na 18–20/32, odesílání 3,1 → 1,3 kB/s, klient dostal jen 62 ze 150 snapshotů a dvě mezery 334 a 416 ms. Oprava: `ENetPacketPeer.throttle_configure(..., deceleration 0)` v konektoru.
- **Druhé sezení (17:11–17:13, 2v2 1+1, host Stín, klient Vichr):** bez throttle výpadku (throttle 28–32, 143–153 snapshotů / 5 s, žádný spike), jinak stejné: mezery 119–149 ms 4–9× za 5 s (velmi pravidelné), ping vstupu 152–161 ms při RTT 55–85 ms, host starved ≈ skipped 4–23 za 5 s, fronta 5. Korekce 140–214 px v oknech, kdy klienta zasáhla odstřelovačka hosta (odhoz × ~150 ms zpoždění), jinak 19–56 px. RTT v lobby opět vyšší (146–199 ms) než v zápase → úsporný režim Wi-Fi. Handshake tentokrát 217 ms. Hodiny klienta jdou cca o 1 s napřed; jednosměrné zpoždění událostí nejde kvůli chybě v milisekundách změřit.
- **Třetí sezení (17:18–17:20, role prohozené: host Windows Jiskra, klient Mac Krügermann, Střechy FFA 150 s):** host Windows 60 FPS (vsync), 0 záseků. Klient Mac: mezery 117–165 ms 4–9× za 5 s + 2 spiky 318/330 ms, 0 ztracených snapshotů, ping vstupu 153–166 ms při RTT 53–75 ms. Host: vstupy z Macu plynulé (starved 1–7, dříve 4–42), fronta 5. ENet ztráta z pohledu Windows hosta roste 1,5 → 3,4 % (směr Windows → Mac), z pohledu Macu 1,9 → 0,4 %. Korekce na Macu 13–38× za 5 s při střelbě z kulometu (10 ran/s, nepredikovaný ráz), 0 bez střelby.
- **Závěr ze 3 sezení:** (a) **data odesílaná Windows notebookem chodí po shlucích** bez ohledu na roli (vstupy v 1./2., snapshoty ve 3. sezení) a jeho směrem je víc ztrát → Wi-Fi/úspora energie na notebooku; (b) **snapshoty mají mezery v obou směrech, vstupy klienta jen od Windows** → podezření na blokování: všechny RPC jsou na kanálu 0 (`unreliable_ordered` snapshoty + `reliable` výstřely/zabití); pokud ENet v Godotu drží neuspořádané pakety za ztraceným spolehlivým na stejném kanálu, mezera = doba opakovaného odeslání (RTT + 4×rozptyl ≈ 120–150 ms, dvojitá ztráta ≈ 300–400 ms) – přesně naměřené hodnoty. **Ověřit** a případně posílat snapshoty jako `unreliable` (neuspořádané; staré snapshoty už zahazuje `MatchController` podle ticku) nebo na vlastním kanálu; (c) korekce vlastní postavy hlavně od nepredikovaného zpětného rázu (rychlopalné zbraně) a od zásahů silnými zbraněmi (odhoz × ~150 ms); (d) zpoždění vstupu ~90 ms navíc = fronta vstupů na hostu stále u stropu 5 kvůli shlukům.
- **Chyby diagnostiky:** `mem=0MB` v release (použít `OS.get_static_memory_usage()`), milisekundy ve značce času berou `ticks_msec`, ne systémový čas.
- **Doporučení hráčům (bez kódu):** notebook do zásuvky a režim napájení „Nejlepší výkon“, ve Správci zařízení u Wi-Fi adaptéru úspora energie vypnutá / „Maximální výkon“, ideálně kabel; `tailscale ping <host>` ukáže, zda jde spojení napřímo nebo přes DERP relay.

Dříve zapsané:
**Testovací hraní 0.2.8 s kamarády (kamarád hostuje) podle `docs/PLAYTEST.md`**, potom od všech vyžádat `last_game.log` a vyhodnotit (připojení, Tailscale, ztráty, mezery snapshotů, záseky, přebíjení). Opravy až po vyhodnocení a pokynu uživatele.
Dříve zapsané:
**Testovací hraní s kamarádem jako hostitelem podle `docs/PLAYTEST.md`**, potom od všech hráčů vyžádat `godot.log` a vyhodnotit `[conn]`/`[net]` řádky (připojení, ztráty, mezery snapshotů, záseky). Opravy sítě až po vyhodnocení a pokynu uživatele.
Dříve zapsané:
**Ruční test 2 v 2 se skutečnými hráči** (hostitel zapne „2 v 2“, rozdělit týmy, zahrát zápas: ověřit, že spoluhráče nejde shodit, scoreboardy vlevo/vpravo, výsledek týmu). Pak dle pokynu uživatele.
Dále stále platí: **ruční vizuální porovnání obou postav s předlohami:** `tools/godot --path .`, v menu postupně zvolit Krügermanna a Architekta a spustit trénink. Pohyb A/D, skok W/mezerník, míření myší, střelba levým tlačítkem, schopnost E/pravým tlačítkem. Aktuální implementační zadání je dokončené; další herní změny jen podle nového pokynu. macOS export neopakovat bez nového svolení po zamítnutém spuštění.

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
- **Milník:** M3 a M3U hotové; M4 predikce a skóre vydané jako dev sestavení 27, changelog a kadence jako sestavení 28. Nyní sjednocení vydávání na `0.1.1`, potom debug měření. Odložené ruční testy viz výše.
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
- **2026-11-13, 0.2.16 krok 6/7 (Claude, lokální commit, bez pushe):** nové `src/arenas/moving_platform.gd`, `src/arenas/arena_hobbiton.tscn`, `data/arenas/hobbiton.tres`, `assets/backgrounds/hobbiton.png`, `assets/sprites/tiles/turf_{top,fill}.png`, `tests/test_moving_platforms.gd`; úpravy `arena.gd`, `platform.gd`, `player.gd`, `player_motor.gd`, `input_frame.gd`, `match_controller.gd`, `match_client.gd`, `client_prediction.gd`, `arena_data.gd`, `tools/art/generate_world.py`, CSV, changelog, `test_arenas.gd`, EDITING_GUIDE, ARCHITECTURE, CREDITS, CLAUDE.md.
- **2026-11-13, 0.2.16 krok 5/7 (Claude, lokální commit, bez pushe):** `src/ui/lobby.tscn` (nové rozvržení), `src/ui/lobby.gd`, `src/ui/main_menu.tscn` + `.gd` (bez Ovládání), CSV (`LOBBY_PLAYERS`, smazané `CONTROLS_*`, changelog), PLAYTEST, ARCHITECTURE, CLAUDE.md.
- **2026-11-13, 0.2.16 krok 4/7 (Claude, lokální commit, bez pushe):** `teams.gd`, `team_choice.gd`, `match_ranking.gd`, `lobby_validator.gd`, `session.gd`, `enet_direct_connector.gd`, `net_codec.gd`, `build_info.gd` (protokol 24), `player.gd` (barvy), `match_controller.gd`, `match_client.gd`, `match_hud.gd`, `lobby.gd`, `results.gd`, `connection_log.gd`, `arena.gd` + 4 scény map (spawny), CSV, changelog, testy (`test_teams`, `test_lobby_validator`, `test_arenas`, `run_tests.gd`), README, CLAUDE.md, ARCHITECTURE, EDITING_GUIDE.
- **2026-11-13, 0.2.16 krok 3/7 (Claude, lokální commit, bez pushe):** `src/abilities/teleport_ability.gd`, `src/player/player.gd` (cooldown v ticích), `tests/run_tests.gd` + `tests/test_case.gd` (async testy), `tests/test_abilities.gd` (teleport ve fyzikálním světě, cooldown host/klient), CSV, changelog, EDITING_GUIDE, ARCHITECTURE, CLAUDE.md.
- **2026-11-13, 0.2.16 krok 2/7 (Claude, lokální commit, bez pushe):** `src/ui/score_table.gd` (jedna kompaktní velikost), `src/ui/match_hud.gd` (menší okraj panelu), nový `tests/test_score_table.gd`.
- **2026-11-13, 0.2.16 krok 1/7 (Claude, lokální commit, bez pushe):** `heavy_machine_gun.tres`, `sniper.tres`, `gas_blast.tres`, `weapon_data.gd` (`move_spread_degrees`), `combat_rules.gd` (rozptyl při pohybu, limit 2600), `input_frame.gd` (`is_moving`), `weapon_system.gd`, `gas_cloud.gd`, `gas_blast_ability.gd`, CSV (popisy + changelog), `changelog.tres`, `project.godot` 0.2.16, testy (`test_weapons`, `test_abilities`, `test_reload`), EDITING_GUIDE, CLAUDE.md.
- **2026-11-09, verze 0.2.15 (Claude):** zpoždění a slabší odfouknutí plynu (`gas_blast.tres`, `GasCloud.delay_ticks`, `AreaEffects.blow/_gas_touching`, `Player.gas_ticks` ve snapshotu, protokol 23), testy plynu; úklid `build/` a archivů v `.tools/`; CLAUDE.md (archivy lze mazat), ARCHITECTURE, EDITING_GUIDE.
- **2026-11-09, verze 0.2.14 (Claude):** mapa Peklo (`arena_hell.tscn`, `hell.tres`, `lava.gd`, grafika lávy a pozadí), láva ve snapshotu (protokol 22), HUD upozornění, bezpečný respawn nad lávou; `tests/test_lava.gd`, `test_arenas` se 4 mapami; EDITING_GUIDE (tabulka map a jejich názvů, láva), ARCHITECTURE, CLAUDE.md, PLAN T.5.
- **2026-11-09, verze 0.2.13 (Claude):** odfukovací plyn Krügermanna (`gas_blast.tres`, `gas_blast_ability.gd`, `gas_cloud.gd`, `AreaEffects.blow`, `gas_arrow.png`), Balvan střílí za štítem, těžký kulomet (`heavy_machine_gun.tres` + sprite, `air_spread_degrees`), rozptyl podle seq vstupu, oprava párování uvolněné kulky, protokol 21; testy plynu/štítu/týmů/zbraní; ARCHITECTURE, EDITING_GUIDE, CLAUDE.md.
- **2026-11-09, verze 0.2.12 (Claude):** jen WASD (+ migrace uloženého ovládání), přebití na Q (`InputFrame.RELOAD`, protokol 20), schopnost po smrti připravená, chodící cvičný panák (`practice_dummy.gd`); testy `test_practice_dummy.gd` + rozšíření key_bindings/reload/net_codec/abilities/client_prediction; README, ARCHITECTURE, CLAUDE.md, PLAYTEST.
- **2026-11-08, verze 0.2.11 (Claude):** rozdělení `player.gd` / `match_controller.gd` / `session.gd` (nové `player_weapon.gd`, `remote_view.gd`, `player_labels.gd`, `match_client.gd`, `session_auth.gd`), `sys_free` = fyzicky volná RAM na všech systémech, `__pycache__/` v `.gitignore`; testy upraveny na `player.gun` a `MatchClient`; ARCHITECTURE/CLAUDE.md/PLAYTEST aktualizované.
- **2026-11-05, verze 0.2.8 (Claude):** přebíjení + animace, rychlejší Stín, kompaktní 2v2 scoreboard, nastavení s bindováním, Ovládání v menu, jediný diagnostický log, changelog po sekcích, horní patro Střech, PLAN.md T.5; viz „Kde jsme skončili“.
- **2026-11-05, verze 0.2.7 (Claude):** písmo Jersey 15, potvrzení postavy + náhledy na kartách, mapa v pozadí lobby, diagnostické logy + `docs/PLAYTEST.md`; viz „Kde jsme skončili“.
- **2026-11-05, režim 2 v 2, verze 0.2.6 (Claude):** viz „Kde jsme skončili“; changelog `CHANGELOG_TEAMS` přidán do aktuálního záznamu (build 0) vedle nových vzhledů a jetpacku.
- **2026-11-05, nové vzhledy podle předloh, lokální 0.2.6 (Codex, bez commitu/pushe):** samostatný pixelový generátor `reference_characters.py`, nové kompletní animované sheety Krügermanna a Architekta, parametrizovaný vizuální test obou postav, související texty/dokumentace a changelog 0.2.5/53 → 0.2.6/build 0. V exportech vyloučeny referenční obrázky. Již rozpracovaný jetpack zachován. Windows/Linux build a obsah balíčků ověřeny; macOS export nebyl povolen.
- **2026-11-05, efekty schopností + delší tlaková vlna, verze 0.2.5 (Claude):** `tools/art/generate_effects.py`, `assets/sprites/effects/*`, `src/player/ability_fx.gd`, `player_visual.gd` (efekty), `slow_cloud.gd` (pixelový plyn), `shockwave.tres` radius 320, test efektů.
- **2026-11-05, validace + opravy (0.2.3) a pixelové písmo/scoreboard/KILL (0.2.4) (Claude):** viz „Kde jsme skončili“; nové `src/ui/kill_popup.gd`, `assets/fonts/PixelifySans.ttf` (+ OFL), úpravy `match_hud.gd`, `match.tscn` (ScorePanel, bez KillLabel), CSV `POPUP_*` místo `HUD_*KILL`.
- **2026-11-05, pixel art map/pozadí/menu, verze 0.2.2 (Claude):** `tools/art/generate_world.py`, `assets/sprites/tiles`, `assets/backgrounds`, `assets/ui` (+ `theme.tres`), `src/arenas/arena_background.gd`, `platform.gd` (dlaždice), pozadí v 3 arénách a 3 UI scénách, logo v menu, `gui/theme/custom` v `project.godot`, CREDITS, EDITING_GUIDE.
- **2026-11-05, pixel art postav, verze 0.2.1 (Claude):** `tools/art/generate_sprites.py`, `assets/sprites/**`, `src/player/player_visual.gd`, `CharacterData.sprite_sheet`, `WeaponData.sprite`, `Player.last_fire_ms`/`is_firing()`, `FLAG_FIRING`, jmenovka v barvě slotu, CREDITS, EDITING_GUIDE (grafika), testy `test_player_visual`.
- **2026-11-05, vydání v0.2.0 + název „Dojo Knockout“ (Claude):** `GAME_TITLE` v CSV a CI, titulek okna, `publish_release.sh` (`GAME_TITLE` s výchozím `GAME_NAME`), test titulku v `tests/test_release_workflow.py` (CI proměnnou v testech výslovně odstraňuje), README.
- **2026-11-05, rozvržení menu/lobby + M6.3 test 4 hráčů, verze 0.1.15 (Claude):** `main_menu.tscn` (Trénink na celou šířku), `lobby.tscn`/`lobby.gd` (kompaktnější), výsledky testu 4 botů a profilace zapsány.
- **2026-11-05, M6.1 + M6.2 mapy a výběr mapy, verze 0.1.14 (Claude):** `ArenaData`, `data/arenas/{rooftops,temple_steps,hanging_bridges}.tres`, 2 nové scény arén, `ContentDB` arény, `ArenaChoice`, `Session.arena_id` + `_begin_match(slots, arena)`, `Settings.practice_arena`, výběr v menu a lobby, lobby ve `ScrollContainer`, `tests/test_arenas.gd`, oprava changelogu 0.1.12 → 43, EDITING_GUIDE o mapách.
- **2026-11-05, M5.4 návod + delší plyn, verze 0.1.13 (Claude):** `docs/EDITING_GUIDE.md`, `slow_cloud` délka 540, akceptační ověření přidání postavy přes data.
- **2026-11-05, jedna zbraň na postavu, verze 0.1.12 (Claude):** `CharacterData.weapon`, 6 postav upraveno, odstraněno přepínání (`project.godot`, `InputFrame`, `Player`, `WeaponSystem`, `CombatRules`, `NetCodec`, `MatchController`), HUD/lobby/CSV, testy.
- **2026-11-04 večer, rozhodnutí uživatele (jen dokumentace):** každá postava bude mít jen jednu zbraň, přepínání zbraní se odstraní; zapsáno do PLAN.md G.0a a „Další krok“.
- **2026-11-04, M5.3 výběr postavy v lobby + plyn jako pás, verze 0.1.11 (Claude):** `src/net/character_choice.gd`, postava v `Session.players`, `LobbyValidator` kontroluje postavy, karty v `lobby.gd`, `MatchController` bere zvolenou postavu, odstraněno `character_for_slot`, `SlowCloud` jako obdélníkový pás, `SlowCloudAbility` (délka/výška/mezera).
- **2026-11-04, výběr postavy pro trénink, verze 0.1.10 (Claude):** `PracticeRow` + `CharacterOption` v `main_menu.tscn`, `Settings.practice_character`, `ContentDB.practice_character()`, test; zapsána budoucí práce na zbraních (PLAN.md G.0a).
- **2026-11-04, M5.2c oblak + plošina, Krügermann, zpětný ráz, verze 0.1.9 (Claude):** `AreaEffects`, `SlowCloud`, `TempPlatform`, `SlowCloudAbility`, `PlatformAbility`, `data/abilities/{slow_cloud,platform}.tres`, `ContentDB` schopnosti, zpomalení v `PlayerMotor`, RPC `effect_spawned` v `match_net.gd`, přejmenování mlha → krugermann, zpětný ráz 6 zbraní + `CombatRules.MIN_RECOIL`.
- **2026-11-04, M5.2b úskok + přesun, verze 0.1.8 (Claude):** `DashAbility`, `TeleportAbility`, `data/abilities/{dash,teleport}.tres`, `AbilityData.start()`, `Player.tick_ability()` (přesunuto z `AbilitySystem`), `PlayerMotor` stav úskoku, snapshot 39 B (cooldown v tikách, úskok), protokol 8, testy predikce úskoku a motoru.
- **2026-11-04, M5.2a schopnosti + 2 nové postavy, verze 0.1.7 (Claude):** `AbilityData`, `ShieldAbility`, `ShockwaveAbility`, `AbilitySystem`, `data/abilities/{shield,shockwave}.tres`, `CharacterData.ability`, stav schopnosti v `Player`, snapshot 34 B (protokol 7), HUD, 4 nové zbraně (`light_machine_gun`, `revolver`, `nail_gun`, `double_barrel`), postavy `krugermann`, `architekt`, testy `test_abilities`.
- **2026-11-04, M5.1 zbraně + přepínání, verze 0.1.6 (Claude):** 7 nových `data/weapons/*.tres`, 3 nové postavy, `WeaponData.pellets`, akce `weapon_switch`/`weapon_1`/`weapon_2`, `Player.weapon_slot`/`wanted_weapon_slot`/`handle_weapon_input`, `WeaponSystem._switch_weapon` + broky, `NetCodec.FLAG_WEAPON_2`, HUD zbraň, `ContentDB.character_for_slot` (dočasné) a oprava řazení, `tests/test_weapons.gd`.
- **2026-11-04, M4.1 test přes Tailscale + log `[net]`, verze 0.1.5 (Claude):** nové `src/net/net_log.gd` + napojení v `match_controller.gd` (289 řádků), test `tests/test_net_log.gd`, zápis zjištění do PLAN.md M4.1.
- **2026-11-04, M4 validace + odpojení + pole adresy, verze 0.1.4 (Claude):** nové `src/net/lobby_validator.gd` (+ `clean_name` přesunuto ze Session, konstanty MAX_PLAYERS/MAX_NAME_LENGTH odtud), kontroly fází v Session, `InputBuffer.STALE_TICKS`, kontrola konečných čísel u střel od hostitele, `_client_loaded` jen v zápase, menu bez předvyplněné adresy. Testy `test_lobby_validator` (5) a `test_input_buffer::test_long_silence_stops_the_player`.
- **2026-11-04, M4 fronta vstupů + ping/FPS, verze 0.1.3 (Claude):**
  - `src/match/input_buffer.gd` (nový): logika fronty přesunuta z `match_controller.gd` (282 řádků), dohánění po 0,5 s, sloučení tlačítek přeskočených vstupů, čtení vstupu i u neaktivního hráče.
  - `NetStats` zjednodušen jen na ping; `MatchHud.show_ping()` – FPS + ping, písmo 12, viditelné hned, F3 přepíná. Odstraněny klíče `DEBUG_NET_*`, nové `HUD_FPS`, `HUD_PING`, `CHANGELOG_PING_FPS`, `CHANGELOG_INPUT_DELAY`. `ClientPrediction.pending_count()` odstraněno.
- **2026-11-04, M4 ukazatel F3 + verze 0.1.2 + codex.md (Claude):**
  - `codex.md` a `AGENTS.md`: pravidla pro Codex (nikdy nepushovat, necommitovat bez pokynu, zachovat strukturu kódu a verzování/release, changelog jen nejnovější verze). `CLAUDE.md`: Claude znovu pushuje sám, Codex odkazem na codex.md.
  - `src/net/net_stats.gd` (nový): měření bez nových síťových zpráv – čas odeslání vstupu podle `seq`, potvrzení přes `last_seq` ve snapshotu, vyhlazený průměr + kolísání, intervaly snapshotů, maxima za 2 s, omezená paměť (256 vstupů).
  - `ClientPrediction.reconcile()` vrací chybu predikce v px (−1 při prvním snapshotu/smrti/respawnu), `pending_count()`.
  - `MatchHud`: F3 přepíná ukazatel, texty `DEBUG_NET_*` v CSV. `MatchController` jen předává měření (302 řádků).
  - Changelog: `Changelog.latest()`, menu „Co je nového“ ukazuje jen nejnovější verzi; poznámky vydání beze změny (už dřív jen nejnovější).
  - Opravena chyba nalezená během práce: text s čárkou v CSV bez uvozovek se uřízl; nový test `tests/test_translations_csv.gd` hlídá 2 sloupce na řádek.
- **2026-11-04, kontrola po pullu (Claude):** stažené `da40eac`, `2560ebb`, `6978a62`; prošel jsem diff kódu (predikce, skóre, protokol 5, changelog, vydávání), testy, lokalizaci, Python testy workflow, síťový smoke test a veřejný release. Chyby v kódu nenalezeny; opraven jen zastaralý PROGRESS.md (tvrdil necommitnuté změny a neověřený release).
- **2026-11-04, sjednocení vydávání (lokálně, bez commitu/pushe):** jedno existující vydání s verzí z projektu, nyní `0.1.1`; main-only CI, bez posouvání tagů a vytváření dalších vydání. Kompatibilní přechod dev → stable/latest a skrytí původního `v0.1.0` až po úspěchu. Publikovaný changelog sestavení 28 archivovaný. Předchozí changelog/kadenci publikoval uživatel jako `2560ebb`, úspěšný CI běh `41843215167`.
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
- **6 hráčů na původních mapách** (1280 × 720) je těsno – pro 6 hráčů je velký Hobitín.
- **Pohyblivé plošiny:** vzdálený hráč stojící na pohyblivé plošině se u klienta kreslí o interpolační zpoždění (~100 ms) pozadu, takže na rychlé plošině vypadá o pár px vedle (vlastní postava sedí přesně).
- **Peklo:** láva po vystoupání už neklesá; plošina panáka je po zaplavení pryč, panák se oživí na mostě. Spawn hráčů na začátku zápasu je dole (sloty 0–3), nahoře jsou jen záložní/lávové spawny.
- **Odfouknutí plynem u klienta-oběti** = jedna korekce ~130–170 px (o plynu se dozví se zpožděním sítě), stejně jako nepredikovaný zásah.
- **Směr vlastní kulky** se může vzácně lišit od hostitele kolem smrti/respawnu nebo při chybné predikci dotyku se zemí (párování v pořadí).
- **Cvičný panák** na plošině užší než ~180 px jen stojí a poskakuje (není kam bezpečně jít); když mu cestu zastoupí hráč, otočí se nebo stojí. Po odhozu ve vzduchu neřídí (záměrně – shodit ho má jít).
- **Výklad „cooldown schopnosti při smrti“:** zadání bylo useknuté, implementováno jako vynulování (schopnost hned připravená).
- **Omezení ověření 0.2.6:** nový macOS export nebyl povolen; Windows/Linux binárky byly sestaveny a jejich balíčky načteny macOS Godotem, nikoli spuštěny nativně na cílových OS. Ruční síťová hra po této čistě vzhledové úpravě neopakována. Běžící zdrojová hra a schopnosti obou postav ověřeny na macOS.
- **Ping ukazuje potvrzení vstupu**, tj. RTT + až ~33 ms do dalšího snapshotu + případná fronta na hostu; je tedy o něco vyšší než čistý síťový ping.
- **Přeskočený vstup při dohánění** způsobí na klientovi malou korekci (~1 tick pohybu), vyhlazenou vizuálním offsetem.
- **Stejná Wi-Fi: výrazné sekání všech klientů kromě hosta** (nahlášeno uživatelem 2026-11-04). Příčina neměřená, oprava výslovně odložená; viz PLAN.md M4.1. Lokální headless síťové testy tento problém nevyvracejí.
- **Každá změna hry = nová verze:** hra ji od M3U sama nabídne v menu. Verze bez aktualizátoru (≤ sestavení 24) je potřeba naposledy stáhnout ručně.
- **Vyšší zpoždění zobrazení ostatních hráčů na kolísavé síti** (až 250 ms) je cena za plynulost; na čisté síti naopak kratší (~50 ms) než dřív (100 ms).
- **Dvě kopie hry na jednom počítači zapisují do stejného `last_game.log`** (jen vývojové testy; hráči mají každý svůj počítač).
- **Zpětný ráz odstřelovačky (600)** odsune Stína po 2–3 ranách z okraje plošiny – stávající balanc, zvážit při ladění.
- **Tailscale:** Share ověřen 2026-11-04 (Mac host, přímé spojení). Bez Share se připojení nepovede oběma směry – hra hlásí jen obecnou chybu připojení. Firewall na Windows při hostování zatím neověřen.
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
- **2026-11-13, 0.2.16 krok 6/7:** **175/175 GDScript testů** (nové `test_moving_platforms.gd`: většina plošin se hýbe, ne všechny; poloha jen z ticku, perioda, fáze; žádná plošina nad 120 px/s; hráč jede s houpačkou, výtahem i přívozem 2 s a stojí na nich; **replay klienta od snapshotu ticku 30 skončí přesně tam, kde host** (houpačka, výtah, svislá, s krokem a skokem); odhad ticku přes přetečení u16), test arén se 5 mapami. Bez nesení testy selžou (ověřeno). **Síť (host + klient Stín, `--fake-lag=60`, Hobitín; host klienta postaví na houpačku, výtah, přívoz; klient stojí a 2× krátce jde):** korekce mimo vynucené přesuny max **1,3–2,0 px** za 5 s (před opravou vnoření na výtahu propad 22 px 39× za 5 s, před opravou přichycení 12,9 px), klient na houpačce stále 110 px od jejího kraje (jede s ní), 0 smrtí. **Střechy, běh a skoky (vliv `apply_floor_snap`):** nová verze 3 běhy vs. stará 3 běhy – okna po startu stejná nebo lepší (1,3–2,4 px), okno startu pohybu po odpočtu kolísá i ve staré verzi (8,6–17 px). **Panák na Hobitíně 5 min (5 spawnů): 0 pádů.** **6 procesů na Hobitíně** (3 týmy → 2 týmy → každý proti každému): týmy začínají pohromadě (červení na levém kopci, modří na pravém, zelení na střední plošině), výsledky u všech stejné, 0 chyb skriptů. Screenshot tréninku. **Neověřeno:** ruční hraní (dojem z rychlosti plošin, čitelnost malých postav při zoomu 0,5), vzdálení hráči na pohyblivé plošině vypadají kvůli interpolaci mírně posunutí (~0,1 s × rychlost plošiny), 6 hráčů na mapě naživo.
- **2026-11-13, 0.2.16 krok 5/7:** **169/169 GDScript testů**, lokalizace **270 klíčů, 0 chybějících**. Screenshoty 1280 × 720 (falešná data): lobby hostitele se 6 hráči a 3 týmy a lobby se 4 hráči „každý proti každému“ – vše na jedné obrazovce, karty čitelné (i „Dvouhlavňová brokovnice“), jména v barvách týmů; hlavní menu bez Ovládání. Síťový test 6 procesů znovu (lobby na hostu i 5 klientech, 3 režimy, 3× návrat do lobby): 0 chyb skriptů. **Neověřeno:** screenshot klientského pohledu (místo výběrů jen popisky, bez adres – stejné kontejnery), menší okna než 1280 × 720 (posuvník zůstal).
- **2026-11-13, 0.2.16 krok 4/7:** **169/169 GDScript testů** (nové: režimy a limity 3 / 2 na tým, `ready_to_start` pro 3 v 3, 3 v 1, 4 v 2, 2+2+2, 1+1+1, prázdný zelený, hráč v zeleném při 2 týmech; startovní sloty týmů; 3 týmy – pořadí podle výdrže; 6 hráčů projde validací, 7 ne; sloty do 5; spawny 6 v pořadí L/P/L/P/střed na 4 mapách; ENet a snapshot pro 6), lokalizace OK. **Síť 6 procesů (host + 5 klientů, Střechy):** 3 týmy po 2 → 2 týmy (zelení se sami rozdělili na 3 v 3) → každý proti každému; všichni klienti vidí 6 hráčů, 3 / 2 / 1 tabulky, správné sloty a spawny (týmy pohromadě), stejné výsledky (zelení 1., modří 2., červení 3. / celý vítězný tým 1. / místa 1–6), návrat do lobby 3×, 0 chyb na klientech; 7. hráč během zápasu „Zápas už běží“, do plného lobby „Hra je plná (max. 6 hráčů).“. Před opravou ENet limitu se 5. klient nepřipojil (timeout). Na hostu zbývá při startu 1 chyba „Node not found Match/MatchNet“ na klienta (opakované oznámení „načteno“, stávající chování; dřív navíc vstupy). Screenshoty (falešná data): HUD 3 tabulky, výsledky 6 řádků, lobby 6 hráčů (přetéká – krok 5). **Neověřeno:** reálná hra 6 lidí přes Wi-Fi/Tailscale (výkon hostitele, provoz ~6× snapshot 284 B × 60/s), mapy jsou pro 6 hráčů těsné (velká mapa = krok 6), okenní klient se v testu nepřipojil (zřejmě macOS ochrana místní sítě pro okenní proces – headless klienti OK).
- **2026-11-13, 0.2.16 krok 3/7:** **165/165 GDScript testů** (nové: teleport ve skutečném fyzikálním světě – vodorovně plných 250 px přes hráče, 3°/10°/30° do podlahy sklouzne, nahoru proskakovací plošinou, pevná zeď zastaví těsně před ní, šikmo do zdi sklouzne nahoru, kolmo do podlahy nikam; cooldown host vs. klient s periodickými snapshoty 500 ticků stejně), na staré verzi tytéž testy selžou (posun 0–1 px do podlahy, hráč zastavil po 113 px, nesoulad cooldownu v tiku 479). **Síť (host Balvan + klient Stín, `--fake-lag=60`, Střechy):** 5 přesunů (170°, 3°, 150° do podlahy, 2× mačkání E přesně při konci cooldownu na 5° a 180°) – predikce klienta = pozice hostitele na 4 desetinná místa, žádný návrat. **Neověřeno:** ruční dojem; přesun do pevného bloku z boku na mapách s výklenky.
- **2026-11-13, 0.2.16 krok 2/7:** **163/163 GDScript testů** (nový: tabulka FFA se 4 dlouhými jmény ≤ 340 × 130 px; na staré verzi 440 × 161 px → test selže), lokalizace OK. Screenshoty 1280 × 720 (trénink + 2 přidaní hráči; týmové tabulky s falešnými hráči): vše čitelné, dlouhé jméno zkrácené „…“. **Neověřeno:** tabulka v reálné síťové hře (stejný kód jako trénink).
- **2026-11-13, 0.2.16 krok 1/7:** **162/162 GDScript testů** (nové: kulomet 75 nábojů / 2 s, ±1° vestoje, ±30° ve vzduchu i při klávese pohybu, každá z A/D/W/S je pohyb, odstřelovačka 2600 v limitu; plyn až po 60 ticích, žije ≥ 5 s), lokalizace **278 klíčů, 0 chybějících**. Trénink (headless, skutečné projektily): Balvan vestoje rozptyl 1,6° (10 ran), při chůzi 54° (10 ran), 75 nábojů; Krügermannův plyn existoval přesně 5,00 s. **Neověřeno:** ruční dojem z balancu, síťová hra (rozptyl při pohybu používá jen vstup, sdílený s predikcí – pokryto unit testem).
- **2026-11-09, 0.2.15:** **160/160 GDScript testů** (plyn: 11 ticků uvnitř nic, 12. = odfouknutí 1250/váha, výstup vynuluje počet, okraj pásu, pod pásem nic, nezranitelný se nepočítá, štít, týmy; `gas_ticks` ve snapshotu a při replay, reset po respawnu), lokalizace **275 klíčů, 0 chybějících**. Síť (host Krügermann 200 px od klienta Balvana, lag 60 ms), 2 běhy: odfouknutí 885 px/s (= 1250/1,4), korekce klienta ≤ 10 px (dřív 128–165 px), 55/55 kulek ve směru hostitele, střelba za štítem. Po úklidu Godot běží (`tools/godot --version`). **Neověřeno:** ruční dojem z 0,2 s, lokální export po smazání archivu šablon (nainstalované šablony zůstaly).
- **2026-11-09, 0.2.14:** **159/159 GDScript testů** (nové `test_lava.gd`: jen proskakovací plošiny a dlouhý horní most, láva startuje pod plošinami a končí těsně pod mostem, spustí se při 3 životech (jen jednou) / v tréninku po 2 smrtích, stoupá a zastaví se, klient přebírá hladinu, dotyk chodidly, respawn při stoupání jen nad konečnou hladinou, záloha nejvyšší spawn, hladina ve snapshotu), lokalizace OK. **Trénink Peklo (zrychleně):** 2 pády do lávy dole → láva stoupá, nápis „Láva stoupá!“, respawn na mostě, panáka zabila na jeho plošině, oživen na mostě, láva skončila na 290; 3 respawny, 0 v lávě. **Panák na 4 mapách × 5 min** (všechny spawny): 0 pádů (první test panáka minulé verze běžel kvůli načítání Settings na výchozí mapě – opraveno ve skriptu, výsledek stejný). **Síť (host + klient s lagem 60):** klient vidí hladinu 880 → 290 plynule, upozornění, zemřel v lávě na své plošině, oživen na mostě (950, 210). Screenshoty Pekla (plošiny po zesvětlení dobře vidět). **Neověřeno:** ruční hraní, 2 v 2 na Pekle, Windows.
- **2026-11-09, 0.2.13:** **154/154 GDScript testů** (nové: plyn odfoukne hned a stejně při setrvání, dotek konce pásu stačí, pod pásem nic, majitel/spoluhráč/čerstvě respawnutý imunní, levý plyn fouká doleva, štít × 0,2, host připíše Krügermanna, směr od hostitele vyhraje; Balvan střílí za štítem; těžký kulomet 100 nábojů, ≤ 1° na zemi, ≥ 10× víc ve vzduchu; stejný vstup = stejný směr kulky, různé vstupy se rozptylují), lokalizace **271 klíčů, 0 chybějících**. Existující sprity se generátorem nezměnily (jen nové PNG). **Síťový test (host Krügermann, klient Balvan s `--fake-lag=60`):** plyn klienta odfoukl rychlostí 1063 px/s (= 1500/1,4), při shození z mapy `[match] kill by slot0` (Krügermann 1 zabití); vlastní kulky klienta: 55/55 a 43/43 přesně ve směru hostitele (před opravou uvolněné kulky jednou 1/43 kolem respawnu), rozptyl ve vzduchu ±13,9–15,2°, na zemi ±0,8°; za štítem 15 ran; korekce klienta při odfouknutí 128–165 px jednou (plyn se dozví se zpožděním, jako nepredikovaný zásah), jinak ≤ 5 px; po opravě žádné chyby skriptů. **Neověřeno:** ruční dojem (síla plynu, čitelnost šipek, balanc kulometu), Windows, skutečná Wi-Fi.
- **2026-11-09, 0.2.12:** **151/151 GDScript testů** (nové: výchozí jen WASD + Q, migrace starého uložení, výchozí klávesa nové akce nekrade použitou, ruční přebití jen s chybějícími náboji / bez restartu při držení / bez výstřelu, predikce ručního přebití bez korekce, RELOAD bit ve vstupu i v `prev_buttons` snapshotu, schopnost po respawnu připravená, panák – nechodí k okraji, stojí bez místa, ve vzduchu neřídí, skáče jen na místě), lokalizace **266 klíčů, 0 chybějících**, Python testy vydávání OK. **Panák (zrychlená simulace `--fixed-fps 60`):** 3 mapy × 5 min ze spawnu panáka i 3 mapy × 10 min s přesunem na všechny 4 spawny – **0 pádů**, ušel 44–105 tisíc px, 40–91 skoků; chodí i po dřevěných plošinách (paprsek ověřen zvlášť na jednosměrné plošině); na spawnu 0 stál u kraje, protože mu cestu blokoval nehybný hráč (správně). **Síťový test 4 procesů:** klient opakovaně 1 výstřel + Q → klient (predikce) i host vidí přebíjení s náboji v zásobníku (min. 1), korekce 2–3 za 5 s (max 14 px), připojení/špatný kód/pozdní hráč OK, protokol 20, žádné chyby skriptů. **UI (okno):** Nastavení s řádkem Přebití (Q), jen WASD, vše se vejde; nápověda Ovládání s aktuálními klávesami; skutečný `settings.cfg` z 0.2.11 (šipky + mezerník) se načetl jako jen WASD a soubor se nezměnil. **Neověřeno:** ruční hraní (dojem z panáka, Q, schopnosti), Windows, skutečná Wi-Fi/Tailscale.
- **2026-11-08, 0.2.11:** **141/141 GDScript testů** (nový: volná paměť bez swapu/stránkovacího souboru – data jako z Windows, Windows bez stránkovacího souboru, macOS/Linux), lokalizace **261 klíčů, 0 chybějících**. Síťový test 4 procesů na 127.0.0.1 (host, klient `--fake-lag=60` běhá/skáče/střílí, pokus se špatným kódem, pozdní hráč během zápasu), stejný scénář i na 0.2.10 pro srovnání: připojení OK, špatný kód → „Špatný kód hry…“, pozdní hráč → „Zápas už běží…“, klient vidí vlastní náboje 3→0 a přebíjení, `[net]` s `sys_free` a `interp_ms`, žádné chyby skriptů. Srovnání 0.2.10 / 0.2.11 (2. běh): posun zobrazení klienta na hostu max 43,0 / 43,5 px, kolísání 20 / 19 ms, host `waited` 41 / 40, skoky vzdáleného hráče > 30 px 3 / 4 (respawny), korekce > 8 px 3 / 2 za 5 s; `sys_free` na Macu 4,7 GB → 3,3 GB (už bez swapu). Trénink s oknem: screenshoty jména a procent (0 % bílé, 37 % žluté), HUD „Odstřelovačka · 2/3“, přebíjení (ukazatel, skloněná zbraň, zásobník, „přebíjení…“). **Neověřeno:** Windows (`sys_free` tam), skutečná Wi-Fi/Tailscale, ruční hra.
- **2026-11-05, 0.2.10:** **140/140 GDScript testů** (nové: `test_damage.gd`, fronta vstupů – vstupy přesně jednou a v pořadí i při shlucích, čekání místo hádání, dohánění; predikce klienta bez korekce při shlucích vstupů na hostu; dopočítání polohy; párování předpovězených střel). Síťový test 3 procesů (host, A s `--fake-lag=60 --fake-burst=100` běhá a střílí kulometem, pozorovatel B), totéž na 0.2.9: **ping A 219–228 → 159–163 ms** (zbytek ≈ simulovaný lag + shluky), korekce A 2–4 → 0–2 za 5 s, B vidí A: velké skoky 23 → 11, zaseknutí 3 → 7 z ~390 ticků; host vidí A: 0.2.9 dokonale (držel zásobu, ale +60 ms pro A), 0.2.10 7 skoků / 6 zaseknutí. Screenshot procent nad postavou (trénink). **Neověřeno:** skutečná Wi-Fi/Tailscale, Windows, dojem z balancu procent.
- **2026-11-05, 0.2.9:** **133/133 GDScript testů** (nové: `test_snapshot_timeline.gd` – měření kolísání, plynulá změna zpoždění, rovnoměrné přehrávání snapshotů přicházejících ve 100ms shlucích; fronta vstupů při shlucích zvedne cíl a přestane hladovět; predikce rázu a přebíjení bez korekce pro kulomet, samopal, odstřelovačku a brokovnici; přesné časovače ve snapshotu). Síťový test host + klient s `--fake-lag=80 --fake-jitter=60`, klient stále střílí z kulometu a běhá: **0.2.8** korekce >8 px 17–23 / 5 s, **0.2.9** 4–8 / 5 s; host 0.2.9 cíl fronty 5–6, po zahřátí 0 hladových ticků; zpoždění interpolace 120–142 ms. Simulátor lagu náhodně zpožďuje jednotlivé pakety, neshlukuje je – zamrzání při shlucích ověřuje jen unit test. **Neověřeno:** skutečná Wi-Fi/Tailscale s kamarádem, Windows.
- **2026-11-05, 0.2.8:** **128/128 GDScript testů** (nové: přebíjení a reset po respawnu, náboje/přebíjení ve snapshotu, bindování kláves, jediný log souborů, sekce changelogu, horní patro Střech), lokalizace **248 klíčů, 0 chybějících**. Trénink (Stín, Střechy): 3 rány → přebíjení 1 s → plný zásobník, screenshot animace; zjištěno, že zpětný ráz odstřelovačky (600) shodí hráče z okraje plošiny při střelbě dolů/do strany (stávající balanc). Síťový test 4 procesů (2v2, Střechy): klient vidí vlastní náboje a přebíjení ze snapshotu, kompaktní scoreboardy, `[net]` řádky s provozem/ENet/interpolací, `last_game.log` jediný soubor ve složce. UI: Nastavení (rebind skoku na K uložen a resetován), Ovládání, Co je nového po sekcích, menu. Lokální macOS release export: staré `godot*.log` smazány, `godot.log` nevzniká. **Neověřeno:** Windows (cesta, tlačítko složky, klávesy podle rozložení), skutečný Tailscale, zápis `last_game.log` v release buildu během online hry (ověřeno jen v debug buildu; release instaluje stejný logger).
- **2026-11-05, 0.2.7:** **116/116 GDScript testů** (nové: síťový log – formát, ENet statistiky, počítadla vstupů, maskování IP; potvrzení postavy), lokalizace **193 klíčů, 0 chybějících**, Python testy vydávání 10/10. Síťový test 4 procesů: hostitel nemůže spustit, dokud nepotvrdí; potvrzení nepotvrzené postavy hostitele jiným hráčem → hostitel dostal jinou; 2 v 2 na Chrámových schodech; logy obou stran mají `[sys]`, `[conn]` (bez IP), `[net]` s ENet RTT/ztrátou, 150 snapshotů / 5 s a ~300 vstupů / 5 s na slot. Screenshoty: menu, lobby (náhledy, potvrzení, mapa v pozadí), HUD 2 v 2 s novým písmem. Lokální macOS release export spuštěn: `[sys]` řádek v `godot.log`. **Neověřeno:** Windows (cesta k logům, tlačítko složky), skutečná Wi-Fi/Tailscale, ruční klikání na karty člověkem.
- **2026-11-05, 2 v 2 (0.2.6):** **113/113 GDScript testů** (nové `test_teams.gd`: pravidla týmů, validace `team`, tlaková vlna a plyn šetří spoluhráče, konec a pořadí týmového zápasu), lokalizace **183 klíčů, 0 chybějících**. Síťový test 4 procesů na 127.0.0.1: host zapne 2 v 2, klienti se přeskupí (Bob → červení, Cyril → modří) na 2+2, start, sloty 0/2 červení a 1/3 modří, všichni klienti vidí 2 scoreboardy „Červený tým“/„Modrý tým“ a týmy hráčů, po vyřazení modrých výsledky „červení 1. místo“ u všech. Fyzikální test: střela proletí spoluhráčem a zasáhne soupeře; bez týmů se zastaví o prvního hráče. Screenshoty lobby (2 v 2), HUD 2 v 2 a tréninku (jedna tabulka beze změny). **Neověřeno:** ruční hra 4 lidí v 2 v 2, Windows.
- **2026-11-05, nové vzhledy (0.2.6):** **109/109 GDScript testů**, lokalizace **174 použitých klíčů, 0 chybějících**, **10/10 Python testů vydávání**, `git diff --check` OK. Pohybový vizuální test kontroluje u Balvana, Krügermanna a Architekta idle/walk/jump/fall/shoot, počty snímků 2/4/1/1/2 a zrcadlení postavy/zbraně. Dočasný integrační smoke úspěšně ověřil obě živé Player scény na podlaze, obě orientace a všechny animace, skutečné projektily/zásahy/zpětný ráz, Krügermannův plyn (imunita vlastníka, zpomalení soupeře), Architektovu plošinu a přistání na ní. Vizuální kontrola generovaných snímků a screenshot běžícího tréninku včetně HUD portrétů (`build/character_preview.png`). **Export Windows a Linux exit 0**; oba skutečné zabalené projekty načteny mimo zdrojový projekt: verze 0.2.6, shodné viditelné pixely obou sheetů a žádné referenční obrázky. Test neplatného manifestu dál záměrně vypisuje chybu JSON a runner při ukončení známá resource warnings; integrační smoke i grafické spuštění bez scriptových chyb. **Neověřeno:** nový macOS export (spuštění zamítnuto), nativní spuštění na Windows/Linuxu, ruční multiplayer/internet.
- **2026-11-05, efekty schopností (0.2.5):** 109/109 unit testů (efekt ke každé schopnosti, prstenec přesně na dosah vlny), lokalizace OK; screenshoty všech 5 efektů v tréninku. **Neověřeno:** efekty u vzdálených hráčů ručně (náběžná hrana z příznaku ve snapshotu – stejná cesta jako dřívější kruh), ruční dojem.
- **2026-11-05, validace (0.2.3–0.2.4):** 108/108 unit testů, lokalizace OK, 10/10 testů vydávání; síťové scénáře: 4 chyby připojení, 6+1 scénářů odpojení (vč. Esc během výsledků – reprodukováno a opraveno), 4 boti na mapách (0 pomalých snímků), korekce při GO 33–47 → 24 px; exporty 3 platforem, spuštění macOS release exportu; screenshoty HUD/scoreboard/KILL a menu. **Neověřeno:** ruční hra 4 lidí, internet, spuštění na Windows a Linuxu.
- **2026-11-05, pixel art světa (0.2.2):** 107/107 unit testů, lokalizace OK; screenshoty 3 map v tréninku, menu, lobby hostitele (bez posuvníku), výsledků a dialogu „Co je nového“. **Neověřeno:** ruční dojem, Windows.
- **2026-11-05, pixel art (0.2.1):** 107/107 unit testů (výběr animace, zrcadlení zbraně, stav vzdáleného hráče ze snapshotu, sprite u každé postavy/zbraně, příznak střelby v kodeku), lokalizace OK. Trénink: screenshoty chůze/skoku/střelby (Balvan). Online host + klient: klient vidí u sebe a host u klienta všech 5 animací. **Neověřeno:** ruční dojem z grafiky, Windows, třetí hráč (animace ze snapshotu jen unit testem).
- **2026-11-05, v0.2.0:** 104/104 unit testů, lokalizace OK, 10/10 testů vydávání (nový: titulek z `GAME_TITLE`, názvy souborů dál `gun_game-*`). **Neověřeno:** ruční hra 4 lidí, internet, Windows.
- **2026-11-05, rozvržení + M6.3 (0.1.15):** 104/104 unit testů, lokalizace OK; screenshot menu a lobby hostitele (bez posuvníku, 1280 × 775); test 4 botů na 3 mapách (výsledky viz „Kde jsme skončili“). **Neověřeno:** ruční hra 4 lidí, internet, Windows, slabší notebook.
- **2026-11-05, M6.1 + M6.2 (0.1.14):** 104/104 unit testů (3 mapy, záložní mapa, ≥ 4 spawny s plošinou pod každým, nic mimo hranice), lokalizace OK. Trénink na obou nových mapách (postavy stojí na zemi, screenshoty). Síťový test se 3 procesy: host zvolí Visuté mosty → oba klienti vidí změnu v lobby a všichni hrají Visuté mosty. Screenshot lobby hostitele (po opravě posuvu). **Neověřeno:** ruční hraní nových map, 4 hráči, Windows.
- **2026-11-05, M5.4 (0.1.13):** 102/102 unit testů, lokalizace OK; ruční akceptační ověření dočasné postavy přes `.tres` + CSV (objevila se v ContentDB a menu). **Neověřeno:** návod prakticky nevyzkoušel nikdo jiný; ruční hraní, Windows.
- **2026-11-05, jedna zbraň (0.1.12):** 102/102 unit testů (každá postava má zvolenou zbraň), lokalizace OK. Trénink: všech 6 postav střílí svou zbraní (brokovnice 8 broků, odstřelovačka 1 rána / 0,5 s), HUD „zbraň | schopnost“. Síťový zápas se 3 hráči bez chyb. **Neověřeno:** ruční hraní, Windows.
- **2026-11-04, M5.3 (0.1.11):** 104/104 unit testů (validace postav v lobby: chybějící, neznámá, duplicitní; první volná/oblíbená postava; plyn jako pás), lokalizace OK. Síťový test se 3 procesy: A získá Stína, B o Stína nepřijde (odmítnuto) a dostane Vichra, všichni tři v zápase vidí stejné postavy; ~2300 opakovaných žádostí (chyba testovacího skriptu) → host jen 6 změn díky limitu. Screenshoty lobby (karty, obsazeno) a plynu. **Neověřeno:** ruční klikání na karty, Windows.
- **2026-11-04, výběr postavy pro trénink (0.1.10):** 103/103 unit testů, lokalizace OK; v menu 6 postav, výběr Stína → v tréninku Stín, volba uložena; screenshot menu. **Neověřeno:** ruční klikání v rozbalovacím seznamu.
- **2026-11-04, M5.2c (0.1.9):** 102/102 unit testů (zpomalení běhu/skoku v motoru, oblak: majitel imunní, mimo oblak nic, bez zdvojení, pozice hostitele; minimum zpětného rázu), lokalizace OK. Online host + klient (lag 100 ms / 5 %): Architekt postaví plošinu ve vzduchu a 3 s na ní stojí u hosta i klienta, korekce max. 24 px; oblak Krügermanna u obou právě jednou. Trénink: měření rázu (samopal dřív 0,7 px / 0,5 s), screenshot oblaku a plošiny. **Neověřeno:** zpomalení soupeře v online hře ručně, ruční hraní, Windows.
- **2026-11-04, M5.2b (0.1.8):** 100/100 unit testů (úskok v motoru, predikce úskoku včetně replay ze snapshotu uprostřed úskoku bez korekce, přenos stavu úskoku a cooldownu), lokalizace OK. Trénink: přesun 250 px ke kurzoru, úskok ~210 px, cooldown blokuje. Online host + klient (lag 100 ms / 5 %): korekce max. 23 px (úskok) / 14 px (přesun). **Neověřeno:** ruční hraní, pocit z ovládání, Windows.
- **2026-11-04, M5.2a (0.1.7):** 98/98 unit testů (aktivace na stisk a cooldown, štít ×0,2 + zákaz střelby, tlaková vlna jen v okruhu, ne chráněné/sebe, v limitu knockbacku a připsání zásahu, 6 postav × 2 unikátní zbraně, limity knockbacku všech 12 zbraní, přenos cooldownu/příznaku), lokalizace 136 klíčů OK. Síťový test: klient (Balvan) zmáčkne E → host i klient: štít 1,5 s, cooldown se odpočítává, HUD text. **Neověřeno:** tlaková vlna online (jen unit test, Vichr se online zatím nedostane do slotu), ruční hraní, balanc.
- **2026-11-04, M5.1 (0.1.6):** 95/95 unit testů (limity knockbacku všech zbraní, 4 postavy × 2 unikátní zbraně, přepnutí a blokace střelby, klávesy, přenos zbraně ve vstupu i snapshotu), lokalizace 122 klíčů OK. Síťový test host + klient: brokovnice 6 broků, Q přepne klienta na pistoli u hosta i klienta, HUD text správně. **Neověřeno:** ruční hraní a pocit z balancu zbraní, kolečko myši ručně, Windows.
- **2026-11-04, log `[net]` (0.1.5):** 91/91 unit testů, lokalizace OK; síťový test host + klient (fake lag 100 ms/5 %) zapsal řádky `[net]` u obou. Že release build zapisuje `print` do `godot.log`, ověří až další ostré hraní (release log z 18:54 obsahoval jen úvodní řádky enginu).
- **2026-11-04, validace + odpojení (0.1.4):** 89/89 unit testů, lokalizace OK. 6 scénářů odpojení se skutečnými procesy (viz „Kde jsme skončili“) bez chyb skriptů; test zastavení postavy po pádu klienta ukázal rozdíl proti kódu bez opravy (zastaví se po ~0,25 s místo běhu dál). Menu: pole prázdné, příklad zmizí po kliknutí a vrátí se po odchodu z pole, adresa se neukládá. **Neověřeno:** ruční hraní, skutečná Wi-Fi/internet, Windows, aktualizace 0.1.3 → 0.1.4.
- **2026-11-04, fronta vstupů + ping/FPS (0.1.3):** 83/83 unit testů (nové `test_input_buffer`: pořadí/duplikáty/opakování, strop se sloučením skoku, dohánění trvalé fronty, žádné přeskočení při trhaném doručování; `test_net_stats` upraven na ping), lokalizace OK, 9/9 Python testů workflow. Síťový test host + klient s fake lag 0, 100/5 %, 200/10 % na novém i starém kódu (srovnání viz „Kde jsme skončili“), bez chyb skriptů. Screenshot: ukazatel čitelný vlevo dole. **Neověřeno:** ruční hraní, skutečná Wi-Fi/internet, Windows, aktualizace 0.1.2 → 0.1.3.
- **2026-11-04, F3 + 0.1.2:** 80/80 unit testů (nové: 3× `test_net_stats`, chyba predikce v `test_client_prediction`, jen nejnovější verze v `test_changelog`, sloupce CSV – ověřeno, že selže na chybném řádku), lokalizace 104 klíčů / 0 chybějících, 9/9 Python testů workflow. Síťový test host + klient s fake lag 0, 100/5 %, 200/10 %: bez chyb skriptů, hodnoty viz „Kde jsme skončili“. Screenshot ukazatele (okno 1280×720 na Retině): čitelné vlevo dole, nepřekrývá scoreboard. Menu: „Co je nového“ ukazuje jen aktuální verzi; generátor poznámek ověřen. **Neověřeno:** ruční hraní, skutečná Wi-Fi/internet, Windows, aktualizace 0.1.1 → 0.1.2 (ověřit po CI).
- **2026-11-04, kontrola po pullu `6978a62`:** 74/74 unit testů, lokalizace 96 / 0 chybějících, 9/9 Python testů workflow, síťový smoke test host+klient bez chyb skriptů. CI běhy `da40eac`, `2560ebb`, `6978a62` úspěšné; release `gun_game v0.1.1` (sestavení 29) ověřen přes GitHub API. Ruční hraní ani aktualizace z předchozí verze neověřeny.
- **2026-11-04, verze/vydávání:** import, 74/74 herních unit testů a lokalizace 96 klíčů / 0 chybějících OK. Izolovaná kopie projektu: 38 kontrol skutečných headless nástrojů (verze `0.1.1`, příští `0.1.2`, shodná macOS metadata, kanál stable, poznámky a commit odkaz, odmítnutí neplatné verze/argumentů bez přepsání souboru). YAML načten a ověřen main-only, jediný publikační krok, serializace, bez příkazů push/create. **9/9 lokálních testů publikace OK**: postupné verze, zákaz přeskakování/downgradu, pořadí uploadů a skrytí archivu, selhání API/uploadu/promoce, ověření latest a bezpečné opakování po částečné publikaci. Pouze mock `gh`, bez sítě. Git Bash vyžadoval schválenou výjimku sandboxu pro lokální testy. Skutečná publikace ani nová end-to-end instalace se neprováděla.
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
- **Verze (uživatel 2026-11-04):** jediné pokračující vydání, nyní `0.1.1`, pak `0.1.2` atd.; výslovná hodnota v projektu. Nahrazuje původní dva veřejné kanály. Interní URL `dev` zůstává kvůli starým klientům, nové hry používají stable/latest. Starý release se nemaže, jen skryje jako koncept po ověřeném úspěchu.
- **Changelog (uživatel 2026-11-04) je vydaný v sestavení 28.** Menu a poznámky používají společné texty.
- **Codex nesmí pushovat bez nového výslovného souhlasu (2026-11-04); nyní žádný souhlas není.** Všechny změny této session zůstávají bez commitu a bez pushe.
- **Skóre (2026-11-04):** zabití podle poslední účinné kulky před každou smrtí, bez timeoutu do pádu; série zabití stejného střelce do 2 s. Skóre pouze host, protokol 5. Silnější pistole 550 → 800. Oprava Wi-Fi sekání je nyní pouze v plánu.
- **M4:** vlastní pohyb se predikuje sdíleným motorem, opravy se přehrávají pouze během fyziky; odhoz, střelba a průběh zápasu zůstávají na hostu. Snapshot používá protokol 4.
- **Build jen při změně hry:** `paths-ignore` pro `docs/**`, `**/*.md`, `LICENSE`, `.gitignore` a `.gitattributes`. README a dokumentace tedy nemění verzi a nenutí hráče aktualizovat.
- **Nikdo nestojí na hlavě jiného hráče** (sklouznutí), **horní okraj arény je otevřený** a **život se ubírá až po 0,5 s mimo arénu.**
- **Aktualizace jen na vyšší číslo sestavení.** Nové verze používají stable/latest, dev klienti dostanou stejný update ze zachované URL. Manifest se nahrává poslední. Restart používá cestu zapamatovanou před výměnou.
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
- **Jediné aktualizované vydání stable/latest**, pevný historický tag `dev` pouze kvůli kompatibilitě adres. Bez posouvání tagů při dalších buildech.
- **Commity jen s dokumentací nevytvářejí nový build**, aby se zbytečně neměnila verze, se kterou se hráči spojují.
- **Windows se stahuje jako `.exe` přímo** (jeden soubor, PCK uvnitř). Mac a Linux zůstávají jako ZIP.
