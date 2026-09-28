extends SceneTree
func _initialize(): call_deferred("run")
func run():
    var file := "res://assets/runtime/characters/v04/knight_animated.scn"
    var model: Node3D = load(file).instantiate()
    root.add_child(model)
    var removed := 0
    for node in model.find_children("*","MeshInstance3D",true,false):
        var mesh := ArrayMesh.new()
        for index in node.mesh.get_surface_count():
            var material: Material = node.get_active_material(index)
            if material and material.resource_name == "Knight_Charcoal_Cloth":
                removed += node.mesh.surface_get_arrays(index)[Mesh.ARRAY_INDEX].size()/3
                continue
            mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,node.mesh.surface_get_arrays(index))
            mesh.surface_set_material(mesh.get_surface_count()-1,material)
        node.mesh = mesh
    var scene := PackedScene.new()
    assert(scene.pack(model)==OK)
    assert(ResourceSaver.save(scene,file)==OK)
    var doc := GLTFDocument.new()
    var state := GLTFState.new()
    assert(doc.append_from_scene(model,state)==OK)
    assert(doc.write_to_filesystem(state,ProjectSettings.globalize_path(file.replace(".scn",".glb")))==OK)
    print("V06_CAPE_REMOVED_TRIANGLES ",removed)
    quit()
