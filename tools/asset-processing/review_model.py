"""Inspect and render a generated source GLB without modifying the original."""
from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
import sys

import bpy
from mathutils import Vector


def arguments():
    """Read arguments passed after Blender's separator."""
    parser = argparse.ArgumentParser()
    parser.add_argument('--source', required=True)
    parser.add_argument('--output', required=True)
    parser.add_argument('--front-angle', type=float, default=0.0)
    parser.add_argument('--elevation', type=float, default=4.0)
    parser.add_argument('--samples', type=int, default=24)
    parser.add_argument('--raking-light', action='store_true')
    return parser.parse_args(sys.argv[sys.argv.index('--') + 1:])


def aim(obj, target):
    """Point a camera or light toward the requested world position."""
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat('-Z', 'Y').to_euler()


def light(name, location, energy, size):
    """Add a neutral studio area light."""
    data = bpy.data.lights.new(name, 'AREA')
    data.energy = energy
    data.shape = 'DISK'
    data.size = size
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    obj.location = location
    aim(obj, (0, 0, 1.1))


def main():
    """Normalize only the review scene and render three diagnostic angles."""
    args = arguments()
    output = Path(args.output).resolve()
    output.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(Path(args.source).resolve()))
    imported = list(bpy.context.scene.objects)
    helpers = set()
    for obj in imported:
        if obj.type == 'ARMATURE':
            for bone in obj.pose.bones:
                if bone.custom_shape:
                    helpers.add(bone.custom_shape)
                    bone.custom_shape = None
    for helper in helpers:
        if helper in imported:
            imported.remove(helper)
        bpy.data.objects.remove(helper, do_unlink=True)
    meshes = [obj for obj in imported if obj.type == 'MESH']
    points = [obj.matrix_world @ Vector(corner) for obj in meshes for corner in obj.bound_box]
    minimum = Vector(tuple(min(point[index] for point in points) for index in range(3)))
    maximum = Vector(tuple(max(point[index] for point in points) for index in range(3)))
    dimensions = maximum - minimum
    report = {
        'source': str(Path(args.source).resolve()),
        'mesh_objects': len(meshes),
        'vertices': sum(len(obj.data.vertices) for obj in meshes),
        'triangles': sum(sum(len(face.vertices) - 2 for face in obj.data.polygons) for obj in meshes),
        'armatures': len([obj for obj in imported if obj.type == 'ARMATURE']),
        'dimensions_source': list(dimensions),
        'materials': [material.name for material in bpy.data.materials],
        'images': [{'name': image.name, 'size': list(image.size)} for image in bpy.data.images],
        'status': 'source_review_only_not_rigged_or_runtime_approved',
    }
    (output / 'inspection.json').write_text(json.dumps(report, indent=2) + '\n')
    root = bpy.data.objects.new('ReviewScale', None)
    bpy.context.collection.objects.link(root)
    for obj in imported:
        if obj.parent is None:
            obj.parent = root
    scale = 2.2 / max(dimensions)
    root.scale = Vector((scale, scale, scale))
    root.location = Vector((-(minimum.x + maximum.x) * 0.5 * scale,
                            -(minimum.y + maximum.y) * 0.5 * scale, -minimum.z * scale))
    scene = bpy.context.scene
    scene.render.threads_mode = 'FIXED'
    scene.render.threads = 4
    scene.render.engine = 'CYCLES'
    scene.cycles.samples = args.samples
    scene.cycles.use_denoising = True
    scene.render.resolution_x = 720
    scene.render.resolution_y = 840
    scene.render.resolution_percentage = 100
    scene.world = bpy.data.worlds.new('StudioWorld')
    scene.world.use_nodes = True
    scene.world.node_tree.nodes['Background'].inputs['Color'].default_value = (0.24, 0.24, 0.24, 1)
    scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value = 0.45
    light('Key', (3, -4, 5), 550, 4)
    light('Fill', (-3, -2, 2.8), 330, 4)
    light('Rim', (1, 3, 4), 650, 3)
    if args.raking_light:
        for obj in list(scene.objects):
            if obj.type == 'LIGHT':
                bpy.data.objects.remove(obj, do_unlink=True)
        scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value = 0.12
        light('LowSun', (-4, -2, 1), 650, 0.6)
        light('SkyFill', (2, 1, 4), 65, 5)
    bpy.ops.mesh.primitive_plane_add(size=200)
    floor = bpy.context.object
    floor.location.z = -0.012
    material = bpy.data.materials.new('StudioFloor')
    material.diffuse_color = (0.12, 0.12, 0.12, 1)
    floor.data.materials.append(material)
    camera_data = bpy.data.cameras.new('ReviewCamera')
    camera = bpy.data.objects.new('ReviewCamera', camera_data)
    bpy.context.collection.objects.link(camera)
    camera_data.type = 'ORTHO'
    camera_data.ortho_scale = 3.05
    scene.camera = camera
    target = Vector((0, 0, dimensions.z * scale * 0.48))
    for name, degrees in [('front', 0), ('three-quarter', 45), ('back', 180)]:
        angle = math.radians(degrees + args.front_angle)
        camera.location = (math.sin(angle) * 5, -math.cos(angle) * 5,
                           target.z + math.tan(math.radians(args.elevation)) * 5)
        aim(camera, target)
        scene.render.filepath = str(output / (name + '.png'))
        bpy.ops.render.render(write_still=True)
    print('SOURCE_REVIEW ' + json.dumps(report))


if __name__ == '__main__':
    main()
