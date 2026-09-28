"""Give the generated straight sword a heavy slab profile, preserving its original."""

from __future__ import annotations

import json
from pathlib import Path

import bpy


ROOT = Path(__file__).resolve().parents[2]
ASSET_ID = 'great_enemy_greatsword_v03'


def main():
    """Balance the blade with a thicker grip, broader guard and heavier pommel."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    source = ROOT / 'assets/source/great_enemy_greatsword_v02/model.glb'
    output = ROOT / 'assets/processed' / ASSET_ID
    output.mkdir(parents=True, exist_ok=True)
    bpy.ops.import_scene.gltf(filepath=str(source))
    for obj in bpy.context.scene.objects:
        if obj.type != 'MESH':
            continue
        bpy.context.view_layer.objects.active = obj
        obj.select_set(True)
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        minimum = min(vertex.co.z for vertex in obj.data.vertices)
        height = max(vertex.co.z for vertex in obj.data.vertices) - minimum
        for vertex in obj.data.vertices:
            normalized = (vertex.co.z - minimum) / height
            blend = max(0.0, min(1.0, (normalized - 0.205) / 0.065))
            blend = blend * blend * (3.0 - 2.0 * blend)
            vertex.co.x *= 2.0 + 0.3 * blend
            vertex.co.y *= 2.0 + 0.2 * blend
            vertex.co.z -= minimum
            vertex.co *= 4.8 / height
        obj.data.update()
        obj.select_set(False)
    bpy.ops.wm.save_as_mainfile(filepath=str(output / 'heavy-slab.blend'))
    bpy.ops.export_scene.gltf(filepath=str(output / 'model.glb'), export_format='GLB')
    (output / 'authoring.json').write_text(json.dumps({
        'source': str(source.relative_to(ROOT)), 'length_m': 4.8,
        'blade_width_multiplier': 2.2, 'blade_depth_multiplier': 2.3,
        'grip': 'width and depth doubled; guard and pommel strengthened',
        'status': 'static art candidate, grip and boss assembly not yet validated',
    }, indent=2) + '\n')


if __name__ == '__main__':
    main()
