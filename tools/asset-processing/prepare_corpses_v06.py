"""Reduce the two authorized Tripo ruins to small static battlefield assets."""
from __future__ import annotations

import importlib.util
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('assembly', Path(__file__).with_name('prepare_assembly.py'))
assembly = importlib.util.module_from_spec(spec)
spec.loader.exec_module(assembly)
assembly.OUTPUT = ROOT / 'assets/runtime/world/v06'
assembly.OUTPUT.mkdir(parents=True, exist_ok=True)
items = [
    (f'fallen_{i}', f'source/fallen_mound_v06_{i}/model.glb', 0.85, 2200, 512, False)
    for i in range(1, 4)
]
report = [assembly.process(item) for item in items]
(assembly.OUTPUT / 'corpses-manifest.json').write_text(json.dumps(report, indent=2) + '\n')
print('V05_RUINS_READY', json.dumps(report))
