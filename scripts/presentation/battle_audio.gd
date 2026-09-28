class_name BattleAudio
extends Node
var manifest: Dictionary
var voices: Array[AudioStreamPlayer3D] = []
var ambient: AudioStreamPlayer
var scrape: AudioStreamPlayer3D
var cue_counts := {}
var announcements: Array[AudioStreamPlayer] = []
var music: AudioStreamPlayer
var music_target := -60.0
const FOOTSTEP_GAIN := -10.457575
const MUSIC_GAIN := -3.0
var rng := RandomNumberGenerator.new()
func _ready() -> void:
    manifest = JSON.parse_string(FileAccess.get_file_as_string("res://assets/runtime/audio/v04/manifest.json"))
    rng.randomize()
func start_ambient() -> void:
    if ambient: return
    ambient = AudioStreamPlayer.new()
    ambient.stream = load(manifest.ambient[0].file).duplicate()
    if ambient.stream is AudioStreamWAV:
        ambient.stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
    ambient.volume_db = -22
    ambient.pitch_scale = 0.84
    add_child(ambient)
    ambient.play()
func cue(id: String, position_at: Vector3, gain: float = 0.0, layered: bool = false) -> void:
    if id in ["boss_step","boss_run","player_step","player_steps_loop"]: return
    if not manifest.has(id): return
    if id == "player_death" and int(cue_counts.get(id,0)) > 0: return
    cue_counts[id] = int(cue_counts.get(id,0)) + 1
    for index in range(manifest[id].size() if layered else 1):
        var choice: int = index if layered else rng.randi_range(0,manifest[id].size()-1)
        while voices.size() >= 20:
            var old: AudioStreamPlayer3D = voices.pop_front()
            if is_instance_valid(old): old.queue_free()
        var player := AudioStreamPlayer3D.new()
        player.stream = load(manifest[id][choice].file).duplicate()
        # Imported WAV smpl loop metadata must never turn one-shot foley into a loop.
        if player.stream is AudioStreamWAV: player.stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
        elif player.stream is AudioStreamOggVorbis: player.stream.loop = false
        get_parent().add_child(player)
        player.global_position = position_at
        player.max_distance = 85
        player.unit_size = 10
        player.volume_db = -9 + gain + (FOOTSTEP_GAIN if id in ["boss_step","boss_run","player_step"] else 0.0)
        player.pitch_scale = rng.randf_range(0.95, 1.04)
        player.finished.connect(func(): voices.erase(player); player.queue_free())
        voices.append(player)
        player.play()

func foot_scrape(_position_at: Vector3, _moving: bool) -> void:
    if scrape: scrape.stop()

func reset_cues() -> void:
    for voice in announcements:
        if is_instance_valid(voice):
            voice.stop()
            voice.queue_free()
    announcements.clear()
    for voice in voices:
        if is_instance_valid(voice):
            voice.stop()
            voice.queue_free()
    voices.clear()
    cue_counts.clear()
    if scrape: scrape.stop()
    if music: music.stop()
    music_target = -60

func set_combat(active: bool) -> void:
    # Browser audio begins only after a gesture has started the ambient player.
    var audible := active and ambient != null
    music_target = MUSIC_GAIN if audible else -60.0
    if audible and not music:
        music = AudioStreamPlayer.new()
        music.stream = load("res://assets/runtime/audio/v05/battle_music.ogg")
        music.stream.loop = true
        music.volume_db = -60
        add_child(music)
    if audible and music and not music.playing: music.play()

func _process(delta: float) -> void:
    if not music: return
    music.volume_db = move_toward(music.volume_db,music_target,delta*28)
    if music_target <= -60 and music.volume_db <= -59.9 and music.playing: music.stop()

func _exit_tree() -> void:
    for voice in voices:
        if is_instance_valid(voice): voice.stop()
    voices.clear()
    if is_instance_valid(ambient): ambient.stop()
    if is_instance_valid(scrape): scrape.stop()
    if is_instance_valid(music): music.stop()

func announce(event: String) -> void:
    var key := "announcement_" + event
    if cue_counts.has(key): return
    cue_counts[key] = 1
    var voice := AudioStreamPlayer.new()
    voice.stream = load("res://assets/runtime/audio/v06/announcement.wav")
    voice.volume_db = -12
    add_child(voice)
    announcements.append(voice)
    voice.finished.connect(func(): announcements.erase(voice); voice.queue_free())
    voice.play()
