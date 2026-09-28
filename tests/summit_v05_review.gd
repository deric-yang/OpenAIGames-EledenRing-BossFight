extends SceneTree
var game: Node3D
var out := "res://qa/polish-v05/"
func _initialize() -> void: call_deferred("run")
func settle_camera() -> void:
    for i in 90: game.camera_director._process(1.0/60)
func shot(file: String) -> void:
    await process_frame
    await process_frame
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(ProjectSettings.globalize_path(out+file+".png"))
func run() -> void:
    game = load("res://scenes/playable_v04.tscn").instantiate()
    root.add_child(game)
    game.set_physics_process(false)
    await physics_frame
    game.effects.clear()
    game.player.avatar.model.visible=true
    game.player.weapon.visible=true
    game.player.avatar.play_clip("Sword_Idle",true,1,0)
    game.boss.avatar.play_clip("Sword_Idle",true,1,0)
    game.player.avatar.tick(0.02)
    game.player.weapon.tick(0.02)
    game.boss.avatar.tick(0.02)
    game.boss.weapon.tick(0.02)
    game.boss.eyes.tick(0.02)
    game.camera_director.intro=false
    game.camera_director.set_process(false)
    game.stage="ready"
    game.hud.location_time=0
    settle_camera()
    await shot("ascent-spawn")
    game.player.position=game.world.ground(8,-24)
    settle_camera()
    await shot("ascent-midway")
    game.player.position=game.world.ground(8,-55)
    settle_camera()
    await shot("summit-warden")
    FileAccess.open(out+"placements.json",FileAccess.WRITE).store_string(JSON.stringify(game.world.placements,"  "))
    FileAccess.open(out+"fragments.json",FileAccess.WRITE).store_string(JSON.stringify(game.world.fragment_placements))
    # Preserve the authored luminous blade geometry for the editable Blender assembly.
    var relics: Node3D = game.world.find_children("*","LuminousRelics",true,false)[0]
    var export_root := Node3D.new()
    root.add_child(export_root)
    for child in relics.get_children():
        if child is MeshInstance3D and child.mesh is ImmediateMesh:
            var copy := MeshInstance3D.new()
            var array_mesh := ArrayMesh.new()
            for surface in child.mesh.get_surface_count():
                array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,child.mesh.surface_get_arrays(surface))
            copy.mesh=array_mesh
            copy.material_override=child.material_override
            export_root.add_child(copy)
            copy.owner=export_root
    var doc := GLTFDocument.new()
    var state := GLTFState.new()
    assert(doc.append_from_scene(export_root,state)==OK)
    assert(doc.write_to_filesystem(state,ProjectSettings.globalize_path("res://assets/runtime/world/v05/rune_relics.glb"))==OK)
    print("V05_SUMMIT_REVIEW_DONE")
    quit()
