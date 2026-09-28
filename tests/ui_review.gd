extends SceneTree

var failures := 0
var checks := 0

func _init() -> void:
    call_deferred("_run")

func check(condition: bool, message: String) -> void:
    checks += 1
    if not condition:
        failures += 1
        push_error(message)

func capture(label: String) -> void:
    await process_frame
    if DisplayServer.get_name() != "headless":
        await RenderingServer.frame_post_draw
        root.get_texture().get_image().save_png("res://qa/ui-v01/" + label + ".png")

func _run() -> void:
    DirAccess.make_dir_recursive_absolute("res://qa/ui-v01")
    var bar := VitalBar.new()
    bar.set_value(0.7)
    bar.advance(0.9)
    check(is_equal_approx(bar.trail, 1.0), "damage trail must hold for one second")
    bar.advance(0.4)
    check(bar.trail < 1.0 and bar.trail > 0.7, "damage trail must shrink after hold")
    bar.advance(1.0)
    check(is_equal_approx(bar.trail, 0.7), "damage trail must reach actual value")
    bar.set_value(1.0, true)
    for index in range(8):
        bar.set_value(0.95 - index * 0.1)
        bar.advance(0.3)
    check(bar.trail < 0.9, "continuous hits must not freeze trail indefinitely")
    bar.set_value(1.0, true)
    check(bar.hold_left == 0.0 and bar.trail == 1.0, "reset clears ghost history")
    bar.free()
    var player := PlayerController.new()
    check(player.spend_stamina(26), "roll cost accepted")
    check(player.stamina == 74, "roll consumes 26 stamina")
    check(not player.spend_stamina(90), "insufficient stamina rejects action")
    player.recover_stamina(0.5)
    check(player.stamina == 74, "recovery has delay")
    player.recover_stamina(0.65)
    check(is_equal_approx(player.stamina, 88), "recovery applies only elapsed unheld time")
    player.reset_state()
    check(player.stamina == 100, "respawn restores stamina")
    player.free()
    var scene = load("res://scenes/ui_preview.tscn").instantiate()
    root.add_child(scene)
    await process_frame
    var hud: EncounterHUD = scene.hud
    hud.set_process(false)
    hud._process(1.1)
    await capture("01-location")
    check(is_equal_approx(hud.location_panel.anchor_left + hud.location_panel.anchor_right, 1.0), "location centered")
    hud.location_time = 0.0
    hud._process(0.01)
    hud.player_track.set_value(0.65)
    hud.boss_track.set_value(0.72)
    await capture("02-damage")
    hud.show_victory()
    hud._process(1.0)
    await capture("03-victory")
    check(hud.victory_panel.visible and hud.reward_panel.visible, "victory and reward visible")
    hud._process(2.3)
    check(not hud.victory_panel.visible and hud.reward_panel.visible, "reward outlasts victory")
    await capture("04-reward")
    hud.reset_display()
    check(not hud.victory_panel.visible and not hud.reward_panel.visible, "reset clears victory and reward")
    root.content_scale_size = Vector2i(1024, 768)
    root.size = Vector2i(1024, 768)
    hud.show_victory()
    hud._process(1.0)
    await capture("05-four-three")
    print("UI_REVIEW checks=%d failures=%d" % [checks, failures])
    quit(1 if failures else 0)
