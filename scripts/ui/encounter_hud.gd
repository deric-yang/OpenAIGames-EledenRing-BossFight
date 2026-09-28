class_name EncounterHUD
extends CanvasLayer

var encounter: Node
var root: Control
var player_track: VitalBar
var stamina_track: VitalBar
var boss_track: VitalBar
var boss_name: Control
var location_panel: Control
var location_label: Label
var lock_marker: Label
var victory_panel: Control
var reward_panel: Control
var death_panel: Control
var death_time := -1.0
var location_time := 0.0
var location_duration := 4.5
var victory_time := -1.0
var preview_mode := false

func setup(owner: Node, bus: CombatEventBus) -> void:
    encounter = owner
    layer = 20
    _build()
    bus.event_emitted.connect(_on_event)
    show_location("古战场遗迹")

func _label(text: String, font_size: int, color: Color) -> Label:
    var label := Label.new()
    label.text = text
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", color)
    label.add_theme_color_override("font_shadow_color", Color(0.02, 0.015, 0.01, 0.9))
    label.add_theme_constant_override("shadow_offset_y", 2)
    var font := load("res://assets/runtime/fonts/CormorantGaramond.ttf") as FontFile
    font.fallbacks = [load("res://assets/runtime/fonts/WeepingDunesSerifSC.ttf") as FontFile]
    label.add_theme_font_override("font", font)
    return label

func _panel(rect: Rect2, parent: Control = null) -> Control:
    var panel := Control.new()
    panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    (parent if parent else root).add_child(panel)
    panel.anchor_left = rect.position.x
    panel.anchor_top = rect.position.y
    panel.anchor_right = rect.end.x
    panel.anchor_bottom = rect.end.y
    return panel

func _text(parent: Control, text: String, font_size: int, color: Color, centered := true) -> Label:
    var label := _label(text, font_size, color)
    parent.add_child(label)
    label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    return label

func _vital(rect: Rect2, color: Color, delayed := true) -> VitalBar:
    var bar := VitalBar.new()
    root.add_child(bar)
    bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
    bar.anchor_left = rect.position.x
    bar.anchor_top = rect.position.y
    bar.anchor_right = rect.end.x
    bar.anchor_bottom = rect.end.y
    bar.fill_color = color
    bar.delayed_damage = delayed
    return bar

func _build() -> void:
    root = Control.new()
    root.name = "HUDRoot"
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(root)
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    player_track = _vital(Rect2(0.065, 0.055, 0.31, 0.019), Color("87362e"))
    stamina_track = _vital(Rect2(0.065, 0.085, 0.255, 0.015), Color("58734b"), false)
    boss_track = _vital(Rect2(0.18, 0.899, 0.64, 0.016), Color("8e342b"))
    boss_name = _panel(Rect2(0.18, 0.852, 0.64, 0.039))
    _text(boss_name, "王骸的守望者", 23, Color("ddd2b8"), false)

    location_panel = _panel(Rect2(0.22, 0.39, 0.56, 0.18))
    location_label = _text(location_panel, "古战场遗迹", 48, Color("e9e1cc"))
    var rule := ColorRect.new()
    rule.color = Color("ae9b73", 0.7)
    location_panel.add_child(rule)
    rule.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
    rule.offset_top = -3
    rule.mouse_filter = Control.MOUSE_FILTER_IGNORE

    victory_panel = _panel(Rect2(0.02, 0.38, 0.96, 0.19))
    var smoke := ColorRect.new()
    victory_panel.add_child(smoke)
    smoke.mouse_filter = Control.MOUSE_FILTER_IGNORE
    smoke.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var smoke_material := ShaderMaterial.new()
    smoke_material.shader = load("res://shaders/ui/victory_smoke.gdshader")
    smoke.material = smoke_material
    var title := _text(victory_panel, "Great Enemy Defeated", 58, Color("d9b85e"))
    title.name = "VictoryTitle"
    victory_panel.visible = false

    death_panel = _panel(Rect2(0.02, 0.38, 0.96, 0.19))
    var death_smoke := ColorRect.new()
    death_panel.add_child(death_smoke)
    death_smoke.mouse_filter = Control.MOUSE_FILTER_IGNORE
    death_smoke.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    death_smoke.material = smoke_material.duplicate()
    var death_title := _text(death_panel, "You Died", 66, Color("a3292b"))
    death_title.name = "DeathTitle"
    death_panel.visible = false

    reward_panel = _panel(Rect2(0.27, 0.665, 0.46, 0.20))
    var backing := RewardOrnament.new()
    reward_panel.add_child(backing)
    backing.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var reward_caption := _text(_panel(Rect2(0.32, 0.15, 0.57, 0.17), reward_panel), "获得道具", 16, Color("a99874"))
    reward_caption.name = "RewardCaption"
    var reward_title := _text(_panel(Rect2(0.32, 0.39, 0.57, 0.30), reward_panel), "霸王之枪", 29, Color("ead8af"))
    reward_title.name = "RewardTitle"
    var icon := TextureRect.new()
    _panel(Rect2(0.025,0.06,0.27,0.88),reward_panel).add_child(icon)
    icon.texture = load("res://assets/runtime/ui/v09/overlords-spear.png")
    icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
    reward_panel.visible = false
    lock_marker = _label("◇", 24, Color("ead5a0"))
    root.add_child(lock_marker)
    lock_marker.visible = false
    root.resized.connect(_fit_text)
    _fit_text()

func _fit_text() -> void:
    if not root:
        return
    var factor := clampf(root.size.x / 1280.0, 0.55, 1.4)
    reward_panel.find_child("RewardTitle",true,false).add_theme_font_size_override("font_size",int(29*factor))
    reward_panel.find_child("RewardCaption",true,false).add_theme_font_size_override("font_size",int(16*factor))
    death_panel.get_node("DeathTitle").add_theme_font_size_override("font_size", int(66 * factor))
    location_label.add_theme_font_size_override("font_size", int(48 * factor))
    victory_panel.get_node("VictoryTitle").add_theme_font_size_override("font_size", int(58 * factor))

func show_location(title: String, _subtitle := "") -> void:
    location_label.text = title
    location_time = location_duration
    location_panel.modulate.a = 0.0
    location_panel.visible = true

func show_victory() -> void:
    boss_track.visible = false
    boss_name.visible = false
    location_time = 0.0
    location_panel.visible = false
    victory_time = 0.0
    victory_panel.visible = true
    reward_panel.visible = true
    victory_panel.modulate.a = 0.0
    reward_panel.modulate.a = 0.0

func reset_display() -> void:
    boss_track.visible = true
    boss_name.visible = true
    player_track.set_value(1.0, true)
    boss_track.set_value(1.0, true)
    stamina_track.set_value(1.0, true)
    death_time = -1
    death_panel.visible = false
    victory_time = -1.0
    victory_panel.visible = false
    reward_panel.visible = false
    show_location("古战场遗迹")

func _on_event(event: Dictionary) -> void:
    match str(event.get("type", "")):
        "encounter_reset": reset_display()
        "victory": show_victory()
        "player_died":
            death_time = 0
            death_panel.visible = true
            death_panel.modulate.a = 0
            location_time = 0.0
            location_panel.visible = false

func _process(delta: float) -> void:
    if encounter and not preview_mode:
        player_track.set_value(encounter.player.hp / encounter.player.max_hp)
        boss_track.set_value(encounter.boss.hp / encounter.boss.max_hp)
        stamina_track.set_value(encounter.player.stamina / encounter.player.max_stamina)
        var engaged := true
        if encounter.has_method("boss_brain"):
            engaged = encounter.stage in ["fight","execution","review","explore","defeat"]
            boss_track.visible = engaged
            boss_name.visible = engaged
        var camera = encounter.camera_director
        var point: Vector3 = encounter.boss.global_position + Vector3.UP * 3.1
        lock_marker.visible = engaged and camera.locked_on and not camera.intro and not camera.is_position_behind(point)
        if lock_marker.visible:
            lock_marker.position = camera.unproject_position(point) - Vector2(12, 18)
    if death_time >= 0:
        death_time += delta
        death_panel.modulate.a = clampf((death_time-0.3)/1.0,0,1)
    location_time = maxf(0.0, location_time - delta)
    var elapsed := location_duration - location_time
    location_panel.modulate.a = minf(clampf(elapsed / 0.7, 0, 1), clampf(location_time / 1.0, 0, 1))
    if victory_time >= 0.0:
        victory_time += delta
        victory_panel.modulate.a = minf(clampf(victory_time / 0.3, 0, 1), clampf((3.2 - victory_time) / 0.7, 0, 1))
        reward_panel.modulate.a = minf(clampf((victory_time - 0.55) / 0.4, 0, 1), clampf((6.0 - victory_time) / 0.6, 0, 1))
        victory_panel.visible = victory_time < 3.2
        reward_panel.visible = victory_time < 6.0
        if victory_time >= 6.0:
            victory_time = -1.0
