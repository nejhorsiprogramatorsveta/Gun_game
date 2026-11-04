# gun_game – project guide for Claude Code

## Session start (mandatory)
1. Read this file and docs/PROGRESS.md (docs/PLAN.md = approved plan, read relevant sections). 2. `git status` + `git log --oneline -10` (once git exists).
3. Briefly confirm the current state in Czech (milestone, last finished task, next step).

## Resume protocol ("přečti si progress a pokračuj")
If the user only says to read progress and continue: do the session start, then execute exactly the task in
PROGRESS.md "Další krok" – nothing more. If "Další krok" is unclear, blocked, or needs a user decision, ask instead of guessing.
If PROGRESS.md and git disagree (e.g. uncommitted changes, task half-done), report it first.

## End-of-task protocol (mandatory after EVERY task, also when interrupted or unfinished)
Codex has its own rules in codex.md (loaded via AGENTS.md): it must NEVER push; the user pushes its work.

1. Update docs/PROGRESS.md: "Kde jsme skončili" (what part of which milestone is done / half-done, uncommitted files),
   "Další krok" (one concrete next task, specific enough to start without asking), "Poslední změny", "Stav testů", "Známé problémy".
2. Claude Code: commit (Conventional Commits) and PUSH to origin main yourself – the user allowed this permanently
   (2026-11-03). Only push finished, tested work; then check that the GitHub Actions run succeeded.
3. Give the user a Czech overview: which part of the plan (milestone/step) was completed, what remains in the milestone,
   changed files, how to test, what was NOT tested, commit hash + CI result.
4. Stop. Do not start the next step on your own.
If the user says "ulož progress", do step 1 immediately.

## Communication
Respond to the user in Czech. Code, identifiers, commits in English (Conventional Commits).
Player-facing text only via tr() keys in localization/translations.csv.

## Purpose
Online 2–4 player 2D knockback arena shooter (original, Gun Mayhem-like mechanics). Host-authoritative listen server.
Friends (mainly Windows) download ZIP from GitHub Releases. MVP: keyboard only.

## Stack
Godot 4.7.2-stable (non-.NET), GDScript (static typing), Compatibility renderer.

## Commands (pinned Godot lives in .tools/, never use a system-wide godot)
All verified in M1 on macOS arm64:
- Setup dev env (once): `tools/setup_env.sh` (add `--with-templates` for local exports, ~1 GB)
- Import (after clean clone or new assets; 1st run logs harmless translation errors): `tools/godot --headless --path . --import`
- Run game: `tools/godot --path .`   Editor: `tools/godot --path . --editor`
- Tests: `tools/godot --headless --path . -s tests/run_tests.gd` (exit 1 on failure)
- Loc check: `tools/godot --headless --path . -s tools/check_localization.gd` (exit 1 on missing key)
- Release notes (local preview): `tools/godot --headless --path . -s tools/write_release_notes.gd -- --output=res://.tools/notes.md`
- Export: `tools/godot --headless --path . --export-release "<Windows Desktop|macOS|Linux>" build/<os>/<file>`
- Smoke tests of scenes: write a throwaway `extends SceneTree` script (outside the repo) and run it with `-s`;
  `Input.action_press()` simulates keys. Run without `--headless` to take screenshots (opens a window).
- Network smoke test without UI: throwaway SceneTree scripts that call `root.get_node("Session").host_game()/join_game()`
  (autoloads ARE loaded with `-s`), run as separate background processes on 127.0.0.1, logs to files (not pipes).
  `-- --fake-commit=abc` (debug builds only) simulates a different build for the version-mismatch path.
- Fake network (debug builds): `tools/godot --path . -- --fake-lag=100 --fake-loss=5` (adds RTT/loss to match traffic of that instance).
- CI: .github/workflows/build.yml (push main -> update the ONE existing release, title `gun_game vX.Y.Z`).
- Public version comes ONLY from `application/config/version` in project.godot (currently 0.1.1, next 0.1.2).
  Bump it explicitly before each new game release; CI permits only the next patch/minor/major and rejects lower builds.
  A retry of the same version/build is allowed. Docs-only changes still do not publish.

## Architecture (see docs/ARCHITECTURE.md for what exists, docs/PLAN.md section F for the target)
Existing: src/core/{build_info,content_db}.gd, src/player/{player_motor,input_frame,player,client_prediction}.gd,
src/arenas/{arena,platform}.gd, src/match/match_controller.gd, src/ui/main_menu.gd, data/*.tres,
src/autoload/session.gd (autoload Session: host/join, auth handshake, lobby players),
src/autoload/settings.gd (autoload Settings: name, last address), src/ui/lobby.gd,
src/net/connectors/{connector,enet_direct_connector}.gd, src/net/{handshake,net_codec}.gd,
src/match/match_net.gd (only match RPCs), src/player/remote_interpolator.gd, src/net/lag_simulator.gd.
src/combat/{combat_rules,projectile,weapon_system}.gd, src/data_types/weapon_data.gd, data/weapons/*.tres.
src/ui/{match_hud,results}.gd (lives/K/D scoreboard, kill notices, results -> same lobby, PLAN.md T.1/T.4).
src/match/match_score.gd (host-owned last-bullet attribution and 2-second multikill window).
src/core/updater.gd (auto-update; test with debug export + `-- --update-test=URL`, PLAN.md I.8).
M4 movement prediction is implemented: clients immediately simulate only their own player through the shared PlayerMotor,
retain up to 120 unacknowledged inputs/states, restore authoritative state, and replay pending inputs.
Snapshot protocol 5 carries complete motor memory (floor contact, previous buttons, remaining jumps, jump/drop timers)
alongside position/velocity, last_seq and kills/deaths: 6-byte header + 33 bytes/player. Input packets remain 14 bytes.
MatchController queues the newest snapshot and reconciles ONLY in _physics_process before the next local input;
move_and_slide() must use the physics delta during replay. Remote players still interpolate with a 100 ms delay.
Small corrections use a visual offset; combat, knockback, recoil, respawns, countdown and lives remain host-authoritative.
Changelog "Co je nového" shows ONLY the newest (highest) patch version (user 2026-11-04); release notes the same.
Changelog is implemented: data/changelog.tres + localization CSV are shared by src/core/changelog.gd,
the offline menu "Co je nového", and tools/write_release_notes.gd.
Build 0 in the data resolves to this source tree's actual BuildInfo; before the next gameplay change,
archive that entry under its published version/build and add a new current entry. Do not guess the next build number.
Next (M4): debug RTT/correction measurements (see PROGRESS.md); keep Wi-Fi fixes deferred until separately requested.
The user replaced the previous dev/stable split (2026-11-04): keep ONE existing release `dev`,
promoted to stable/latest, and change its visible version/title and assets. The `dev` slug is retained for
installed clients. Do not create releases or move/push tags. Hide old `v0.1.0` as a draft only after successful
publication and verification. Never delete it. New builds use channel stable; old dev clients still update
from the unchanged dev URL, then use latest. Game files upload before version.json; build numbers keep growing.
The fixed dev tag's automatic source archives remain historical; release notes link to the actual build commit.
User report (2026-11-04): severe stutter on the same Wi-Fi for clients while the host remains smooth.
Root cause is unmeasured. PLAN.md M4.1 records investigation and later fixes; do not change networking,
movement prediction or interpolation to address it in the current combat/scoreboard task.
Commit *.gd.uid and *.import files; *.translation, .godot/, build/, build_info.json are generated (gitignored).

## Design decisions that override the original brief (details: docs/PLAN.md)
- AIMING: shots go toward the MOUSE CURSOR (not horizontal like Gun Mayhem). Fire = left mouse button.
  InputFrame/network input carries an aim angle; character faces the cursor; recoil opposite to aim.
- ART: whole game in detailed pixel-art style (Japanese samurai/ninja theme), see PLAN.md section Q.
  Reference image in art_reference/ is third-party art: style reference only, never copy/commit/ship it.
- WINDOWS TESTING: manual tests on Windows are deferred to the END of the project unless the user says
  otherwise. Do not ask about them each session; just keep them listed in PROGRESS.md.

## Rules
SECURITY (user requirement): every network change must follow docs/PLAN.md section S (no object decoding,
server_relay off, validate/size-limit all input, room code to join, NO UPnP/port opening, never show/share the public IP; internet play = Tailscale).
Code must run on Windows, macOS and Linux: no OS-specific APIs/paths in game code (use res:// and user://,
Godot APIs only); shell scripts in tools/ are dev-only (Windows devs would use Git Bash/WSL).
Host decides all gameplay. RPC only in session.gd / src/net/ / match_net.gd. Connection only via src/net/connectors/.
Scripts < ~300 lines, one responsibility. No new autoloads/addons/assets without approval. Record assets in CREDITS.md.
Never claim something works unless tested.
