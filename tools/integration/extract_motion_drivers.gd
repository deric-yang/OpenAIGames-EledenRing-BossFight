extends SceneTree
## Build compact skeleton/animation drivers from the selected source clips.
const WORKSPACE = "/Users/yangjianwen/Documents/aistudio/Gamebench"
const OLD = WORKSPACE + "/projects/sekiro-combat/rebuild"
const OUT = "res://assets/runtime/motions/v04/"

func _initialize() -> void:
    call_deferred("build")

func load_gltf(file: String) -> Node3D:
    var doc := GLTFDocument.new()
    var state := GLTFState.new()
    var err := doc.append_from_file(file, state)
    assert(err == OK, "Cannot read " + file)
    return doc.generate_scene(state)

func strip_meshes(node: Node) -> void:
    for child in node.get_children():
        if child is MeshInstance3D:
            child.free()
        else:
            strip_meshes(child)

func own_nodes(node: Node, owner_node: Node) -> void:
    for child in node.get_children():
        child.owner = owner_node
        own_nodes(child, owner_node)

func save_driver(model: Node3D, filename: String, keep: Array) -> Dictionary:
    root.add_child(model)
    strip_meshes(model)
    var players := model.find_children("*", "AnimationPlayer", true, false)
    assert(players.size() > 0)
    var player: AnimationPlayer = players[0]
    var lengths := {}
    for key in player.get_animation_library_list():
        var library := player.get_animation_library(key)
        for clip in library.get_animation_list():
            var full := str(key) + "/" + str(clip) if key != "" else str(clip)
            if full not in keep and clip != "RESET":
                library.remove_animation(clip)
            else:
                lengths[full] = library.get_animation(clip).length
    player.stop()
    own_nodes(model, model)
    var scene := PackedScene.new()
    assert(scene.pack(model) == OK)
    assert(ResourceSaver.save(scene, OUT + filename + ".scn") == OK)
    model.free()
    return lengths

func build() -> void:
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
    var selected: Array = JSON.parse_string(FileAccess.get_file_as_string("res://docs/iteration-v04/selected-motions.json"))
    var groups := {}
    for row in selected:
        var file: String = row.local_glb
        if not groups.has(file): groups[file] = []
        groups[file].append(row.id)
    var result := {}
    for file in groups:
        var name: String = str(file).get_file().get_basename()
        var lengths := save_driver(load_gltf(WORKSPACE + "/" + file), name, groups[file])
        for clip in groups[file]:
            assert(lengths.has(clip), "Missing selected animation " + clip)
            result[clip] = {"driver": OUT + name + ".scn", "clip": clip, "length": lengths[clip]}
    var model := load_gltf(OLD + "/assets/ual/AnimationLibrary_Godot_Standard.gltf")
    var player: AnimationPlayer = model.find_children("*", "AnimationPlayer", true, false)[0]
    player.add_animation_library("ual2", load(OLD + "/assets/ual2/retargeted.res"))
    var keep := ["Sword_Idle", "Walk_Loop", "Sprint_Loop", "Jog_Fwd_Loop", "Roll", "Hit_Chest", "Death01",
        "ual2/Sword_Regular_A", "ual2/Sword_Regular_B", "ual2/Sword_Regular_Combo", "ual2/Hit_Knockback_RM"]
    var lengths := save_driver(model, "player_ual", keep)
    for clip in keep:
        assert(lengths.has(clip), "Missing player clip " + clip)
        result[clip] = {"driver": OUT + "player_ual.scn", "clip": clip, "length": lengths[clip]}
    var f := FileAccess.open(OUT + "manifest.json", FileAccess.WRITE)
    f.store_string(JSON.stringify(result, "  ") + "\n")
    print("MOTION_DRIVERS_READY ", result.size())
    quit()
