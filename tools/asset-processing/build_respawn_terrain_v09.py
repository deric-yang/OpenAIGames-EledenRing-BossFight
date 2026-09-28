"""Preserve the dune field and add a locally dense, level respawn shelf."""
from __future__ import annotations

import importlib.util
import json
from pathlib import Path

import bpy

SPEC = importlib.util.spec_from_file_location('dunes', Path(__file__).with_name('build_dunes_v04.py'))
DUNES = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(DUNES)
clean_scene = DUNES.clean_scene
dune_height = DUNES.dune_height
material = DUNES.material
mesh_object = DUNES.mesh_object

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/runtime/world/v09'
OUT.mkdir(parents=True, exist_ok=True)
clean_scene()
xs = sorted(set(range(-160, 161, 2)) | {i / 2 for i in range(-2, 31)})
ys = sorted(set(range(-180, 181, 2)) | {i / 2 for i in range(36, 69)})
vertices = [(x, y, dune_height(x, y)) for y in ys for x in xs]
faces = []
for row in range(len(ys) - 1):
    for column in range(len(xs) - 1):
        index = row * len(xs) + column
        faces.append((index, index + 1, index + len(xs) + 1, index + len(xs)))
obj = mesh_object('AncientBattlefield_RespawnShelf', vertices, faces,
                  material('Sand', (0.42, 0.285, 0.17)))
uv = obj.data.uv_layers.new(name='TerrainUV')
for loop in obj.data.loops:
    point = obj.data.vertices[loop.vertex_index].co
    uv.data[loop.index].uv = ((point.x + 160) / 320, (point.y + 180) / 360)
bpy.ops.export_scene.gltf(filepath=str(OUT / 'terrain.glb'), export_format='GLB')
source = ROOT / 'assets/processed/battlefield_v09'
source.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=str(source / 'terrain.blend'))
(source / 'terrain.json').write_text(json.dumps({
    'center_godot': [7, -26], 'flat_radius': 3.1, 'blend_radius': 7.5,
    'triangles': len(faces) * 2, 'local_grid_spacing': 0.5,
    'height': dune_height(7, 26), 'collision': 'same mesh via create_trimesh_collision',
}, indent=2) + '\n')
