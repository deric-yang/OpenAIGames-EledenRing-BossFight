"""Produce optimized rigid weapons and a separately skinned battle standard."""
from __future__ import annotations

import importlib.util
import math
from pathlib import Path

import bpy

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('assembly', Path(__file__).with_name('prepare_assembly.py'))
assembly = importlib.util.module_from_spec(spec)
spec.loader.exec_module(assembly)
assembly.OUTPUT = ROOT / 'assets/runtime/characters/v04'
assembly.OUTPUT.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
vertices, faces = [], []
NX, NY = 33, 17
for j in range(NY):
    v = j / (NY - 1)
    for i in range(NX):
        u = i / (NX - 1)
        # Cloth curls around the upper shaft before falling into a tapered, irregular tail.
        angle = u * math.tau * 1.25 + v * 0.8
        radius = 0.055 + 0.055 * u + 0.095 * u ** 3
        x = math.cos(angle) * radius + max(0.0, u - 0.56) * 0.8
        y = math.sin(angle) * radius
        z = 1.85 - u * 0.92 - v * (0.18 + u * 0.13)
        z -= 0.035 * math.sin(i * 2.3) * v * u
        vertices.append((x, y, z))
for j in range(NY - 1):
    for i in range(NX - 1):
        a = j * NX + i
        faces.append((a, a + 1, a + 1 + NX, a + NX))
mesh = bpy.data.meshes.new('BannerClothGrid')
mesh.from_pydata(vertices, [], faces)
mesh.update()
cloth = bpy.data.objects.new('FlexibleBurgundyStandard', mesh)
bpy.context.collection.objects.link(cloth)
uv = mesh.uv_layers.new(name='UVMap')
for polygon in mesh.polygons:
    polygon.use_smooth = True
    for loop in polygon.loop_indices:
        i = mesh.loops[loop].vertex_index
        uv.data[loop].uv = ((i % NX) / (NX - 1), 1 - (i // NX) / (NY - 1))
material = bpy.data.materials.new('BurgundyGoldBrocade')
material.use_nodes = True
material.use_backface_culling = False
shader = material.node_tree.nodes.get('Principled BSDF')
shader.inputs['Roughness'].default_value = 0.87
texture = material.node_tree.nodes.new('ShaderNodeTexImage')
texture.image = bpy.data.images.load(str(ROOT / 'docs/concepts/v04/banner-textile.png'))
texture.image.scale(1024, 512)
texture.image.pack()
material.node_tree.links.new(texture.outputs['Color'], shader.inputs['Base Color'])
cloth.data.materials.append(material)
arm = bpy.data.armatures.new('BannerChain')
rig = bpy.data.objects.new('BannerRig', arm)
bpy.context.collection.objects.link(rig)
bpy.context.view_layer.objects.active = rig
rig.select_set(True)
bpy.ops.object.mode_set(mode='EDIT')
for i in range(7):
    bone = arm.edit_bones.new('Flag_%02d' % i)
    bone.head = (0, 0, 1.85 - i * 0.92 / 7)
    bone.tail = (0, 0, 1.85 - (i + 1) * 0.92 / 7)
    if i:
        bone.parent = arm.edit_bones['Flag_%02d' % (i - 1)]
        bone.use_connect = True
bpy.ops.object.mode_set(mode='OBJECT')
for i in range(7):
    group = cloth.vertex_groups.new(name='Flag_%02d' % i)
    for index, vertex in enumerate(vertices):
        t = (index % NX) / (NX - 1) * 6
        weight = max(0, 1 - abs(t - i))
        if weight > 0:
            group.add([index], weight, 'REPLACE')
modifier = cloth.modifiers.new('BannerSkin', 'ARMATURE')
modifier.object = rig
cloth.parent = rig
for frame in range(0, 97, 4):
    for i, bone in enumerate(rig.pose.bones):
        bone.rotation_mode = 'XYZ'
        bone.rotation_euler.z = math.sin(frame / 96 * math.tau - i * 0.8) * 0.075 * i / 6
        bone.rotation_euler.y = math.sin(frame / 96 * math.tau * 2 - i * 0.7) * 0.035 * i / 6
        bone.keyframe_insert(data_path='rotation_euler', frame=frame)
rig.animation_data.action.name = 'Banner_Wind'
bpy.context.scene.render.fps = 24
bpy.context.scene.frame_start = 0
bpy.context.scene.frame_end = 96
bpy.context.scene.frame_set(0)
out = ROOT / 'assets/processed/banner_cloth_v06'
out.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=str(out / 'banner.blend'))
bpy.ops.export_scene.gltf(filepath=str(assembly.OUTPUT / 'banner_cloth.glb'), export_format='GLB',
                          export_animations=True, export_animation_mode='SCENE')
print('V04_WEAPONS_AND_BANNER_READY')
