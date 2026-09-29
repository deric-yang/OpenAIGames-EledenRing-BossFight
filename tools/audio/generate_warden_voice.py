"""Generate the six approved Victor lines; secrets stay in process memory only."""

from __future__ import annotations

import base64
import getpass
import json
import os
from pathlib import Path
import urllib.error
import urllib.request

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "assets/runtime/dialogue/warden-victor.json"
RECORDS = ROOT / "generation-records/voice-victor"
API = "https://api.elevenlabs.io/v1"


def request_json(key: str, path: str, payload: dict | None = None) -> tuple[dict, dict]:
    """Make one official API request; never retry an uncertain paid generation."""
    request = urllib.request.Request(
        API + path,
        data=json.dumps(payload).encode() if payload is not None else None,
        headers={"xi-api-key": key, "Content-Type": "application/json"},
        method="POST" if payload is not None else "GET",
    )
    with urllib.request.urlopen(request, timeout=180) as response:
        return json.load(response), dict(response.headers)


def main() -> None:
    """Verify the selected library voice and save resumable audio plus alignment."""
    key = os.environ.get("ELEVENLABS_API_KEY") or getpass.getpass("ElevenLabs API key (hidden): ")
    data = json.loads(MANIFEST.read_text())
    voice, _ = request_json(key, "/voices/" + data["voice_id"])
    models, _ = request_json(key, "/models")
    available = [row["model_id"] for row in models if row.get("can_do_text_to_speech")]
    print(json.dumps({"voice_id": voice["voice_id"], "name": voice["name"], "tts_models": available}), flush=True)
    if data["model_id"] not in available:
        raise RuntimeError("Requested expressive TTS model is unavailable; no generation attempted.")
    RECORDS.mkdir(parents=True, exist_ok=True)
    for index, (ident, line) in enumerate(data["lines"].items()):
        destination = ROOT / line["file"].removeprefix("res://")
        record_path = RECORDS / (ident + ".json")
        if destination.exists() and record_path.exists():
            print("Already generated: " + ident, flush=True)
            continue
        payload = {
            "text": line["performance"], "model_id": data["model_id"], "language_code": "en",
            "voice_settings": {"stability": 0.5, "similarity_boost": 0.78, "speed": 0.94},
            "seed": 929013 + index,
        }
        result, headers = request_json(
            key, "/text-to-speech/" + data["voice_id"] + "/with-timestamps?output_format=mp3_44100_128",
            payload,
        )
        audio = base64.b64decode(result.pop("audio_base64"))
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(audio)
        record = {
            "voice_id": voice["voice_id"], "voice_name": voice["name"], "request": payload,
            "request_id": headers.get("request-id"), "character_cost": headers.get("character-cost"),
            "bytes": len(audio), **result,
        }
        record_path.write_text(json.dumps(record, ensure_ascii=False, indent=2))
        alignment = result.get("normalized_alignment") or result.get("alignment") or {}
        ends = alignment.get("character_end_times_seconds", [])
        line["speech_end"] = max(ends) if ends else 0.0
        MANIFEST.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")
        print(json.dumps({"id": ident, "bytes": len(audio), "speech_end": line["speech_end"]}), flush=True)


if __name__ == "__main__":
    try:
        main()
    except urllib.error.HTTPError as error:
        print(json.dumps({"http_status": error.code, "detail": error.read().decode()[:1200]}), flush=True)
        raise SystemExit(1) from None
