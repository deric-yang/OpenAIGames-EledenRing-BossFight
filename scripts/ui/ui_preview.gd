extends Control
## Interactive lab using the same HUD implementation as the game.

var hud: EncounterHUD
var bus: CombatEventBus
var preview_epoch := 0

func _ready() -> void:
    var background := TextureRect.new()
    add_child(background)
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var atlas := AtlasTexture.new()
    atlas.atlas = load("res://assets/runtime/ui/review-background.png")
    atlas.region = Rect2(0, 0, 1536, 568)
    background.texture = atlas
    background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    background.modulate = Color(0.72, 0.72, 0.72)
    bus = CombatEventBus.new()
    add_child(bus)
    hud = EncounterHUD.new()
    add_child(hud)
    hud.preview_mode = true
    hud.setup(null, bus)
    var controls := CanvasLayer.new()
    controls.layer = 30
    add_child(controls)
    var column := VBoxContainer.new()
    controls.add_child(column)
    column.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
    column.position = Vector2(get_viewport_rect().size.x - 235, 24)
    column.size.x = 210
    var caption := hud._label("", 16, Color("e4d9bb"))
    caption.text = "UI 预览 · 概念图背景\n1 受伤  2 耗耐力  3 Boss受伤\n4 复活  5 胜利  6 连续受伤"
    column.add_child(caption)
    for item in [["玩家受伤", 1], ["耐力消耗", 2], ["Boss 受伤", 3], ["出生 / 复活", 4], ["击败 Boss / 奖励", 5], ["连续受伤", 6], ["胜利定格 · 7", 7]]:
        var button := Button.new()
        button.add_theme_font_override("font", hud.location_label.get_theme_font("font"))
        button.text = item[0]
        column.add_child(button)
        button.pressed.connect(_action.bind(item[1]))
    get_viewport().size_changed.connect(func(): column.position.x = get_viewport_rect().size.x - 235)

func _unhandled_key_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode >= KEY_1 and event.keycode <= KEY_7:
            _action(event.keycode - KEY_0)

func _action(action: int) -> void:
    hud.set_process(true)
    match action:
        1: hud.player_track.set_value(maxf(0.0, hud.player_track.value - 0.18))
        2: hud.stamina_track.set_value(maxf(0.0, hud.stamina_track.value - 0.26))
        3: hud.boss_track.set_value(maxf(0.0, hud.boss_track.value - 0.14))
        4:
            preview_epoch += 1
            hud.reset_display()
        5: hud.show_victory()
        6:
            var epoch := preview_epoch
            _action(1)
            await get_tree().create_timer(0.35).timeout
            if epoch != preview_epoch:
                return
            _action(1)
            await get_tree().create_timer(0.35).timeout
            if epoch != preview_epoch:
                return
            _action(1)
        7:
            preview_epoch += 1
            hud.reset_display()
            hud.show_victory()
            hud._process(1.0)
            hud.set_process(false)

func _process(delta: float) -> void:
    if hud and hud.stamina_track.value < 1.0:
        hud.stamina_track.set_value(minf(1.0, hud.stamina_track.value + delta * 0.12))
