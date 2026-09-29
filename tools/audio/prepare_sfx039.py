"""Prepare selected local SFX039 clips without changing the source recordings."""

from __future__ import annotations

import argparse
import json
import subprocess
from pathlib import Path

import numpy as np


def run(ffmpeg: str, arguments: list[str], data: bytes | None = None) -> bytes:
    """Run the local encoder and surface decoding failures."""
    return subprocess.run(
        [ffmpeg, "-v", "error", "-y", *arguments], input=data, capture_output=True, check=True,
    ).stdout


def main() -> None:
    """Crop the first rock drops and make an amplified, crossfaded rumble loop."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ffmpeg", required=True)
    args = parser.parse_args()
    project = Path(__file__).resolve().parents[2]
    pool = project.parents[1] / "asset-audition/shared-pool"
    catalog = json.loads((pool / "public/audio-catalog-sfx039.json").read_text())
    entries = {item["name"]: item for item in catalog["items"]}
    output = project / "assets/runtime/audio/v10"
    output.mkdir(parents=True, exist_ok=True)
    report = {"clips": [], "source_modified": False}
    # First tails fall below -50 dBFS by 1.20 / 1.35 seconds. Next drops start at 3.05.
    for number, end in [(1, 1.42), (2, 1.58)]:
        name = f"BROKEN - CK - STONE Rock Drop On Rocks Large A {number:02}"
        entry = entries[name]
        target = output / f"rock_drop_first_{number:02}.wav"
        fade_start = end - 0.045
        run(args.ffmpeg, [
            "-i", str(pool / entry["source"]), "-t", str(end),
            "-af", f"volume=-3dB,afade=t=in:d=0.002,afade=t=out:st={fade_start}:d=0.045",
            "-ar", "44100", "-ac", "1", "-c:a", "pcm_s16le", "-map_metadata", "-1", str(target),
        ])
        report["clips"].append({
            "name": name, "source": entry["source"], "source_sha256": entry["sha256"],
            "output": str(target.relative_to(project)), "source_crop_seconds": [0, end], "gain_db": -3,
        })
    name = "BROKEN - DESIGNED - EARTHQUAKE Rumble LFE 02"
    entry = entries[name]
    rate = 44100
    raw = run(args.ffmpeg, [
        "-i", str(pool / entry["source"]), "-ar", str(rate), "-ac", "2", "-f", "f32le", "-",
    ])
    samples = np.frombuffer(raw, dtype="<f4").reshape(-1, 2)
    overlap = rate * 3
    phase = np.linspace(0, np.pi / 2, overlap, endpoint=True, dtype=np.float32)[:, None]
    seam = samples[-overlap:] * np.cos(phase) + samples[:overlap] * np.sin(phase)
    loop = np.concatenate([samples[overlap:-overlap], seam]).astype("<f4")
    target = output / "prebattle_earthquake.ogg"
    run(args.ffmpeg, [
        "-f", "f32le", "-ar", str(rate), "-ac", "2", "-i", "-",
        "-af", "volume=1.3,alimiter=limit=0.891251:level=false:latency=true",
        "-c:a", "libvorbis", "-q:a", "5", "-map_metadata", "-1", str(target),
    ], loop.tobytes())
    report["clips"].append({
        "name": name, "source": entry["source"], "source_sha256": entry["sha256"],
        "output": str(target.relative_to(project)), "duration": len(loop) / rate,
        "gain_linear": 1.3, "crossfade_seconds": 3, "peak_limiter_dbfs": -1,
    })
    (output / "sfx039-provenance.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
