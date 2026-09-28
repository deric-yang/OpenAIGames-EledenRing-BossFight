"""Blender-side inspection code run through tools/blender-mcp/client.py."""

import bpy

PROJECT_TAG = "gilded-ruin-boss:weeping-dunes"

scenes = [scene.name for scene in bpy.data.scenes if scene.get("wd_owner") == PROJECT_TAG]
collections = [coll.name for coll in bpy.data.collections if coll.get("wd_owner") == PROJECT_TAG]
print("PROJECT_SCENES", scenes)
print("PROJECT_COLLECTIONS", collections)
for scene in bpy.data.scenes:
    if scene.get("wd_owner") != PROJECT_TAG:
        continue
    print("SCENE", scene.name, "CAMERA", scene.camera.name if scene.camera else None)
    print("STATUS", scene.get("assembly_status"), "PROVENANCE", scene.get("asset_provenance"))
    print("AXES", scene.get("axis_convention"), "NEGATIVE_DETERMINANT", scene.get("negative_determinant_mapping"))
    owned_objects = [obj for obj in scene.objects if obj.get("wd_owner") == PROJECT_TAG]
    print("OBJECT_COUNT", len(owned_objects))
    for obj in sorted(owned_objects, key=lambda item: item.name):
        if obj.name in {
            "WeepingDunes_Review_Camera",
            "WD_WeepingDunes_Review_Camera",
            "WD_Dune_Terrain_Undulation",
            "WD_Dune_Terrain_Substrate",
            "WD_BlackTree_Trunk_00",
            "WD_BlackTree_Root_00",
            "WD_Player_Blockout",
            "WD_Boss_Blockout",
            "WD_HangingVeil_Left",
        }:
            print("OBJECT", obj.name, "LOC", tuple(round(v, 3) for v in obj.location), "DIMS", tuple(round(v, 3) for v in obj.dimensions), "STATUS", obj.get("asset_status"))
duplicate_named_objects = sorted(obj.name for obj in bpy.data.objects if obj.get("wd_owner") == PROJECT_TAG and (".001" in obj.name or ".002" in obj.name))
print("PROJECT_DUPLICATE_SUFFIX_OBJECTS", duplicate_named_objects)
print("ALL_PROJECT_CAMERAS", sorted(obj.name for obj in bpy.data.objects if obj.get("wd_owner") == PROJECT_TAG and obj.get("asset_status") == "review-camera"))
print("ALL_PROJECT_LIGHTS", sorted(obj.name for obj in bpy.data.objects if obj.get("wd_owner") == PROJECT_TAG and obj.get("asset_status") == "procedural-light"))
print("ALL_PROJECT_MATERIALS", sorted(mat.name for mat in bpy.data.materials if mat.get("wd_owner") == PROJECT_TAG))
for prefix in ("WD_Boss_Blockout", "WD_Player_Blockout", "WD_Rubble_00"):
    print("NAME_DEBUG", prefix, [(obj.name, obj.get("wd_owner"), [coll.name for coll in obj.users_collection]) for obj in bpy.data.objects if obj.name.startswith(prefix)])
print("ACTIVE_SCENE", bpy.context.window.scene.name if bpy.context.window and bpy.context.window.scene else None)
