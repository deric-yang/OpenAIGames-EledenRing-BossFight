"""Preserve Tripo skinning while reducing and normalizing new character assets."""
from __future__ import annotations

import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector
from mathutils.kdtree import KDTree

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/runtime/characters/v04'


def bind_cape(rig, meshes):
    """Give the lower rear cloak independent chains while retaining the pinned upper mantle."""
    inverse = rig.matrix_world.inverted()
    bpy.ops.object.select_all(action='DESELECT')
    rig.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode='EDIT')
    for column, x in enumerate([-0.25, 0.0, 0.25]):
        for row in range(4):
            name = f'Cape_{column}_{row}'
            bone = rig.data.edit_bones.new(name)
            bone.head = inverse @ Vector((x, 0.17 + row * 0.025, 1.43 - row * 0.29))
            bone.tail = inverse @ Vector((x, 0.195 + row * 0.025, 1.14 - row * 0.29))
            bone.parent = rig.data.edit_bones[f'Cape_{column}_{row - 1}'] if row else rig.data.edit_bones['mixamorig:Spine2']
    bpy.ops.object.mode_set(mode='OBJECT')
    count = 0
    for mesh in meshes:
        groups = {f'Cape_{c}_{r}': mesh.vertex_groups.new(name=f'Cape_{c}_{r}')
                  for c in range(3) for r in range(4)}
        for vertex in mesh.data.vertices:
            point = mesh.matrix_world @ vertex.co
            if point.y < 0.14 or not 0.16 < point.z < 1.43:
                continue
            amount = min(1.0, (1.43 - point.z) / 0.30) * min(1.0, (point.y - 0.14) / 0.08)
            if amount <= 0.01:
                continue
            old = [(g.group, g.weight) for g in vertex.groups]
            for index, weight in old:
                mesh.vertex_groups[index].add([vertex.index], weight * (1 - amount), 'REPLACE')
            horizontal = max(0.0, min(2.0, (point.x + 0.25) / 0.25))
            vertical = max(0.0, min(3.0, (1.43 - point.z) / 0.29))
            for column in range(3):
                for row in range(4):
                    weight = max(0, 1 - abs(horizontal - column)) * max(0, 1 - abs(vertical - row))
                    if weight:
                        groups[f'Cape_{column}_{row}'].add([vertex.index], weight * amount, 'REPLACE')
            count += 1
    print('CAPE_BOUND', count, flush=True)


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
    transform = Matrix.Rotation(-math.pi / 2, 4, 'Z') @ Matrix.Scale(factor, 4) @ Matrix.Translation(-center)
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
    bind_cape(rigs[0], meshes)
    if name == 'knight':
        for mesh in meshes:
            original_material = mesh.data.materials[0]
            cloth = original_material.copy()
            cloth.name = 'Knight_Charcoal_Cloth'
            shader = cloth.node_tree.nodes.get('Principled BSDF')
            socket = shader.inputs['Base Color']
            if socket.is_linked:
                source_socket = socket.links[0].from_socket
                multiply = cloth.node_tree.nodes.new('ShaderNodeMixRGB')
                multiply.blend_type = 'MULTIPLY'
                multiply.inputs[0].default_value = 1
                multiply.inputs[2].default_value = (0.24, 0.255, 0.28, 1)
                cloth.node_tree.links.new(source_socket, multiply.inputs[1])
                cloth.node_tree.links.new(multiply.outputs[0], socket)
            for name_input, value in [('Metallic', 0), ('Roughness', 0.95)]:
                target = shader.inputs[name_input]
                for link in list(target.links):
                    cloth.node_tree.links.remove(link)
                target.default_value = value
            mesh.data.materials.append(cloth)
            cape_groups = {g.index for g in mesh.vertex_groups if g.name.startswith('Cape_')}
            weights = [sum(g.weight for g in v.groups if g.group in cape_groups) for v in mesh.data.vertices]
            for polygon in mesh.data.polygons:
                if sum(weights[i] for i in polygon.vertices) / len(polygon.vertices) > 0.55:
                    polygon.material_index = len(mesh.data.materials) - 1
    for image in bpy.data.images:
        if image.size[0] > 2048:
            image.scale(2048, round(image.size[1] * 2048 / image.size[0]))
            image.pack()
    OUT.mkdir(parents=True, exist_ok=True)
    work = ROOT / 'assets/processed' / source
    work.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(work / 'optimized.blend'))
    bpy.ops.export_scene.gltf(filepath=str(OUT / (name + '.glb')), export_format='GLB', export_animations=False)
    if name == 'knight':
        sys.path.insert(0, str(Path(__file__).resolve().parent))
        from glb_material_tint import apply_cloth_tint
        apply_cloth_tint(OUT / 'knight.glb')
    report = {'source': source, 'triangles_before': before,
              'triangles_after': sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in meshes),
              'bones': [{'name': b.name, 'head': list(r.matrix_world @ b.head_local)}
                        for r in rigs for b in r.data.bones],
              'unweighted_vertices': sum(1 for o in meshes for v in o.data.vertices if not v.groups)}
    (work / 'optimization.json').write_text(json.dumps(report, indent=2) + '\n')
    print('CHARACTER_READY', name, report['triangles_after'], 'unweighted', report['unweighted_vertices'])


roles = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else ['general', 'knight']
if 'general' in roles:
    prepare('general', 'old_general_v04_rigged', 55000)
if 'knight' in roles:
    prepare('knight', 'silver_knight_v04_rigged', 32000)
