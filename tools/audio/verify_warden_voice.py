"""Transcribe generated audio to catch omitted words or spoken performance tags."""

from __future__ import annotations

import getpass
import json
import os
from pathlib import Path
import re
import urllib.request
import uuid

ROOT = Path(__file__).resolve().parents[2]


def normalize(text: str) -> str:
    """Compare spoken words independently of punctuation and capitalization."""
    return " ".join(re.findall(r"[a-z]+", text.lower()))


def main() -> None:
    """Verify only the six newly generated files using the same official provider."""
    key = os.environ.get("ELEVENLABS_API_KEY") or getpass.getpass("ElevenLabs API key (hidden): ")
    data = json.loads((ROOT / "assets/runtime/dialogue/warden-victor.json").read_text())
    records = ROOT / "generation-records/voice-victor"
    for ident, line in data["lines"].items():
        output = records / (ident + "-transcript.json")
        if output.exists():
            result = json.loads(output.read_text())
        else:
            boundary = "warden-" + uuid.uuid4().hex
            parts = []
            for name, value in [("model_id", "scribe_v2"), ("language_code", "eng"), ("tag_audio_events", "false")]:
                parts.append(
                    f'--{boundary}\r\nContent-Disposition: form-data; name="{name}"\r\n\r\n{value}\r\n'.encode()
                )
            path = ROOT / line["file"].removeprefix("res://")
            parts.append(
                f'--{boundary}\r\nContent-Disposition: form-data; name="file"; filename="{path.name}"\r\n'
                'Content-Type: audio/mpeg\r\n\r\n'.encode() + path.read_bytes() + b"\r\n"
            )
            parts.append(f"--{boundary}--\r\n".encode())
            request = urllib.request.Request(
                "https://api.elevenlabs.io/v1/speech-to-text", data=b"".join(parts), method="POST",
                headers={"xi-api-key": key, "Content-Type": "multipart/form-data; boundary=" + boundary},
            )
            with urllib.request.urlopen(request, timeout=120) as response:
                result = json.load(response)
            output.write_text(json.dumps(result, ensure_ascii=False, indent=2))
        print(json.dumps({"id": ident, "text": result["text"], "exact_words": normalize(result["text"]) == normalize(line["en"])}), flush=True)


if __name__ == "__main__":
    main()
