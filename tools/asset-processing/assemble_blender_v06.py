"""Assemble an editable Blender battlefield using the game's placement manifest and animated skins."""
from __future__ import annotations

import json
import math
import random
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/processed/battlefield_v06'
CACHE = {}


def collection(name):
    """Create a scene collection for a visible authoring category."""
    value = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(value)
    return value


def import_objects(file):
    """Load glTF data and remove Blender's skeletal display helper geometry."""
    old = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(ROOT / file.removeprefix('res://')))
    objects = [o for o in bpy.data.objects if o not in old]
    helpers = set()
    for obj in objects:
        if obj.type == 'ARMATURE':
            for bone in obj.pose.bones:
                if bone.custom_shape:
                    helpers.add(bone.custom_shape)
                    bone.custom_shape = None
    for helper in helpers:
        if helper in objects:
            objects.remove(helper)
        bpy.data.objects.remove(helper, do_unlink=True)
    return objects


def template(file):
    """Share static geometry between instances, preserving independently movable placements."""
    if file in CACHE:
        return CACHE[file]
    objects = import_objects(file)
    master = bpy.data.collections.new('Source_' + Path(file).stem + '_' + str(len(CACHE)))
    for obj in objects:
        for owner in list(obj.users_collection):
            owner.objects.unlink(obj)
        master.objects.link(obj)
    CACHE[file] = master
    return master


def place(row, target):
    """Apply the Godot-to-Blender coordinate conversion to a linked collection instance."""
    obj = bpy.data.objects.new(Path(row['asset']).stem, None)
    obj.instance_type = 'COLLECTION'
    obj.instance_collection = template(row['asset'])
    target.objects.link(obj)
    x, y, z = row['position']
    obj.location = (x, -z, y)
    obj.rotation_euler.z = row['yaw']
    obj.scale = (row['scale'],) * 3
    obj['source_asset'] = row['asset']
    return obj


def actor(role, position, scale, yaw, target):
    """Import a deformable animated actor and parent its weapon to the baked grip marker."""
    objects = import_objects(f'res://assets/processed/animations_v06/{role}_animated.glb')
    wrapper = bpy.data.objects.new(role.title() + '_MOVE_THIS', None)
    target.objects.link(wrapper)
    for obj in objects:
        for owner in list(obj.users_collection):
            owner.objects.unlink(obj)
        target.objects.link(obj)
        if obj.parent not in objects:
            matrix = obj.matrix_world.copy()
            obj.parent = wrapper
            obj.matrix_world = matrix
    wrapper.location = position
    wrapper.rotation_euler.z = yaw
    wrapper.scale = (scale,) * 3
    grip = next(o for o in objects if o.name.startswith('WeaponGrip'))
    weapon = 'general_polearm' if role == 'general' else 'knight_sword'
    held = bpy.data.objects.new(role + '_Weapon', None)
    target.objects.link(held)
    held.instance_type = 'COLLECTION'
    held.instance_collection = template(f'res://assets/runtime/characters/v04/{weapon}.glb')
    held.parent = grip
    held.location.z = -0.95 if role == 'general' else -0.23
    if role == 'general':
        banner = bpy.data.objects.new('Flexible_Banner_7_Bones', None)
        target.objects.link(banner)
        banner.instance_type = 'COLLECTION'
        banner.instance_collection = template('res://assets/runtime/characters/v04/banner_cloth.glb')
        banner.parent = held
        banner.rotation_euler.z = math.pi
    wrapper['animation_note'] = 'Baked selected motions; switch action/strip in the Animation workspace. WeaponGrip has matching tracks.'
    return wrapper


def ground(x, y):
    """Match the runtime sand dune height function in Blender XY coordinates."""
    import importlib.util
    spec = importlib.util.spec_from_file_location('height', Path(__file__).with_name('build_dunes_v04.py'))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module.dune_height(x, y)


def move_to_collection(obj, target):
    """Keep all generated details in their user-facing authoring collection."""
    for owner in list(obj.users_collection):
        owner.objects.unlink(obj)
    target.objects.link(obj)


def material(name, color, emission=0):
    """Create a simple weathered or emissive viewport material."""
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get('Principled BSDF')
    shader.inputs['Base Color'].default_value = (*color, 1)
    shader.inputs['Roughness'].default_value = 0.9
    shader.inputs['Emission Color'].default_value = (*color, 1)
    shader.inputs['Emission Strength'].default_value = emission
    return mat


def main():
    """Build, pack, and save a complete editable scene without touching prior versions."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    terrain = collection('01_Dunes_and_Golden_Tree')
    debris = collection('02_Scattered_War_Remains')
    spirits = collection('03_Grounded_Spirit_Standards')
    actors = collection('04_Animated_Knight_and_General')
    fires = collection('05_Rune_Relics_and_Resurrection')
    lighting = collection('06_Lighting_and_Atmosphere')
    rows = json.loads((ROOT / 'qa/iteration-v06/placements.json').read_text())
    for row in rows:
        category = spirits if 'standard.glb' in row['asset'] else terrain if any(k in row['asset'] for k in ['terrain.glb', 'tree.glb']) else debris
        obj = place(row, category)
        if category == spirits:
            obj['ground_anchor'] = True
            for part in obj.instance_collection.objects:
                if part.type == 'MESH':
                    for mat in part.data.materials:
                        if mat and mat.use_nodes:
                            mat.node_tree.nodes.get('Principled BSDF').inputs['Alpha'].default_value = 0.32 if 'Runes' in mat.name else 0.105
    player_pos = (7, 26, ground(7, 26) + 0.05)
    actor('knight', player_pos, 1, math.pi, actors)
    actor('general', (8, 53, ground(8, 53) + 0.05), 4.324325, 0, actors)
    place({'asset':'res://assets/runtime/assembly/sigil.glb', 'position':[7, player_pos[2]-0.04, -26], 'yaw':0, 'scale':1}, fires)
    iron = material('Dusty_Iron', (0.06, 0.05, 0.04))
    wood = material('Charred_Wood', (0.04, 0.027, 0.017))
    fragments = {}
    for row in json.loads((ROOT / 'qa/iteration-v06/fragments.json').read_text()):
        kind = row['kind']
        if kind in fragments:
            obj = bpy.data.objects.new('Fragment', fragments[kind])
            debris.objects.link(obj)
        else:
            if kind == 0:
                bpy.ops.mesh.primitive_cylinder_add(vertices=9, radius=0.30, depth=0.06)
            elif kind == 1:
                bpy.ops.mesh.primitive_uv_sphere_add(segments=8, ring_count=4, radius=0.19)
            else:
                bpy.ops.mesh.primitive_cube_add(size=1)
            obj = bpy.context.object
            fragments[kind] = obj.data
            obj.data.materials.append(iron)
        obj.name = ['Broken_Shield', 'Discarded_Helmet', 'Broken_Blade', 'Armor_Plate'][kind]
        x, height, z = row['position']
        obj.location = (x, -z, height)
        a, yaw, c = row['angles']
        obj.rotation_euler = (a, -c, yaw)
        size = row['scale']
        dimensions = (0.1, 0.7, 0.025) if kind == 2 else (0.21, 0.31, 0.018)
        obj.scale = tuple(size * v for v in dimensions) if kind > 1 else (size,) * 3
        move_to_collection(obj, debris)
    rng = random.Random(927264)
    shaft_mesh = None
    for i in range(650):
        x, y = rng.uniform(-110, 110), rng.uniform(-85, 130)
        length = rng.uniform(0.4, 1.6)
        if shaft_mesh is None:
            bpy.ops.mesh.primitive_cylinder_add(vertices=5, radius=0.016, depth=1)
            obj = bpy.context.object
            shaft_mesh = obj.data
            shaft_mesh.materials.append(wood)
        else:
            obj = bpy.data.objects.new('Arrow', shaft_mesh)
            debris.objects.link(obj)
        obj.scale.z = length
        obj.name = 'Scattered_Broken_Arrow'
        obj.location = (x, y, ground(x, y) + 0.02)
        obj.rotation_euler = (math.pi * 0.48, rng.uniform(-0.3,0.3), rng.uniform(-math.pi,math.pi))
        move_to_collection(obj,debris)
    place({'asset':'res://assets/runtime/world/v05/rune_relics.glb',
           'position':[0, 0, 0], 'yaw':0, 'scale':1}, fires)
    world = bpy.data.worlds.new('Ashen_Gold_Sky')
    world.use_nodes = True
    world.node_tree.nodes['Background'].inputs['Color'].default_value = (0.17,0.15,0.13,1)
    world.node_tree.nodes['Background'].inputs['Strength'].default_value = 0.45
    bpy.context.scene.world = world
    sun_data = bpy.data.lights.new('Diffuse_Sun','SUN')
    sun_data.energy = 2.0
    sun_data.angle = 0.16
    sun = bpy.data.objects.new('Diffuse_Sun',sun_data)
    lighting.objects.link(sun)
    sun.rotation_euler = (math.radians(58),math.radians(-15),math.radians(-32))
    camera_data = bpy.data.cameras.new('Battlefield_Camera')
    camera = bpy.data.objects.new('Battlefield_Camera',camera_data)
    lighting.objects.link(camera)
    camera.location = (9,-40,ground(0,-28)+6)
    camera.rotation_euler = (Vector((0,0,4))-camera.location).to_track_quat('-Z','Y').to_euler()
    camera_data.lens = 28
    camera_data.clip_end = 700
    scene = bpy.context.scene
    scene.camera = camera
    scene.render.engine = 'CYCLES'
    scene.cycles.samples = 24
    scene.render.resolution_x = 1440
    scene.render.resolution_y = 900
    scene.render.resolution_percentage = 100
    scene.render.fps = 30
    scene.frame_end = 240
    scene.frame_set(0)
    text = bpy.data.texts.new('READ_ME_场景说明')
    text.write('V04 完整拼装。集合按场景/残骸/魂幡/角色/火源分类。移动角色请选 *_MOVE_THIS 空对象。\n角色 GLB 已烘焙所选动作，使用 Animation / NLA 切换动作，WeaponGrip 包含同步武器挂点轨道。\n运行时披风与旗布风动、Godot雾层/光束和粒子效果以游戏实现为准。此 Blender 文件保留骨架、旗布动作与可编辑场景对象。\n静态资产使用 linked collection 复用，可在 Object > Apply > Make Instances Real 后单独编辑。\n')
    bpy.ops.file.pack_all()
    OUT.mkdir(parents=True,exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'ancient-battlefield-v06.blend'),compress=True)
    report = {'objects':len(bpy.data.objects),'collections':len(bpy.data.collections),'actions':len(bpy.data.actions),
              'armatures':len(bpy.data.armatures),'placements':len(rows),'file':str(OUT/'ancient-battlefield-v06.blend')}
    (OUT/'assembly.json').write_text(json.dumps(report,indent=2)+'\n')
    print('BLENDER_ASSEMBLY_READY',json.dumps(report))


if __name__ == '__main__':
    main()
