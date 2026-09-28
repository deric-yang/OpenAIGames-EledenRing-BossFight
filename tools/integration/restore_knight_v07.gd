extends SceneTree
## Restore the complete authored skin without touching the reviewed animation library.
func _initialize(): call_deferred("run")
func run():
    var file := "res://assets/runtime/characters/v04/knight_animated.scn"
    var model: Node3D = load(file).instantiate()
    root.add_child(model)
    var original: Node3D = load("res://assets/runtime/characters/v04/knight.glb").instantiate()
    root.add_child(original)
    var source: MeshInstance3D = original.find_children("*","MeshInstance3D",true,false)[0]
    for old in model.find_children("Closed_Back_Armor","MeshInstance3D",true,false): old.free()
    for target in model.find_children("*","MeshInstance3D",true,false):
        target.mesh = source.mesh.duplicate(true)
        target.skin = source.skin.duplicate(true)
        for i in target.mesh.get_surface_count():
            var material: StandardMaterial3D = target.mesh.surface_get_material(i)
            if material and material.resource_name == "Knight_Charcoal_Cloth":
                material.albedo_color = Color(0.24,0.255,0.28)
    var scene := PackedScene.new()
    assert(scene.pack(model)==OK)
    assert(ResourceSaver.save(scene,file)==OK)
    var doc := GLTFDocument.new()
    var state := GLTFState.new()
    assert(doc.append_from_scene(model,state)==OK)
    assert(doc.write_to_filesystem(state,ProjectSettings.globalize_path(file.replace(".scn",".glb")))==OK)
    print("V07 complete knight restored; animation library retained")
    quit()
