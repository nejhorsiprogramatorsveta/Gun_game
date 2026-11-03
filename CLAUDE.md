# gun_game – project guide for Claude Code

## Session start (mandatory)
1. Read this file and docs/PROGRESS.md (docs/PLAN.md = approved plan, read relevant sections). 2. `git status` + `git log --oneline -10` (once git exists).
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
- Setup dev env (once): `tools/setup_env.sh` (add `--with-templates` for local exports)
- Run: `tools/godot --path .`   - Two local instances: run twice, one Host, one Join 127.0.0.1
- Tests: `tools/godot --headless --path . -s tests/run_tests.gd`
- Loc check: `tools/godot --headless --path . -s tools/check_localization.gd`
- Export: `tools/godot --headless --path . --export-release "<preset>" <out>`
(Test/loc/export commands become valid during M1; update this section when they are verified.)

## Architecture (planned key files – see docs/PLAN.md section F)
src/autoload/session.gd, src/net/*, src/match/match_controller.gd, src/player/player_motor.gd, data/*.tres

## Rules
Host decides all gameplay. RPC only in session.gd / src/net/ / match_net.gd. Connection only via src/net/connectors/.
Scripts < ~300 lines, one responsibility. No new autoloads/addons/assets without approval. Record assets in CREDITS.md.
Never claim something works unless tested.
