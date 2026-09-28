"""Budget new individual battlefield debris without changing high resolution sources."""
from __future__ import annotations

import importlib.util
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('assembly', Path(__file__).with_name('prepare_assembly.py'))
assembly = importlib.util.module_from_spec(spec)
spec.loader.exec_module(assembly)
assembly.OUTPUT = ROOT / 'assets/runtime/world/v04'
for item in [('broken_bow', 'source/broken_war_bow_v04/model.glb', None, 4500, 1024, False),
             ('fallen_soldier', 'source/fallen_soldier_relic_v04/model.glb', None, 8000, 1024, False)]:
    print(assembly.process(item))
