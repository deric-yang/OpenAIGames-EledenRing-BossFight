extends SceneTree
var game: Node3D
var checks := 0
var failures: Array[String] = []
const OUT := "res://qa/dialogue-victor-20260929/"

func _initialize() -> void: call_deferred("run")

func check(ok: bool, description: String) -> void:
    checks += 1
    if not ok:
        failures.append(description)
        push_error(description)

func run() -> void:
    game = load("res://scenes/playable_v04.tscn").instantiate()
    root.add_child(game)
    game.set_physics_process(false)
    var dialog: WardenDialogue = game.dialogue
    dialog.set_process(false)
    dialog.focused = true
    var font: Font = dialog.subtitle.get_theme_font("font")
    check(dialog.streams.size() == 6, "All six generated Victor recordings are imported")
    for id in dialog.lines:
        check(dialog.streams[id].get_length() > 3 and dialog.streams[id].get_length() < 9, "Valid recording duration: " + id)
        check(not dialog.streams[id].loop, "Voice is one-shot: " + id)
        var complete := true
        for letter in dialog.lines[id].zh: complete = complete and font.has_char(letter.unicode_at(0))
        check(complete, "Chinese subtitle has every glyph: " + id)
    check(dialog.subtitle.anchor_top > game.hud.boss_track.anchor_bottom, "Subtitle is below the Boss health bar")
    check(dialog.subtitle.anchor_bottom < 0.97, "Subtitle leaves the controls footer clear")
    game.audio.start_ambient()
    game.crown_intro.start()
    game.crown_intro.set_process(false)
    game.crown_intro.advance(0.4)
    check(dialog.current_id == "", "Crown voice waits for initial reveal")
    game.crown_intro.advance(0.2)
    check(dialog.current_id == "crown" and dialog.voice.playing, "Crown dissolution triggers real Victor audio")
    check(not game.hud.root.visible and dialog.subtitle.visible and dialog.canvas.layer > game.crown_intro.canvas.layer, "Subtitles remain visible over cinematic bars when HUD is hidden")
    dialog._process(0.2)
    check(dialog.subtitle.modulate.a == 1 and dialog.subtitle.text == dialog.lines.crown.zh, "Chinese subtitle fades in with spoken line")
    dialog._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
    var old_age := dialog.age
    dialog._process(2)
    check(dialog.voice.stream_paused and dialog.age == old_age, "Focus loss pauses both voice and subtitle")
    dialog._notification(NOTIFICATION_APPLICATION_FOCUS_IN)
    check(not dialog.voice.stream_paused, "Focus return resumes existing recording")
    game.crown_intro.was_skipped = true
    game.crown_intro.handoff()
    check(dialog.current_id == "" and not dialog.voice.playing and not dialog.subtitle.visible, "Skipping clears unfinished crown voice and subtitle")
    game.crown_intro.advance(0.46)
    check(game.boss.state == "getup" and dialog.current_id == "challenge", "Challenge begins with actual rise, including skipped intro")
    game.crown_intro.finish()
    check(dialog.play_counts.get("challenge", 0) == 1, "Repeated finish cannot duplicate challenge")

    game.reset()
    check(not dialog.voice.playing and dialog.pending_id == "" and dialog.seen.is_empty(), "Restart clears all audio, subtitles and one-shot flags")
    game.crown_intro.cancel_waiting()
    game.stage = "fight"
    dialog.heavy_choice = 2
    var heavy := "combat-master-30eb25c4486f5e68e256"
    game.start_boss_attack(heavy)
    check(dialog.current_id == "", "Heavy line can skip the first eligible attack")
    game.start_boss_attack(heavy)
    check(dialog.current_id == "heavy", "Selected random heavy starts its line at animation entry")
    game.start_boss_attack(heavy)
    check(dialog.play_counts.get("heavy", 0) == 1, "Heavy speech is limited to once per encounter")
    game.audio.set_combat(true, false)
    game.audio._process(3)
    check(is_equal_approx(game.audio.music.volume_db, BattleAudio.MUSIC_GAIN - 9), "Music ducks by 9 dB under dialogue")
    game.boss.action(game.ROAR, "roar", [0.38], 0.85)
    check(dialog.current_id == "roar" and dialog.play_counts.get("roar", 0) == 1, "Actual roar replaces lower priority speech")
    check(game.audio.cue_counts.get("boss_roar", 0) == 0, "Spoken roar replaces overlapping monster roar")
    dialog.stop()
    game.boss.action(game.ROAR, "roar", [0.38], 0.85)
    check(dialog.current_id == "" and game.audio.cue_counts.get("boss_roar", 0) == 1, "Later roars use normal sound without repeating words")

    dialog.reset_encounter()
    game.audio.reset_cues()
    game.stage = "fight"
    game.player.hp = 1
    game.player.idle()
    game.boss.position = game.world.ground(8, -53)
    game.player.position = game.boss.position + Vector3(0, 0, 3)
    game.player.position.y = DuneHeightV04.sample(game.player.position.x, game.player.position.z)
    game.start_boss_attack(heavy)
    game.contact(game.boss, 0)
    check(game.stage == "defeat" and dialog.pending_id == "player_fallen", "Real lethal hit schedules defeat dialogue")
    check(dialog.current_id == "", "Result clears stale combat line before playing")
    dialog._process(0.66)
    check(dialog.current_id == "player_fallen" and dialog.voice.playing, "Defeat line starts after announcement onset")
    dialog.on_result(false)
    check(dialog.play_counts.get("player_fallen", 0) == 1, "Repeated death never loops the line")
    check(not dialog.say("heavy", true), "Battle lines cannot interrupt terminal dialogue")
    check(game.audio.cue_counts.get("player_death", 0) == 1, "Sword-drop cue stays once only")

    game.reset()
    game.crown_intro.cancel_waiting()
    game.stage = "fight"
    game.win()
    dialog._process(0.66)
    check(dialog.current_id == "warden_fallen", "Boss defeat plays homecoming line")
    check(game.commands.available(), "Voice does not block existing post-victory movement")
    dialog._voice_finished()
    dialog._process(0.36)
    check(not dialog.subtitle.visible and not game.audio.dialogue_active, "Finished speech clears subtitle and releases music")
    game.audio.set_combat(true, false)
    game.audio._process(2)
    check(is_equal_approx(game.audio.music.volume_db, BattleAudio.MUSIC_GAIN), "Music restores original level after speech")
    dialog.reset_encounter()
    dialog.on_result(true)
    game.reset()
    dialog._process(2)
    check(dialog.current_id == "" and dialog.pending_id == "", "Restart cancels pending delayed result line")

    # Exercise the real decoder and AudioStreamPlayer.finished signal.
    dialog.set_process(true)
    dialog.focused = true
    dialog.say("crown", true)
    await create_timer(4.9).timeout
    check(dialog.current_id == "" and not dialog.voice.playing and not dialog.subtitle.visible, "Actual MP3 playback ends and cleans itself up")
    var report := {"checks": checks, "failures": failures}
    FileAccess.open(OUT + "regression.json", FileAccess.WRITE).store_string(JSON.stringify(report, "  "))
    print("WARDEN_DIALOGUE_TEST ", JSON.stringify(report))
    game.audio.reset_cues()
    game.queue_free()
    await process_frame
    await create_timer(0.15).timeout
    quit(0 if failures.is_empty() else 1)
