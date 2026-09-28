"""Reduce the two authorized Tripo ruins to small static battlefield assets."""
from __future__ import annotations

import importlib.util
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('assembly', Path(__file__).with_name('prepare_assembly.py'))
assembly = importlib.util.module_from_spec(spec)
spec.loader.exec_module(assembly)
assembly.OUTPUT = ROOT / 'assets/runtime/world/v05'
assembly.OUTPUT.mkdir(parents=True, exist_ok=True)
items = [
    ('column', 'source/ruined_ionic_column_v05/model.glb', 6.5, 6500, 1024, False),
    ('wall', 'source/ruined_stone_wall_v05/model.glb', 4.2, 8500, 1024, False),
]
report = [assembly.process(item) for item in items]
(assembly.OUTPUT / 'ruins-manifest.json').write_text(json.dumps(report, indent=2) + '\n')
print('V05_RUINS_READY', json.dumps(report))
