extends SceneTree
var game: Node3D
const OUT := "res://qa/dialogue-victor-20260929/"

func _initialize() -> void: call_deferred("run")

func capture(file_name: String) -> void:
    game.dialogue.focused = true
    game.dialogue._process(0.2)
    await process_frame
    await process_frame
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + file_name + ".png"))

func run() -> void:
    game = load("res://scenes/playable_v04.tscn").instantiate()
    root.add_child(game)
    game.set_physics_process(false)
    game.dialogue.set_process(false)
    game.audio.start_ambient()
    game.player.position = game.world.ground(8, -41)
    game.player.face(game.boss.position)
    game.boss.face(game.player.position)
    game.crown_intro.start()
    game.crown_intro.set_process(false)
    game.crown_intro.sample(1.2)
    game.dialogue.crown_tick(1.2)
    await capture("01-crown-subtitle")
    game.crown_intro.handoff()
    game.crown_intro.advance(0.46)
    game.effects._process(4)
    game.effects.clear()
    game.hud.location_time = 0
    game.player.weapon.show()
    game.camera_director.intro = false
    game.camera_director.set_process(false)
    game.camera_director.global_position = game.boss.global_position + Vector3(9, 6, 15)
    game.camera_director.look_at(game.boss.global_position + Vector3(0, 3.4, 0))
    game.hud._process(0)
    await capture("02-rise-subtitle")
    game.boss.action(game.ROAR, "roar", [0.38], 0.85)
    game.boss.avatar.tick(0.6)
    await capture("03-roar-subtitle")
    game.win()
    game.dialogue._process(0.7)
    game.hud.show_victory()
    game.hud._process(1)
    await capture("04-victory-subtitle")
    game.dialogue.reset_encounter()
    game.hud.reset_display()
    game.stage = "defeat"
    game.player.hp = 0
    game.event_bus.emit_event("player_died", {})
    game.hud._process(1.4)
    game.dialogue.on_result(false)
    game.dialogue._process(0.7)
    await capture("05-defeat-subtitle")
    game.dialogue.stop()
    game.audio.reset_cues()
    game.queue_free()
    await process_frame
    quit()
