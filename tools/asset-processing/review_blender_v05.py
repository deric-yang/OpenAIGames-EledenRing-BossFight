"""Set useful opening poses and render the assembled authoring scene for inspection."""
from __future__ import annotations

import json
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
FILE = ROOT / 'assets/processed/battlefield_v05/ancient-battlefield-v05.blend'
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
scene.camera.location = (42, -48, 45)
scene.camera.rotation_euler = (Vector((4, 46, 19))-scene.camera.location).to_track_quat('-Z','Y').to_euler()
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type == 'VIEW_3D':
            area.spaces.active.clip_end = 1000
            area.spaces.active.region_3d.view_distance = 110
            area.spaces.active.region_3d.view_location = (8, 36, 20)
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
readme = bpy.data.texts.get('READ_ME_场景说明')
if readme:
    readme.clear()
    readme.write('V05 古战场遗迹。玩家从低处登丘，王骸的守望者位于树下高地。\n已删除旧火堆，加入符文兵器与 Tripo 残柱断墙。\n移动完整角色使用 *_MOVE_THIS。角色与 WeaponGrip 需切换同名动作，辅助脚本见 Switch_Selected_Motion.py。\n红眼拖尾、剑气、雾和音乐以 Godot 实机为准。')
bpy.ops.wm.save_as_mainfile(filepath=str(FILE), compress=True)
out = ROOT / 'qa/polish-v05/blender-assembled.png'
scene.render.filepath = str(out)
bpy.ops.render.render(write_still=True)
report = {'actions': len(bpy.data.actions), 'armatures': len(bpy.data.armatures),
          'packed_images': sum(1 for image in bpy.data.images if image.packed_file),
          'render': str(out), 'file': str(FILE)}
(ROOT / 'qa/polish-v05/blender-validation.json').write_text(json.dumps(report, indent=2) + '\n')
print('BLENDER_VISUAL_QA_READY', json.dumps(report))
