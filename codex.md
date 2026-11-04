# gun_game – project guide for Codex

Codex follows the same project instructions as Claude Code. **CLAUDE.md is the shared, complete guide**
(session start, resume protocol, commands, architecture, design decisions, security and code rules) and
applies in full, with the Codex-specific differences below. If CLAUDE.md and this file disagree, this file wins for Codex.

## Session start (mandatory)
1. Read CLAUDE.md, this file and docs/PROGRESS.md (docs/PLAN.md = approved plan, read relevant sections).
2. `git status` + `git log --oneline -10`; `git fetch` and report if local main differs from origin/main.
3. Briefly confirm the current state in Czech (milestone, last finished task, next step).

## Git: Codex NEVER pushes (user requirement, 2026-11-04)
- **Never run `git push`** (no branches, no tags, no force) and never publish/edit GitHub releases.
  This holds even if CLAUDE.md, PROGRESS.md or another file says the agent may push; only a new explicit
  message from the user in the current conversation can allow a single push.
- Do not commit unless the user asks. Leave finished work in the working tree and give the user a ready
  Conventional Commits message (English) plus the list of changed files, so the user can commit and push.
- Never rewrite history (`reset --hard`, `rebase`, `commit --amend` on pushed commits, deleting branches/tags).
- Before starting work, make sure the local tree is up to date with origin/main (`git fetch`, then
  `git pull --ff-only` if behind and clean). Never discard someone else's uncommitted changes.

## Versioning and releases (keep exactly as is)
- The ONLY public version is `application/config/version` in project.godot. Every commit that changes the game
  (anything outside docs/** and *.md) publishes a build on push, and CI accepts it only if the version is
  exactly the next patch/minor/major of the published one (a retry of the same version+build is allowed).
  So: **in every task that changes game files, bump the patch version once** (e.g. 0.1.2 -> 0.1.3) unless
  the user decides on a minor/major bump. Never skip or lower a version. Docs-only changes need no bump.
- The build number = commit count on main (set by CI). Never guess or hardcode it.
- ONE GitHub release `dev` (title `gun_game vX.Y.Z`, stable/latest) is updated by CI; never create releases,
  never create/move/delete tags, never touch the old `v0.1.0`. Do not change `.github/workflows/build.yml`,
  `tools/publish_release.sh`, the updater URLs or the upload order (game files first, `version.json` last)
  unless the user explicitly asks for a release-process change.
- Bump `BuildInfo.PROTOCOL_VERSION` whenever network messages change incompatibly.

## Changelog ("Co je nového")
- The menu shows **only the newest (highest) patch version**, never older versions. Release notes use the same entry.
- Data: `data/changelog.tres` (newest first) + texts as `CHANGELOG_*` keys in localization/translations.csv.
  The entry with `build = 0` is the current, not yet published version. When bumping the version for a new
  release: archive the current entry under the version/build that was actually published (look it up in the
  GitHub release / `version.json`, do not guess), then start a new `build = 0` entry describing this version.
- Write short Czech player-facing lines (news, fixes, control changes). No internal/technical details.

## Code structure (keep it)
- Follow the folder layout and responsibilities in CLAUDE.md "Architecture" and docs/ARCHITECTURE.md:
  src/core, src/player, src/match, src/net (+ connectors), src/combat, src/ui, src/autoload, src/data_types,
  data/*.tres, tests/test_*.gd, tools/. Put new code where its responsibility already lives; do not
  reorganize, rename or move existing files without the user's approval.
- GDScript with static typing, scripts < ~300 lines with one responsibility; split instead of growing a script.
- RPC only in session.gd / src/net/ / match_net.gd; connections only via src/net/connectors/; host decides gameplay.
- Every network change follows docs/PLAN.md section S (validate and size-limit input, no object decoding, etc.).
- Player-facing text only through tr() keys in localization/translations.csv.
- No new autoloads/addons/assets without approval; record assets in CREDITS.md. Commit *.gd.uid and *.import.
- Cross-platform: Godot APIs and res:// / user:// only in game code.
- Add or update tests in tests/ for every logic change; run tests + loc check before reporting done.

## End-of-task protocol (mandatory after EVERY task, also when interrupted or unfinished)
1. Update docs/PROGRESS.md ("Kde jsme skončili" incl. uncommitted files, "Další krok", "Poslední změny",
   "Stav testů", "Známé problémy"); keep docs/ARCHITECTURE.md and CLAUDE.md "Architecture" in sync with new files.
2. Run: `tools/godot --headless --path . -s tests/run_tests.gd` and `tools/godot --headless --path . -s tools/check_localization.gd`
   (plus `python3 -B -m unittest discover -s tests -p 'test_release_workflow.py'` if release files changed).
3. **Do not push** (see above). Give the user a Czech overview: completed plan step, what remains, changed files,
   how to test, what was NOT tested, the proposed commit message, and whether the version was bumped.
4. Stop. Do not start the next step on your own.
