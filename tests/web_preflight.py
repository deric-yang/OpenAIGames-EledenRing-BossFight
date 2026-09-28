"""Report whether this project can perform a real Godot Web export."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys


PROJECT_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUTPUT = PROJECT_ROOT / "qa" / "web" / "readiness.json"


def _find_executable(env_name: str, names: tuple[str, ...], app_paths: tuple[Path, ...] = ()) -> str | None:
    configured = os.environ.get(env_name)
    if configured:
        candidate = Path(configured).expanduser()
        if candidate.is_file() and os.access(candidate, os.X_OK):
            return str(candidate)
        return None
    for name in names:
        found = shutil.which(name)
        if found:
            return found
    for candidate in app_paths:
        if candidate.is_file() and os.access(candidate, os.X_OK):
            return str(candidate)
    return None


def _command_version(executable: str | None) -> str | None:
    if not executable:
        return None
    try:
        result = subprocess.run(
            [executable, "--version"],
            check=False,
            capture_output=True,
            text=True,
            timeout=10,
        )
    except (OSError, subprocess.SubprocessError):
        return None
    output = (result.stdout or result.stderr).strip()
    return output.splitlines()[0] if output else None


def _template_status() -> dict[str, object]:
    configured = os.environ.get("GODOT_EXPORT_TEMPLATES")
    directory = Path(configured).expanduser() if configured else Path.home() / "Library/Application Support/Godot/export_templates"
    entries = sorted(path.name for path in directory.glob("*") if path.is_dir()) if directory.is_dir() else []
    web_entries = [name for name in entries if "web" in name.lower() or "4.7" in name]
    return {
        "path": str(directory),
        "exists": directory.is_dir(),
        "entries": entries,
        "web_candidates": web_entries,
        "available": bool(web_entries),
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--strict", action="store_true", help="exit 1 when Web export prerequisites are missing")
    args = parser.parse_args()

    godot = _find_executable(
        "GODOT_BIN",
        ("godot", "Godot"),
        (Path("/Applications/Godot.app/Contents/MacOS/Godot"),),
    )
    chrome = _find_executable(
        "CHROME_BIN",
        ("google-chrome", "chromium", "chromium-browser"),
        (Path("/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"),),
    )
    node = _find_executable("NODE_BIN", ("node",))
    npm = _find_executable("NPM_BIN", ("npm",))
    export_presets = PROJECT_ROOT / "export_presets.cfg"
    builds = PROJECT_ROOT / "builds"
    templates = _template_status()
    report = {
        "project": str(PROJECT_ROOT),
        "renderer": "gl_compatibility",
        "web_target": "WebGL2",
        "godot": {"path": godot, "version": _command_version(godot)},
        "export_presets": {"path": str(export_presets), "exists": export_presets.is_file()},
        "export_templates": templates,
        "web_build_artifacts": {
            "path": str(builds),
            "exists": builds.is_dir(),
            "files": sorted(str(path.relative_to(PROJECT_ROOT)) for path in builds.rglob("*") if path.is_file()) if builds.is_dir() else [],
        },
        "browser": {"chrome": chrome, "version": _command_version(chrome)},
        "automation": {
            "node": {"path": node, "version": _command_version(node)},
            "npm": {"path": npm, "version": _command_version(npm)},
            "python_playwright": shutil.which("playwright") is not None,
            "python_selenium": _module_available("selenium"),
            "python_pyppeteer": _module_available("pyppeteer"),
        },
    }
    blockers = []
    if not report["export_presets"]["exists"]:
        blockers.append("missing export_presets.cfg")
    if not templates["available"]:
        blockers.append("missing Godot Web export templates")
    if not godot:
        blockers.append("Godot executable not found")
    report["blockers"] = blockers
    report["ready_for_web_export"] = not blockers

    output = args.output if args.output.is_absolute() else PROJECT_ROOT / args.output
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 1 if args.strict and blockers else 0


def _module_available(name: str) -> bool:
    try:
        __import__(name)
    except ImportError:
        return False
    return True


if __name__ == "__main__":
    sys.exit(main())
