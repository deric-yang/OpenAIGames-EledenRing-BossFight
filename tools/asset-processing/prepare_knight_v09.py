"""Preserve Tripo skinning while reducing and normalizing new character assets."""
from __future__ import annotations

import json
import math
from pathlib import Path

import bpy
from mathutils import Matrix, Vector
from mathutils.kdtree import KDTree

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/runtime/characters/v09'


def prepare(name, source, budget):
    """Normalize skeleton and mesh together, then decimate weighted geometry."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(ROOT / 'assets/source' / source / 'model.glb'))
    bpy.context.view_layer.update()
    rigs = [o for o in bpy.context.scene.objects if o.type == 'ARMATURE']
    for rig in rigs:
        for bone in rig.pose.bones:
            bone.custom_shape = None
    # Blender creates an unskinned Icosphere as a bone display helper on import.
    # It must not affect character bounds, exports, or skin-weight validation.
    for obj in list(bpy.context.scene.objects):
        if obj.type == 'MESH' and not any(m.type == 'ARMATURE' for m in obj.modifiers):
            bpy.data.objects.remove(obj, do_unlink=True)
    objects = list(bpy.context.scene.objects)
    meshes = [o for o in objects if o.type == 'MESH']
    points = [o.matrix_world @ Vector(p) for o in meshes for p in o.bound_box]
    low = Vector(tuple(min(p[i] for p in points) for i in range(3)))
    high = Vector(tuple(max(p[i] for p in points) for i in range(3)))
    center = Vector(((low.x + high.x) / 2, (low.y + high.y) / 2, low.z))
    factor = 1.85 / (high.z - low.z)
    right = rigs[0].matrix_world @ rigs[0].data.bones['mixamorig:RightArm'].head_local
    left = rigs[0].matrix_world @ rigs[0].data.bones['mixamorig:LeftArm'].head_local
    axis = right - left
    yaw = math.pi - math.atan2(axis.y, axis.x)
    transform = Matrix.Rotation(yaw, 4, 'Z') @ Matrix.Scale(factor, 4) @ Matrix.Translation(-center)
    original = {o: o.matrix_world.copy() for o in objects}
    for obj in objects:
        if obj.parent is None:
            obj.matrix_world = transform @ original[obj]
    bpy.context.view_layer.update()
    before = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in meshes)
    for obj in meshes:
        bpy.context.view_layer.objects.active = obj
        modifier = obj.modifiers.new('WebBudget', 'DECIMATE')
        modifier.ratio = min(1.0, budget / before)
        bpy.ops.object.modifier_move_to_index(modifier=modifier.name, index=0)
        bpy.ops.object.modifier_apply(modifier=modifier.name)
        weighted = [v for v in obj.data.vertices if any(g.weight > 0.00001 for g in v.groups)]
        tree = KDTree(len(weighted))
        for index, vertex in enumerate(weighted):
            tree.insert(vertex.co, index)
        tree.balance()
        for vertex in obj.data.vertices:
            if any(g.weight > 0.00001 for g in vertex.groups):
                continue
            _, nearest, _ = tree.find(vertex.co)
            if nearest is None:
                raise RuntimeError(f'Invalid reduced vertex {vertex.index}: {list(vertex.co)}, weighted={len(weighted)}')
            for group in weighted[nearest].groups:
                obj.vertex_groups[group.group].add([vertex.index], group.weight, 'REPLACE')
    for image in bpy.data.images:
        if image.size[0] > 2048:
            image.scale(2048, round(image.size[1] * 2048 / image.size[0]))
            image.pack()
    OUT.mkdir(parents=True, exist_ok=True)
    work = ROOT / 'assets/processed' / source
    work.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(work / 'optimized.blend'))
    bpy.ops.export_scene.gltf(filepath=str(OUT / (name + '.glb')), export_format='GLB', export_animations=False)
    report = {'source': source, 'triangles_before': before,
              'triangles_after': sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in meshes),
              'bones': [{'name': b.name, 'head': list(r.matrix_world @ b.head_local)}
                        for r in rigs for b in r.data.bones],
              'unweighted_vertices': sum(1 for o in meshes for v in o.data.vertices if not v.groups)}
    (work / 'optimization.json').write_text(json.dumps(report, indent=2) + '\n')
    print('CHARACTER_READY', name, report['triangles_after'], 'unweighted', report['unweighted_vertices'])


prepare('knight', 'silver_knight_capeless_v09_rigged', 30000)
