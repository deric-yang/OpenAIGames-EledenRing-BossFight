"""Build budgeted, consistently oriented static assets for the assembled art scene."""

from __future__ import annotations

import json
import math
import shutil
import sys
from pathlib import Path

import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / 'assets/runtime/assembly'
SPECS = [
    ('boss', 'source/great_enemy_body_v01/model.glb', 7.2, 70000, 2048, True),
    ('player', 'source/player_silver_v01/model.glb', 1.85, 35000, 2048, True),
    ('sword', 'processed/great_enemy_greatsword_v03/model.glb', 4.8, 22000, 2048, True),
    ('tree', 'source/golden_tree_v01/model.glb', 94, 45000, 2048, True),
    ('rubble', 'source/war_relic_cluster_v01/model.glb', 1.0, 9000, 1024, True),
    ('graves', 'source/sword_grave_cluster_v02/model.glb', 1.7, 10000, 1024, True),
    ('polearms', 'source/polearm_grave_cluster_v02/model.glb', 3.6, 10000, 1024, True),
    ('terrain', 'source/dune_battlefield_v02/model.glb', None, 60000, 1024, False),
    ('standard', 'source/soul_standard_v02/model.glb', None, 5000, 1024, False),
    ('sigil', 'source/golden_respawn_sigil_v03/model.glb', None, 14000, 2048, False),
]


def process(spec):
    """Normalize feet and facing, simplify geometry and resize textures on copies."""
    name, source, height, budget, texture_size, rotate = spec
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(ROOT / 'assets' / source))
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == 'MESH']
    if name == 'sigil':
        for obj in meshes:
            bpy.context.view_layer.objects.active = obj
            obj.select_set(True)
            bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
            for vertex in obj.data.vertices:
                original = vertex.co.copy()
                vertex.co = Vector((-original.z, original.y, original.x))
            minimum = Vector(tuple(min(v.co[i] for v in obj.data.vertices) for i in range(3)))
            maximum = Vector(tuple(max(v.co[i] for v in obj.data.vertices) for i in range(3)))
            size = maximum - minimum
            for vertex in obj.data.vertices:
                vertex.co.x = (vertex.co.x - (minimum.x + maximum.x) / 2) * 3.3 / max(size.x, size.y)
                vertex.co.y = (vertex.co.y - (minimum.y + maximum.y) / 2) * 3.3 / max(size.x, size.y)
                vertex.co.z = (vertex.co.z - minimum.z) * 0.08 / max(size.z, 0.0001)
            obj.select_set(False)
    if height:
        points = [obj.matrix_world @ Vector(p) for obj in meshes for p in obj.bound_box]
        low = min(p.z for p in points)
        factor = height / (max(p.z for p in points) - low)
        for obj in meshes:
            bpy.context.view_layer.objects.active = obj
            obj.select_set(True)
            bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
            for vertex in obj.data.vertices:
                vertex.co.z -= low
                vertex.co *= factor
            if rotate:
                obj.rotation_mode = 'XYZ'
                obj.rotation_euler.z = -math.pi / 2
                bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
            obj.select_set(False)
    before = sum(sum(len(p.vertices) - 2 for p in obj.data.polygons) for obj in meshes)
    for obj in meshes:
        bpy.context.view_layer.objects.active = obj
        if before > budget and not obj.data.shape_keys:
            modifier = obj.modifiers.new('AssemblyBudget', 'DECIMATE')
            modifier.ratio = budget / before
            bpy.ops.object.modifier_apply(modifier=modifier.name)
    for image in bpy.data.images:
        if image.size[0] > texture_size:
            ratio = texture_size / image.size[0]
            image.scale(texture_size, round(image.size[1] * ratio))
            image.pack()
    destination = OUTPUT / (name + '.glb')
    if name in ['terrain', 'standard']:
        shutil.copy2(ROOT / 'assets' / source, destination)
    else:
        bpy.ops.export_scene.gltf(filepath=str(destination), export_format='GLB', export_animations=False)
    after = sum(sum(len(p.vertices) - 2 for p in obj.data.polygons) for obj in meshes)
    return {'name': name, 'source': source, 'height_m': height, 'triangles': after,
            'source_triangles': before, 'texture_max': texture_size, 'bytes': destination.stat().st_size}


def main():
    """Create all assembly copies and retain a reproducible budget manifest."""
    OUTPUT.mkdir(parents=True, exist_ok=True)
    selected = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
    specs = [spec for spec in SPECS if not selected or spec[0] in selected]
    results = [process(spec) for spec in specs]
    if selected and (OUTPUT / 'manifest.json').exists():
        previous = json.loads((OUTPUT / 'manifest.json').read_text())
        results = [item for item in previous if item['name'] not in selected] + results
    (OUTPUT / 'manifest.json').write_text(json.dumps(results, indent=2) + '\n')
    print('ASSEMBLY_PREPARED ' + json.dumps(results))


if __name__ == '__main__':
    main()
