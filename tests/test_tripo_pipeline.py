import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import unittest
from unittest import mock


PROJECT_ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = PROJECT_ROOT / "scripts" / "tripo" / "generate.py"
SPEC = importlib.util.spec_from_file_location("tripo_generate", MODULE_PATH)
TRIPO = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(TRIPO)


ASSET_ID = "wd_black_tree_hero_01"


def valid_glb_bytes():
    metadata = json.dumps({"asset": {"version": "2.0"}}, separators=(",", ":")).encode()
    metadata += b" " * ((4 - len(metadata) % 4) % 4)
    return (
        struct.pack("<4sII", b"glTF", 2, 20 + len(metadata))
        + struct.pack("<II", len(metadata), 0x4E4F534A)
        + metadata
    )


class TripoPipelineTests(unittest.TestCase):
    def setUp(self):
        self.tempdir = tempfile.TemporaryDirectory()
        root = Path(self.tempdir.name)
        self.old_project_root = TRIPO.PROJECT_ROOT
        self.old_records = TRIPO.RECORDS_ROOT
        self.old_source = TRIPO.SOURCE_ROOT
        TRIPO.PROJECT_ROOT = root
        TRIPO.RECORDS_ROOT = root / "records"
        TRIPO.SOURCE_ROOT = root / "source"

    def tearDown(self):
        TRIPO.PROJECT_ROOT = self.old_project_root
        TRIPO.RECORDS_ROOT = self.old_records
        TRIPO.SOURCE_ROOT = self.old_source
        self.tempdir.cleanup()

    def test_dry_run_needs_no_key_and_preserves_eight_asset_manifest(self):
        output = io.StringIO()
        with mock.patch.dict(os.environ, {}, clear=True), contextlib.redirect_stdout(output):
            TRIPO.main(["submit", "--dry-run"])
        lines = [json.loads(line) for line in output.getvalue().splitlines()]
        self.assertEqual(len(lines), 8)
        self.assertTrue(all(line["status"] == "dry_run" for line in lines))
        self.assertIn("negative_prompt", lines[0]["request"])
        self.assertEqual(list(TRIPO.RECORDS_ROOT.glob("**/*")), [])

    def test_request_is_atomic_and_resubmission_is_guarded(self):
        response = {"task_id": "task-once"}
        with mock.patch.object(TRIPO, "api_request", return_value=response) as request:
            with contextlib.redirect_stdout(io.StringIO()):
                TRIPO.main(["submit", ASSET_ID])
            self.assertEqual(request.call_count, 1)
            with contextlib.redirect_stdout(io.StringIO()):
                TRIPO.main(["submit", ASSET_ID])
            self.assertEqual(request.call_count, 1)

        asset = TRIPO.read_assets()[0]
        paths = TRIPO.paths_for(asset)
        paths["submission"].unlink()
        with mock.patch.object(TRIPO, "api_request", side_effect=AssertionError("must not retry")):
            with self.assertRaisesRegex(RuntimeError, "Ambiguous submission state"):
                TRIPO.main(["submit", ASSET_ID])

        request_record = TRIPO.read_json(paths["request"])
        request_record["prompt"] = "changed locally"
        TRIPO.write_json(paths["request"], request_record, mode=0o600)
        with self.assertRaisesRegex(RuntimeError, "Immutable request mismatch"):
            TRIPO.main(["submit", ASSET_ID])

    def test_api_failure_does_not_print_secret_or_remote_body(self):
        secret = "test-only-secret-never-printed"
        with mock.patch.dict(os.environ, {"TRIPO_API_KEY": secret}, clear=True):
            failed = subprocess.CompletedProcess(
                ["curl"], 22, stdout="", stderr=secret + " provider body"
            )
            with mock.patch.object(TRIPO.subprocess, "run", return_value=failed):
                with self.assertRaises(RuntimeError) as raised:
                    TRIPO.api_request("/account/balance")
        self.assertNotIn(secret, str(raised.exception))
        self.assertNotIn("provider body", str(raised.exception))

    def test_signed_url_is_stdin_only_and_glb_is_validated(self):
        destination = TRIPO.SOURCE_ROOT / ASSET_ID / "model.glb"
        signed_url = "https://cdn.example.invalid/model.glb?signature=not-for-argv"

        def fake_download(args, input, **kwargs):
            self.assertNotIn(signed_url, args)
            self.assertIn(signed_url, input)
            part = destination.with_name(destination.name + ".part")
            part.parent.mkdir(parents=True, exist_ok=True)
            part.write_bytes(valid_glb_bytes())
            return subprocess.CompletedProcess(args, 0, stdout="", stderr="")

        with mock.patch.object(TRIPO.subprocess, "run", side_effect=fake_download):
            TRIPO.download_glb(signed_url, destination, 30)
        self.assertTrue(destination.exists())
        TRIPO.validate_glb(destination)

        with self.assertRaisesRegex(RuntimeError, "non-HTTPS"):
            TRIPO.download_glb("http://cdn.example.invalid/model.glb", destination, 30)

    def test_invalid_glb_never_becomes_source_asset(self):
        destination = TRIPO.SOURCE_ROOT / ASSET_ID / "model.glb"

        def fake_download(args, input, **kwargs):
            part = destination.with_name(destination.name + ".part")
            part.parent.mkdir(parents=True, exist_ok=True)
            part.write_bytes(b"not a glb")
            return subprocess.CompletedProcess(args, 0, stdout="", stderr="")

        with mock.patch.object(TRIPO.subprocess, "run", side_effect=fake_download):
            with self.assertRaisesRegex(RuntimeError, "valid GLB"):
                TRIPO.download_glb("https://cdn.example.invalid/model.glb", destination, 30)
        self.assertFalse(destination.exists())
        self.assertFalse(destination.with_name(destination.name + ".part").exists())

    def test_poll_records_safe_status_and_audit_without_signed_url(self):
        asset = TRIPO.read_assets()[0]
        paths = TRIPO.paths_for(asset)
        TRIPO.write_json(
            paths["submission"],
            {"asset_id": ASSET_ID, "task_id": "task-safe"},
            mode=0o600,
        )
        signed_url = "https://cdn.example.invalid/model.glb?signature=never-record"

        def fake_download(url, destination, timeout_seconds):
            self.assertEqual(url, signed_url)
            self.assertEqual(timeout_seconds, 900)
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes(valid_glb_bytes())

        with mock.patch.object(
            TRIPO, "api_request", return_value={
                "status": "success",
                "progress": 100,
                "credits_consumed": 3,
                "output": {"model_url": signed_url, "remote_body": "not recorded"},
            }
        ), mock.patch.object(TRIPO, "download_glb", side_effect=fake_download):
            with contextlib.redirect_stdout(io.StringIO()):
                TRIPO.command_poll()

        task = TRIPO.read_json(paths["task"])
        audit = TRIPO.read_json(paths["audit"])
        self.assertEqual(task["task_id"], "task-safe")
        self.assertEqual(task["credits_consumed"], 3)
        self.assertNotIn("signature", json.dumps(task))
        self.assertNotIn("signature", json.dumps(audit))
        self.assertTrue(paths["source"].exists())

    def test_missing_key_is_rejected_before_curl(self):
        with mock.patch.dict(os.environ, {}, clear=True):
            with mock.patch.object(TRIPO.subprocess, "run") as run:
                with self.assertRaisesRegex(RuntimeError, "TRIPO_API_KEY is unset"):
                    TRIPO.api_request("/account/balance")
        run.assert_not_called()

    def test_curl_ignores_user_configuration(self):
        args = TRIPO._curl_args(30)
        self.assertEqual(args[0:2], ["curl", "-q"])


if __name__ == "__main__":
    unittest.main()
