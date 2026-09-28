"""Author a broad dune field and an animated translucent spirit standard in Blender."""

from __future__ import annotations

import json
import math
from pathlib import Path

import bpy


ROOT = Path(__file__).resolve().parents[2]


def clean_scene():
    """Start a new isolated asset scene."""
    bpy.ops.wm.read_factory_settings(use_empty=True)


def material(name, color, alpha=1.0, metallic=0.0):
    """Build an exportable glTF material driven by mesh color attributes."""
    result = bpy.data.materials.new(name)
    result.use_nodes = True
    result.diffuse_color = (*color, alpha)
    shader = result.node_tree.nodes.get('Principled BSDF')
    shader.inputs['Base Color'].default_value = (*color, 1)
    shader.inputs['Roughness'].default_value = 0.92
    shader.inputs['Metallic'].default_value = metallic
    shader.inputs['Alpha'].default_value = alpha
    if alpha < 1:
        result.surface_render_method = 'DITHERED'
        result.use_backface_culling = False
        shader.inputs['Emission Color'].default_value = (*color, 1)
        shader.inputs['Emission Strength'].default_value = 0.18
    return result


def mesh_object(name, vertices, faces, mat, colors=None):
    """Create a UV mapped, smoothly shaded mesh with optional vertex color."""
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    mesh.materials.append(mat)
    for face in mesh.polygons:
        face.use_smooth = True
    if colors:
        attribute = mesh.color_attributes.new(name='Color', type='FLOAT_COLOR', domain='POINT')
        for item, color in zip(attribute.data, colors):
            item.color = color
        node = mat.node_tree.nodes.new('ShaderNodeVertexColor')
        node.layer_name = 'Color'
        shader = mat.node_tree.nodes.get('Principled BSDF')
        mat.node_tree.links.new(node.outputs['Color'], shader.inputs['Base Color'])
    return obj


def original_dune_height(x, y):
    """Blend gentle central fighting ground into asymmetrical outer dune ridges."""
    radius = math.hypot(x * 0.96, y)
    blend = max(0.0, min(1.0, (radius - 30.0) / 62.0))
    blend = blend * blend * (3 - 2 * blend)
    broad = 3.0 + 2.0 * math.sin(x * 0.035 + y * 0.013)
    broad += 1.5 * math.cos(y * 0.042 - x * 0.016)
    ridges = 0.0
    for offset, amplitude, width in [(-125, 10, 15), (-75, 8, 13), (70, 9, 18), (125, 14, 22)]:
        crest = x * 0.35 + offset + 11 * math.sin(x * 0.023 + offset)
        distance = y - crest
        slope_width = width * (1.0 if distance < 0 else 2.4)
        ridges += amplitude * math.exp(-((distance / slope_width) ** 2))
    center = 1.7 * math.sin(x * 0.075 + y * 0.045) + 0.8 * math.cos(y * 0.13 - x * 0.04)
    center += 0.35 * math.sin(x * 0.21 + y * 0.09)
    old = center * (1 - blend) + (broad + ridges) * blend
    def smooth(a, b, value):
        """Match Godot smoothstep for deterministic terrain collision and placement."""
        t = max(0.0, min(1.0, (value - a) / (b - a)))
        return t * t * (3 - 2 * t)
    summit = 24 * smooth(-12, 45, y) * (1 - smooth(42, 110, abs(x - 8)))
    summit *= 1 - smooth(130, 178, y)
    arena = 1 - smooth(15, 37, math.hypot(x - 8, y - 68))
    plateau = 2 + 0.45 * math.sin(x * 0.06) + 0.35 * math.cos(y * 0.08)
    return old * (1 - arena) + plateau * arena + summit


def dune_height(x, y):
    """Flatten the complete respawn medallion, feathering smoothly into the climbing dune."""
    distance = math.hypot(x - 7, y - 26)
    t = max(0.0, min(1.0, (distance - 3.1) / (7.5 - 3.1)))
    weight = 1 - t * t * (3 - 2 * t)
    return original_dune_height(x, y) * (1 - weight) + original_dune_height(7, 26) * weight


def export_asset(asset_id, meta):
    """Save editable source, glTF and authoring metadata without paid generation."""
    directory = ROOT / 'assets/source' / asset_id
    directory.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(directory / 'source.blend'))
    bpy.ops.export_scene.gltf(
        filepath=str(directory / 'model.glb'), export_format='GLB',
        export_animations=True, export_morph=True, export_yup=True,
        export_animation_mode='SCENE', export_anim_scene_split_object=False,
        export_nla_strips_merged_animation_name='SlowWind',
    )
    (directory / 'authoring.json').write_text(json.dumps(meta, indent=2) + '\n')


def build_terrain():
    """Make a deterministic 320 by 360 metre terrain with usable central ground."""
    clean_scene()
    columns, rows = 161, 181
    vertices, faces, colors = [], [], []
    for row in range(rows):
        y = -180 + row * 2.0
        for column in range(columns):
            x = -160 + column * 2.0
            height = dune_height(x, y)
            vertices.append((x, y, height))
            grain = 0.004 * math.sin(x * 0.11) * math.cos(y * 0.12)
            tint = 0.01 * math.sin(y * 0.02) + height * 0.001 + grain
            colors.append((0.42 + tint, 0.285 + tint * 0.8, 0.17 + tint * 0.55, 1))
    for row in range(rows - 1):
        for column in range(columns - 1):
            index = row * columns + column
            faces.append((index, index + 1, index + columns + 1, index + columns))
    sand = material('WarmAshSand', (1, 1, 1))
    terrain = mesh_object('WeepingDunes_320x360m', vertices, faces, sand, colors)
    uv = terrain.data.uv_layers.new(name='TerrainUV')
    for loop in terrain.data.loops:
        coordinate = terrain.data.vertices[loop.vertex_index].co
        uv.data[loop.index].uv = ((coordinate.x + 160) / 320, (coordinate.y + 180) / 360)
    terrain['playable_center_radius_m'] = 30.0
    terrain['surface_role'] = 'render_mesh; create matching collision on integration'
    central = [z for x, y, z in vertices if math.hypot(x, y) <= 28]
    export_asset('dune_battlefield_v04', {
        'authoring': 'local Blender procedural art, editable source.blend', 'credits': 0,
        'size_m': [320, 360], 'grid_spacing_m': 2, 'triangles': len(faces) * 2,
        'central_radius_m': 30, 'central_height_range_m': [min(central), max(central)],
        'height_range_m': [min(v[2] for v in vertices), max(v[2] for v in vertices)],
        'collision': 'not yet attached to gameplay',
    })


def cloth_position(u, v):
    """Return a hanging banner with folds and a deliberately torn lower hem."""
    width, height = 3.2, 17.0
    bottom = 0.18 + 0.5 * (0.5 + 0.5 * math.sin(u * 29))
    bottom += 0.48 * (0.5 + 0.5 * math.cos(u * 67))
    x = (u - 0.5) * width + 0.18 * math.sin(v * 9) * (1 - v)
    y = 0.16 * math.sin(u * 13 + v * 3) + 0.38 * math.sin(v * 7) * (1 - v)
    z = bottom + v * (height - bottom)
    return (x, y, z)


def line_on_cloth(start, end, width, vertices, faces):
    """Place a narrow flat ornamental stroke on the cloth surface."""
    du, dv = end[0] - start[0], end[1] - start[1]
    length = math.hypot(du, dv)
    side = (-dv / length * width, du / length * width)
    index = len(vertices)
    for coordinate, sign in [(start, -1), (start, 1), (end, 1), (end, -1)]:
        u, v = coordinate[0] + sign * side[0], coordinate[1] + sign * side[1]
        x, y, z = cloth_position(u, v)
        vertices.append((x, y - 0.012, z))
    faces.append((index, index + 1, index + 2, index + 3))


def animate_cloth(obj):
    """Add two morph targets and a seamless four-second glTF wind cycle."""
    obj.shape_key_add(name='Basis')
    for name, phase in [('WindA', 0), ('WindB', math.pi / 2)]:
        key = obj.shape_key_add(name=name)
        for vertex in key.data:
            weight = max(0, 1 - vertex.co.z / 17.0)
            vertex.co.y += math.sin(vertex.co.z * 0.45 + phase) * 0.65 * weight
            vertex.co.x += math.cos(vertex.co.z * 0.34 + phase) * 0.2 * weight
        key.slider_min = -1
        for frame in range(0, 97, 8):
            key.value = math.sin(frame / 96 * math.tau + phase)
            key.keyframe_insert(data_path='value', frame=frame)
    obj.data.shape_keys.animation_data.action.name = obj.name + '_SlowWind'


def build_standard():
    """Make an animated ethereal standard with torn fabric and ghostly runes."""
    clean_scene()
    columns, rows = 25, 81
    vertices, faces, colors = [], [], []
    for row in range(rows):
        v = row / (rows - 1)
        for column in range(columns):
            u = column / (columns - 1)
            vertices.append(cloth_position(u, v))
            edge = min(1, min(u, 1 - u) * 14) * min(1, v * 12)
            colors.append((0.8, 0.78, 0.64, edge))
    for row in range(rows - 1):
        for column in range(columns - 1):
            index = row * columns + column
            if row < 6 and (column * 7 + row * 3) % 17 < 3:
                continue
            faces.append((index, index + 1, index + columns + 1, index + columns))
    cloth = mesh_object('SpiritStandard_TranslucentCloth', vertices, faces,
                        material('FadedIvorySoulCloth', (1, 1, 1), 0.28), colors)
    uv = cloth.data.uv_layers.new(name='ClothUV')
    for loop in cloth.data.loops:
        index = loop.vertex_index
        uv.data[loop.index].uv = (index % columns / (columns - 1), index // columns / (rows - 1))
    ornament_vertices, ornament_faces = [], []
    for side in [0.16, 0.84]:
        for index in range(20):
            v = 0.11 + index * 0.04
            line_on_cloth((side, v), (side, v + 0.025), 0.006, ornament_vertices, ornament_faces)
    for index in range(9):
        v = 0.2 + index * 0.077
        diamond = [(0.5, v + 0.025), (0.63, v), (0.5, v - 0.025), (0.37, v)]
        for start, end in zip(diamond, diamond[1:] + diamond[:1]):
            line_on_cloth(start, end, 0.006, ornament_vertices, ornament_faces)
        line_on_cloth((0.5, v - 0.03), (0.5, v + 0.03), 0.007, ornament_vertices, ornament_faces)
    runes = mesh_object('SpiritStandard_FadedRunes', ornament_vertices, ornament_faces,
                        material('GhostGoldRunes', (0.86, 0.81, 0.59), 0.45))
    for obj in [cloth, runes]:
        animate_cloth(obj)
    scene = bpy.context.scene
    scene.render.fps = 24
    scene.frame_start = 0
    scene.frame_end = 96
    scene.frame_set(0)
    export_asset('soul_standard_v04', {
        'authoring': 'local Blender mesh and morph animation', 'credits': 0,
        'size_m': [3.2, 17], 'cloth_alpha': 0.28, 'rune_alpha': 0.45,
        'animation': '4-second cyclic wind; glTF morph targets',
        'placement': 'lower hem anchored to terrain; translucent spirit cloth',
    })


if __name__ == '__main__':
    build_terrain()
    build_standard()
