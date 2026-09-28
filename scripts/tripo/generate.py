#!/usr/bin/env python3
"""Secure, offline-first Tripo batch wrapper for Weeping Dunes.

The API key is read only from TRIPO_API_KEY. Signed download URLs stay in
memory and are passed to curl through stdin; neither URLs nor remote response
bodies are written to repository records.

Python 3.9 is the canonical runtime. The Tripo endpoint and request schema in
this repository remain unverified until the public documentation can be
reached; use --dry-run before any live submission.
"""

from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional, Sequence
from urllib.parse import quote, urlparse


PROJECT_ROOT = Path(__file__).resolve().parents[2]
MANIFEST_PATH = Path(__file__).with_name("assets.json")
RECORDS_ROOT = PROJECT_ROOT / "generation-records" / "tripo"
SOURCE_ROOT = PROJECT_ROOT / "assets" / "source"
BASE_URL = "https://openapi.tripo3d.ai/v3"
MODEL = os.environ.get("TRIPO_MODEL", "v3.1-20260211")
NEGATIVE_PROMPT = (
    "low poly, cartoon, toy, melted shapes, blurry texture, simple geometry, "
    "pedestal, baked hard shadows, text, watermark, duplicate parts, floating "
    "geometry, disconnected parts, extra limbs, malformed topology"
)
CURL_CONNECT_TIMEOUT_SECONDS = 20
CURL_API_TIMEOUT_SECONDS = 90
CURL_DOWNLOAD_TIMEOUT_SECONDS = 300
EXPECTED_ASSET_COUNT = 8


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def read_assets() -> List[Dict[str, Any]]:
    try:
        value = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    except (OSError, ValueError) as exc:
        raise RuntimeError("Unable to read the Tripo asset manifest") from exc
    if not isinstance(value, list) or len(value) != EXPECTED_ASSET_COUNT:
        raise RuntimeError("The Tripo manifest must contain exactly 8 assets")
    ids = []
    for asset in value:
        if not isinstance(asset, dict) or not isinstance(asset.get("id"), str):
            raise RuntimeError("Each Tripo manifest entry must have an id")
        if asset["id"] in ids:
            raise RuntimeError("The Tripo manifest contains duplicate asset ids")
        ids.append(asset["id"])
    return value


def _atomic_replace(temp_path: Path, destination: Path) -> None:
    os.replace(str(temp_path), str(destination))
    # The rename is atomic. Best-effort directory fsync makes the rename
    # durable on filesystems that support opening a directory.
    try:
        directory_fd = os.open(str(destination.parent), os.O_RDONLY)
    except OSError:
        return
    try:
        os.fsync(directory_fd)
    except OSError:
        pass
    finally:
        os.close(directory_fd)


def write_json(path: Path, value: Any, mode: Optional[int] = None) -> None:
    """Write JSON atomically without ever exposing a partial record."""
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary_name: Optional[str] = None
    try:
        descriptor, temporary_name = tempfile.mkstemp(
            prefix="." + path.name + ".", dir=str(path.parent)
        )
        with os.fdopen(descriptor, "w", encoding="utf-8") as stream:
            stream.write(json.dumps(value, ensure_ascii=False, indent=2) + "\n")
            stream.flush()
            os.fsync(stream.fileno())
        temporary_path = Path(temporary_name)
        if mode is not None:
            os.chmod(str(temporary_path), mode)
        _atomic_replace(temporary_path, path)
        temporary_name = None
    finally:
        if temporary_name is not None:
            try:
                Path(temporary_name).unlink()
            except FileNotFoundError:
                pass


def read_json(path: Path) -> Any:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError) as exc:
        raise RuntimeError("A local Tripo record is unreadable") from exc


def paths_for(asset: Dict[str, Any]) -> Dict[str, Path]:
    asset_id = asset["id"]
    record_dir = RECORDS_ROOT / asset_id
    source_dir = SOURCE_ROOT / asset_id
    return {
        "request": record_dir / "request.json",
        "submission": record_dir / "submission.json",
        "task": record_dir / "task.json",
        "audit": record_dir / "audit.json",
        "source": source_dir / "model.glb",
        "source_dir": source_dir,
    }


def request_for(asset: Dict[str, Any], assets: List[Dict[str, Any]]) -> Dict[str, Any]:
    try:
        asset_index = assets.index(asset)
    except ValueError as exc:
        raise RuntimeError("Asset is not present in the Tripo manifest") from exc
    return {
        "model": MODEL,
        "geometry_quality": "detailed",
        "face_limit": asset["face_limit"],
        "texture": True,
        "pbr": True,
        "texture_quality": asset["texture_quality"],
        "delight": True,
        "auto_size": True,
        "smart_low_poly": False,
        "quad": False,
        "prompt": asset["prompt"],
        "negative_prompt": NEGATIVE_PROMPT,
        "model_seed": 9212026 + asset_index,
    }


def runtime_budget_seconds(asset: Dict[str, Any]) -> int:
    """Return a local planning budget, not an unverified API field."""
    value = asset.get("runtime_budget_seconds", 600)
    if not isinstance(value, int) or value <= 0:
        raise RuntimeError("Invalid runtime budget in the Tripo manifest")
    return value


def selected_assets(assets: List[Dict[str, Any]], ids: Sequence[str]) -> List[Dict[str, Any]]:
    if not ids:
        return assets
    by_id = {asset["id"]: asset for asset in assets}
    unknown = [asset_id for asset_id in ids if asset_id not in by_id]
    if unknown:
        raise RuntimeError("Unknown asset id: " + ", ".join(unknown))
    return [by_id[asset_id] for asset_id in ids]


def _api_key() -> str:
    api_key = os.environ.get("TRIPO_API_KEY")
    if not api_key:
        raise RuntimeError(
            "TRIPO_API_KEY is unset; credentials are accepted only through the process environment"
        )
    return api_key


def _curl_args(timeout_seconds: int) -> List[str]:
    return [
        "curl",
        "-q",
        "-fsS",
        "--connect-timeout",
        str(CURL_CONNECT_TIMEOUT_SECONDS),
        "--max-time",
        str(timeout_seconds),
        "--proto",
        "=https",
        "--proto-redir",
        "=https",
        "--config",
        "-",
    ]


def api_request(endpoint: str, body: Optional[Dict[str, Any]] = None) -> Any:
    """Call the unverified endpoint without putting the key in argv or logs."""
    api_key = _api_key()
    config = [
        "url = " + json.dumps(BASE_URL + endpoint),
        "header = " + json.dumps("Authorization: Bearer " + api_key),
        'header = "Content-Type: application/json"',
    ]
    if body is not None:
        config.append("data = " + json.dumps(json.dumps(body, ensure_ascii=False)))
    result = subprocess.run(
        _curl_args(CURL_API_TIMEOUT_SECONDS),
        input="\n".join(config) + "\n",
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        check=False,
    )
    if result.returncode != 0:
        # Do not include stderr or a remote error body: either can contain
        # provider data, signed material, or accidental credential echoes.
        raise RuntimeError("Tripo request failed; remote response was not recorded")
    try:
        payload = json.loads(result.stdout or "")
    except (TypeError, ValueError) as exc:
        raise RuntimeError("Tripo returned a non-JSON response") from exc
    if not isinstance(payload, dict):
        raise RuntimeError("Tripo returned an unsupported response")
    if payload.get("code"):
        raise RuntimeError("Tripo rejected the request; remote response was not recorded")
    return payload.get("data", payload)


def command_balance() -> None:
    data = api_request("/account/balance")
    if not isinstance(data, dict):
        raise RuntimeError("Tripo balance response was not an object")
    print(json.dumps({"credits": data.get("credits", data.get("balance"))}))


def _ensure_immutable_request(path: Path, request: Dict[str, Any]) -> None:
    if not path.exists():
        write_json(path, request, mode=0o600)
        return
    existing = read_json(path)
    if existing != request:
        raise RuntimeError(
            "Immutable request mismatch for this asset; refusing to resubmit"
        )


def command_dry_run(ids: Sequence[str]) -> None:
    assets = read_assets()
    for asset in selected_assets(assets, ids):
        print(
            json.dumps(
                {
                    "id": asset["id"],
                    "status": "dry_run",
                    "runtime_budget_seconds": runtime_budget_seconds(asset),
                    "request": request_for(asset, assets),
                },
                ensure_ascii=False,
            )
        )

def command_submit_live(ids: Sequence[str]) -> None:
    """Submit once, separating the preflight record from the live POST."""
    assets = read_assets()
    for asset in selected_assets(assets, ids):
        paths = paths_for(asset)
        request = request_for(asset, assets)
        existed = paths["request"].exists()
        _ensure_immutable_request(paths["request"], request)
        if paths["submission"].exists():
            submission = read_json(paths["submission"])
            if not isinstance(submission, dict) or not submission.get("task_id"):
                raise RuntimeError("Existing Tripo submission record is invalid")
            print(json.dumps({"id": asset["id"], "status": "already_submitted"}))
            continue
        if existed:
            raise RuntimeError(
                "Ambiguous submission state for "
                + asset["id"]
                + "; refusing a duplicate-charge retry"
            )
        # The immutable request is now the durable write-ahead marker. If the
        # POST times out or the process dies, future runs stop here.
        data = api_request("/generation/text-to-model", request)
        if not isinstance(data, dict) or not data.get("task_id"):
            raise RuntimeError(
                "Tripo response did not contain task_id; refusing a retry because the charge is ambiguous"
            )
        write_json(
            paths["submission"],
            {
                "asset_id": asset["id"],
                "task_id": data["task_id"],
                "submitted_at": utc_now(),
            },
            mode=0o600,
        )
        print(
            json.dumps(
                {"id": asset["id"], "task_id": data["task_id"], "status": "submitted"}
            )
        )


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    try:
        with path.open("rb") as stream:
            for chunk in iter(lambda: stream.read(1024 * 1024), b""):
                digest.update(chunk)
    except OSError as exc:
        raise RuntimeError("Unable to hash the downloaded GLB") from exc
    return digest.hexdigest()


def validate_https_url(url: str) -> None:
    parsed = urlparse(url)
    try:
        port = parsed.port
    except ValueError as exc:
        raise RuntimeError("Tripo returned an invalid HTTPS download URL") from exc
    if (
        parsed.scheme.lower() != "https"
        or not parsed.hostname
        or parsed.username is not None
        or parsed.password is not None
        or port is not None and not (1 <= port <= 65535)
    ):
        raise RuntimeError("Tripo returned a non-HTTPS download URL")


def validate_glb(path: Path) -> None:
    """Validate the GLB v2 header and JSON chunk before it becomes a source asset."""
    try:
        file_size = path.stat().st_size
        if file_size < 20:
            raise ValueError
        with path.open("rb") as stream:
            header = stream.read(12)
            magic, version, declared_length = struct.unpack("<4sII", header)
            if magic != b"glTF" or version != 2 or declared_length != file_size:
                raise ValueError
            chunk_header = stream.read(8)
            chunk_length, chunk_type = struct.unpack("<II", chunk_header)
            if chunk_type != 0x4E4F534A or chunk_length < 2:
                raise ValueError
            if 20 + chunk_length > file_size:
                raise ValueError
            chunk = stream.read(chunk_length)
        metadata = json.loads(chunk.rstrip(b" \t\r\n\x00").decode("utf-8"))
        if not isinstance(metadata, dict):
            raise ValueError
    except (OSError, ValueError, UnicodeDecodeError, json.JSONDecodeError, struct.error) as exc:
        raise RuntimeError("Downloaded file is not a valid GLB v2") from exc


def download_glb(url: str, destination: Path, timeout_seconds: int) -> None:
    """Download a validated HTTPS URL without exposing it in process arguments."""
    validate_https_url(url)
    destination.parent.mkdir(parents=True, exist_ok=True)
    part = destination.with_name(destination.name + ".part")
    part.unlink(missing_ok=True)
    config = [
        "url = " + json.dumps(url),
        "output = " + json.dumps(str(part)),
    ]
    result = subprocess.run(
        _curl_args(timeout_seconds),
        input="\n".join(config) + "\n",
        text=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
    )
    if result.returncode != 0:
        part.unlink(missing_ok=True)
        raise RuntimeError("Tripo GLB download failed; remote response was not recorded")
    try:
        validate_glb(part)
        with part.open("rb") as stream:
            os.fsync(stream.fileno())
        _atomic_replace(part, destination)
    except RuntimeError:
        part.unlink(missing_ok=True)
        raise


def command_poll() -> None:
    for asset in read_assets():
        paths = paths_for(asset)
        if not paths["submission"].exists():
            continue
        if paths["source"].exists():
            validate_glb(paths["source"])
            print(
                json.dumps(
                    {"id": asset["id"], "status": "downloaded", "sha256": sha256(paths["source"])}
                )
            )
            continue
        submission = read_json(paths["submission"])
        if not isinstance(submission, dict) or not isinstance(
            submission.get("task_id"), str
        ):
            raise RuntimeError("Existing Tripo submission record is invalid")
        task_id = submission["task_id"]
        data = api_request("/tasks/" + quote(task_id, safe=""))
        if not isinstance(data, dict):
            raise RuntimeError("Tripo task response was not an object")
        safe_task = {
            "asset_id": asset["id"],
            "task_id": task_id,
            "status": data.get("status"),
            "progress": data.get("progress"),
            "credits_consumed": data.get("credits_consumed", data.get("credits")),
            "polled_at": utc_now(),
        }
        write_json(paths["task"], safe_task, mode=0o600)
        print(json.dumps(safe_task, ensure_ascii=False))
        if data.get("status") != "success":
            continue
        output = data.get("output") or {}
        if not isinstance(output, dict):
            raise RuntimeError("Successful Tripo task has no usable output")
        url = output.get("model_url") or output.get("pbr_model") or output.get("model")
        if not isinstance(url, str):
            raise RuntimeError("Successful Tripo task has no HTTPS model URL")
        download_glb(url, paths["source"], runtime_budget_seconds(asset))
        audit = {
            "asset_id": asset["id"],
            "task_id": task_id,
            "source_file": str(paths["source"].relative_to(PROJECT_ROOT)),
            "source_sha256": sha256(paths["source"]),
            "source_bytes": paths["source"].stat().st_size,
            "downloaded_at": utc_now(),
            "license_status": "pending_manual_review",
            "visual_review": "pending",
            "processing_status": "source_only",
        }
        write_json(paths["audit"], audit, mode=0o600)
        print(
            json.dumps(
                {
                    "id": asset["id"],
                    "status": "saved",
                    "sha256": audit["source_sha256"],
                    "bytes": audit["source_bytes"],
                }
            )
        )


def _parse_args(arguments: Sequence[str]) -> Any:
    if not arguments:
        raise RuntimeError(
            "Usage: python3 generate.py balance | submit [asset_id ...] | submit --dry-run [asset_id ...] | poll"
        )
    command = arguments[0]
    rest = list(arguments[1:])
    dry_run = False
    if "--dry-run" in rest:
        dry_run = True
        rest.remove("--dry-run")
    if any(item.startswith("-") for item in rest):
        raise RuntimeError("Unknown option")
    return command, rest, dry_run


def main(arguments: Optional[Sequence[str]] = None) -> None:
    command, ids, dry_run = _parse_args(sys.argv[1:] if arguments is None else arguments)
    if command == "dry-run":
        if dry_run:
            raise RuntimeError("--dry-run is redundant with the dry-run command")
        command_dry_run(ids)
    elif command == "balance":
        if dry_run:
            raise RuntimeError("balance does not support --dry-run")
        command_balance()
    elif command == "submit":
        if dry_run:
            command_dry_run(ids)
        else:
            command_submit_live(ids)
    elif command == "poll":
        if dry_run:
            raise RuntimeError("poll does not support --dry-run")
        command_poll()
    else:
        raise RuntimeError(
            "Usage: python3 generate.py balance | submit [asset_id ...] | submit --dry-run [asset_id ...] | poll"
        )


if __name__ == "__main__":
    try:
        main()
    except RuntimeError as exc:
        print("error: " + str(exc), file=sys.stderr)
        sys.exit(2)
