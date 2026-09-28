"""Set useful opening poses and render the assembled authoring scene for inspection."""
from __future__ import annotations

import json
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
FILE = ROOT / 'assets/processed/battlefield_v04/weeping-dunes-v04.blend'
bpy.ops.wm.open_mainfile(filepath=str(FILE))
for obj in bpy.data.objects:
    animation = obj.animation_data
    if not animation:
        continue
    for track in animation.nla_tracks:
        if track.name == 'Sword_Idle':
            strip = track.strips[0]
            animation.action = strip.action
            animation.action_slot = strip.action_slot
            break
scene = bpy.context.scene
scene.frame_set(12)
scene.render.threads_mode = 'FIXED'
scene.render.threads = 4
scene.cycles.samples = 16
scene.cycles.use_denoising = True
scene.render.resolution_x = 1280
scene.render.resolution_y = 800
scene.camera.location = (5, -47, 4)
scene.camera.rotation_euler = (Vector((0, -10, 1))-scene.camera.location).to_track_quat('-Z','Y').to_euler()
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type == 'VIEW_3D':
            area.spaces.active.clip_end = 1000
            area.spaces.active.region_3d.view_distance = 48
            area.spaces.active.region_3d.view_location = (0, 0, 4)
            area.spaces.active.shading.type = 'MATERIAL'
bpy.ops.object.select_all(action='DESELECT')
knight = bpy.data.objects['Knight_MOVE_THIS']
knight.select_set(True)
bpy.context.view_layer.objects.active = knight
text = bpy.data.texts.new('Switch_Selected_Motion.py')
text.write('''"""Run this text once; then call set_motion in Blender's Python Console."""
import bpy
def set_motion(role, clip):
    wrapper = bpy.data.objects[role.title() + '_MOVE_THIS']
    for obj in wrapper.children_recursive:
        data = obj.animation_data
        if not data:
            continue
        for track in data.nla_tracks:
            track.mute = True
            if track.name == clip:
                strip = track.strips[0]
                data.action = strip.action
                data.action_slot = strip.action_slot
                bpy.context.scene.frame_end = int(strip.frame_end)
    bpy.context.scene.frame_set(0)
# Example: set_motion('general', 'combat-master-38cb716005f9f62f42ec')
# Example: set_motion('knight', 'ual2__Sword_Regular_A')
''')
bpy.ops.wm.save_as_mainfile(filepath=str(FILE), compress=True)
out = ROOT / 'qa/playable-v04/blender-assembled.png'
scene.render.filepath = str(out)
bpy.ops.render.render(write_still=True)
report = {'actions': len(bpy.data.actions), 'armatures': len(bpy.data.armatures),
          'packed_images': sum(1 for image in bpy.data.images if image.packed_file),
          'render': str(out), 'file': str(FILE)}
(ROOT / 'qa/playable-v04/blender-validation.json').write_text(json.dumps(report, indent=2) + '\n')
print('BLENDER_VISUAL_QA_READY', json.dumps(report))
