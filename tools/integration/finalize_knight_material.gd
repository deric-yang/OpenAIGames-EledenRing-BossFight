extends SceneTree
func _initialize(): call_deferred("run")
func run():
    var file := "res://assets/runtime/characters/v04/knight_animated.scn"
    var model: Node3D = load(file).instantiate()
    root.add_child(model)
    for mesh in model.find_children("*","MeshInstance3D",true,false):
        for i in mesh.mesh.get_surface_count():
            var material: StandardMaterial3D = mesh.get_active_material(i)
            if material.resource_name == "Knight_Charcoal_Cloth":
                material.albedo_color = Color(0.24,0.255,0.28)
    var scene := PackedScene.new()
    assert(scene.pack(model)==OK)
    assert(ResourceSaver.save(scene,file)==OK)
    var doc := GLTFDocument.new()
    var state := GLTFState.new()
    assert(doc.append_from_scene(model,state)==OK)
    assert(doc.write_to_filesystem(state,ProjectSettings.globalize_path(file.replace(".scn",".glb")))==OK)
    print("CHARCOAL_CLOAK_FINALIZED")
    quit()
