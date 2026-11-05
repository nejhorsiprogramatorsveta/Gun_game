"""Exercise the publisher with a local gh mock; no GitHub requests are made."""

import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import sys
import unittest
import uuid


ROOT = Path(__file__).resolve().parents[1]
PUBLISHER = ROOT / "tools" / "publish_release.sh"
BASH = Path("C:/Program Files/Git/bin/bash.exe") if os.name == "nt" else Path(shutil.which("bash") or "/bin/bash")

MOCK_GH = r'''
import json, os, pathlib, sys
sys.stdout.reconfigure(newline="\n")
args = sys.argv[1:]
with open("calls.jsonl", "a", encoding="utf-8") as log:
    log.write(json.dumps(args) + "\n")
state_path = pathlib.Path("state.json")
state = json.loads(state_path.read_text(encoding="utf-8"))
if args[:3] == ["release", "view", "dev"]:
    event = "verification" if "--json" in args else "view"
elif args[:3] == ["release", "download", "dev"]:
    event = "download"
elif args[:3] == ["release", "upload", "dev"]:
    event = "manifest" if "version.json" in args else "assets"
elif args[:3] == ["release", "edit", "dev"]:
    event = "promotion"
elif args[:3] == ["release", "edit", "v0.1.0"]:
    event = "archive"
elif args[:2] == ["api", "--paginate"]:
    event = "legacy_query"
elif args[0] == "api" and args[1].endswith("/releases/latest"):
    event = "latest"
else:
    sys.exit("Unexpected gh command: " + repr(args))
if state.get("fail") == event:
    sys.exit("Mock failure: " + event)
if event == "view" and not state["dev_exists"]:
    sys.exit("Existing dev release not found")
if event == "download":
    destination = pathlib.Path(args[args.index("--output") + 1])
    if destination.exists() and "--clobber" not in args:
        sys.exit("Download output already exists")
    destination.write_text(json.dumps(state["manifest"]), encoding="utf-8")
elif event == "manifest":
    state["manifest"] = json.loads(pathlib.Path("version.json").read_text(encoding="utf-8"))
elif event == "promotion":
    state["promoted"] = True
elif event == "verification":
    print(json.dumps({"isDraft": False, "isPrerelease": state.get("bad_promotion", False)}))
elif event == "latest":
    print(state.get("latest", "dev"))
elif event == "legacy_query":
    if state["legacy"] == "published":
        print(123)
elif event == "archive":
    state["legacy"] = "draft"
state_path.write_text(json.dumps(state), encoding="utf-8")
'''


class ReleaseWorkflowTests(unittest.TestCase):
    def setUp(self):
        # Default mkdir permissions avoid restrictive Windows tempfile ACLs.
        self.work = ROOT / ".tools" / ("release-tests-" + uuid.uuid4().hex)
        self.work.mkdir(parents=True)
        self.bin_dir = self.work / "bin"
        self.bin_dir.mkdir()
        (self.work / "dist").mkdir()
        for name in ("gun_game-windows.exe", "gun_game-macos.zip", "gun_game-linux.zip"):
            (self.work / "dist" / name).write_bytes(b"mock game")
        (self.work / "notes.md").write_text("Release notes\n", encoding="utf-8")
        (self.work / "mock_gh.py").write_text(MOCK_GH, encoding="utf-8")
        python = shlex.quote(sys.executable.replace("\\", "/"))
        self._wrapper("python3", "exec " + python + ' "$@"\n')
        self._wrapper("gh", "exec " + python + ' mock_gh.py "$@"\n')
        self._wrapper("git", 'echo "Publisher must not invoke git" >&2\nexit 99\n')
        self.state = {"dev_exists": True, "legacy": "published", "promoted": False,
                      "manifest": {"version": "0.1.0", "build": 28}}
        self._write_state()
        self._set_build("0.1.1", 29)

    def tearDown(self):
        shutil.rmtree(self.work)

    def _wrapper(self, name, body):
        path = self.bin_dir / name
        path.write_text("#!/usr/bin/env bash\n" + body, encoding="utf-8", newline="\n")
        path.chmod(0o755)

    def _write_state(self):
        (self.work / "state.json").write_text(json.dumps(self.state), encoding="utf-8")

    def _read_state(self):
        return json.loads((self.work / "state.json").read_text(encoding="utf-8"))

    def _set_build(self, version, build):
        info = {"version": version, "build": build, "commit": "abc1234", "channel": "stable"}
        (self.work / "build_info.json").write_text(json.dumps(info), encoding="utf-8")
        (self.work / "version.json").write_text(json.dumps(info), encoding="utf-8")

    def _run(self, extra_env=None):
        env = os.environ.copy()
        env.pop("GAME_TITLE", None)  # CI sets it for the whole job; tests decide explicitly
        env.update({"GAME_NAME": "gun_game", "GITHUB_REPOSITORY": "example/game",
                    "GH_TOKEN": "local-mock-token", "PATH": str(self.bin_dir) + os.pathsep + env["PATH"]})
        env.update(extra_env or {})
        result = subprocess.run([str(BASH), str(PUBLISHER).replace("\\", "/")], cwd=self.work,
                                env=env, capture_output=True, text=True, timeout=30)
        self.assertNotIn(env["GH_TOKEN"], result.stdout + result.stderr)
        self.assertNotIn("Publisher must not invoke git", result.stderr)
        self.assertNotIn("couldn't create signal pipe", result.stderr)
        return result

    def _calls(self):
        path = self.work / "calls.jsonl"
        return [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines()] if path.exists() else []

    def _mutations(self):
        return [args for args in self._calls() if args[:2] in (["release", "upload"], ["release", "edit"])]

    def test_success_uploads_assets_then_manifest_then_promotes_and_archives(self):
        result = self._run()
        self.assertEqual(result.returncode, 0, result.stderr)
        mutations = self._mutations()
        self.assertEqual([args[:3] for args in mutations], [
            ["release", "upload", "dev"], ["release", "upload", "dev"],
            ["release", "edit", "dev"], ["release", "edit", "v0.1.0"]])
        for filename in ("windows.exe", "macos.zip", "linux.zip"):
            self.assertTrue(any(arg.endswith(filename) for arg in mutations[0]))
        self.assertNotIn("version.json", mutations[0])
        self.assertIn("version.json", mutations[1])
        for option in ("--draft=false", "--prerelease=false", "--latest"):
            self.assertIn(option, mutations[2])
        self.assertEqual(mutations[2][mutations[2].index("--title") + 1], "gun_game v0.1.1")
        self.assertEqual(self._read_state()["legacy"], "draft")

    def test_release_title_uses_the_display_name_when_set(self):
        result = self._run({"GAME_TITLE": "Dojo Knockout"})
        self.assertEqual(result.returncode, 0, result.stderr)
        promotion = self._mutations()[2]
        self.assertEqual(promotion[promotion.index("--title") + 1], "Dojo Knockout v0.1.1")
        for filename in ("gun_game-windows.exe", "gun_game-macos.zip", "gun_game-linux.zip"):
            self.assertTrue(any(arg.endswith(filename) for arg in self._mutations()[0]), "file names keep GAME_NAME")

    def test_missing_dev_or_failed_manifest_download_never_mutates(self):
        for failure in ("missing_dev", "download"):
            with self.subTest(failure=failure):
                self.state["dev_exists"] = failure != "missing_dev"
                self.state["fail"] = "download" if failure == "download" else ""
                self._write_state()
                result = self._run()
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(self._mutations(), [])

    def test_rejected_versions_and_builds_fail_before_upload(self):
        for version, build in [("0.1.1", 27), ("0.1.1", 28), ("0.1.0", 29),
                               ("0.0.9", 29), ("0.1.9", 29), ("bad", 29)]:
            with self.subTest(version=version, build=build):
                self._set_build(version, build)
                result = self._run()
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(self._mutations(), [])

    def test_patch_minor_and_major_increment_numerically(self):
        for old, new in [("0.1.9", "0.1.10"), ("0.1.9", "0.2.0"), ("0.1.9", "1.0.0")]:
            with self.subTest(old=old, new=new):
                self.state["manifest"] = {"version": old, "build": 28}
                self._write_state()
                self._set_build(new, 29)
                result = self._run()
                self.assertEqual(result.returncode, 0, result.stderr)

    def test_upload_promotion_or_verification_failure_keeps_legacy_published(self):
        for failure in ("assets", "manifest", "promotion", "verification"):
            with self.subTest(failure=failure):
                self.state["fail"] = failure
                self._write_state()
                result = self._run()
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(self._read_state()["legacy"], "published")
                self.assertFalse(any(args[:3] == ["release", "edit", "v0.1.0"] for args in self._calls()))

    def test_failed_promotion_can_retry_after_manifest_upload(self):
        self.state["fail"] = "promotion"
        self._write_state()
        self.assertNotEqual(self._run().returncode, 0)
        self.state = self._read_state()
        self.assertEqual(self.state["manifest"]["version"], "0.1.1")
        self.state.pop("fail")
        self._write_state()
        result = self._run()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self._read_state()["legacy"], "draft")

    def test_retry_is_idempotent_and_never_creates_releases(self):
        self.assertEqual(self._run().returncode, 0)
        self.assertEqual(self._run().returncode, 0)
        archives = [args for args in self._calls() if args[:3] == ["release", "edit", "v0.1.0"]]
        self.assertEqual(len(archives), 1)
        self.assertFalse(any(args[:2] == ["release", "create"] for args in self._calls()))

    def test_missing_or_already_draft_legacy_is_untouched(self):
        for legacy in ("missing", "draft"):
            with self.subTest(legacy=legacy):
                self.state["legacy"] = legacy
                self._write_state()
                result = self._run()
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertFalse(any(args[:3] == ["release", "edit", "v0.1.0"] for args in self._calls()))

    def test_legacy_api_error_and_unsuccessful_promotion_are_not_ignored(self):
        for updates in ({"fail": "legacy_query"}, {"bad_promotion": True},
                        {"latest": "v0.1.0"}, {"fail": "latest"}):
            with self.subTest(updates=updates):
                self.state.pop("fail", None)
                self.state.pop("bad_promotion", None)
                self.state.pop("latest", None)
                self.state.update(updates)
                self._write_state()
                result = self._run()
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(self._read_state()["legacy"], "published")


if __name__ == "__main__":
    unittest.main()
