extends Node3D
@export var preview_mode := false
const EXECUTION = "combat-master-e07664ecc25243ebbfdc"
const INTRO = "combat-master-1409c47c83223aac5e53"
const ROAR = "combat-master-38cb716005f9f62f42ec"
const COUNTER = "combat-master-8dbbfe19c5e1ff8e0e88"
const STANDUP = "Warden_Rise"
const HEAVY = EXECUTION
const REMOVED = "combat-master-f19e2a7d3ad551bf0341"
const SLASH4 = "combat-master-e04e545ae5e634c10286"
const SLASH8 = "combat-master-3c8d3a0c2bc89d15c58e"
var world: BattlefieldV04
var player: BattleActor
var boss: BattleActor
var camera_director: BattleCamera
var audio: BattleAudio
var effects: BattleEffects
var skill_fx: WardenSkillEffects
var skills: Dictionary
var hazards: Array[Dictionary] = []
var last_boss_attack := ""
var event_bus: CombatEventBus
var hud: EncounterHUD
var stage := "intro"
var clock := 0.0
var ai_wait := 3.0
var attack_count := 0
var attack_pool: Array[String] = []
var motion_cursor := 0
var selected: Array = []
var boss_followup := ""
var director := WardenDirector.new()
var boss_closing := false
var boss_retreating := false
var pending_roar := false
var victory_wait := -1.0
var execution_struck := false
var status: Label
var performance_reported := false
var review_dashboard := false
var review_paused := false
var review_rate := 1.0
var rng := RandomNumberGenerator.new()
var crown_intro: Node3D
var crown_preview := false

func _ready() -> void:
    rng.seed = 927264
    world = BattlefieldV04.new()
    add_child(world)
    audio = BattleAudio.new()
    add_child(audio)
    effects = BattleEffects.new()
    add_child(effects)
    skill_fx = WardenSkillEffects.new()
    add_child(skill_fx)
    skills = JSON.parse_string(FileAccess.get_file_as_string("res://assets/runtime/combat/v06/warden-skills.json"))
    event_bus = CombatEventBus.new()
    add_child(event_bus)
    player = BattleActor.new()
    player.name = "SilverKnight"
    add_child(player)
    player.setup(self,"knight")
    boss = BattleActor.new()
    boss.name = "OldGeneral"
    add_child(boss)
    boss.setup(self,"general")
    camera_director = BattleCamera.new()
    camera_director.name = "BattleCamera"
    add_child(camera_director)
    camera_director.game = self
    camera_director.fov = 62
    camera_director.far = 650
    camera_director.current = true
    hud = EncounterHUD.new()
    add_child(hud)
    hud.setup(self,event_bus)
    status = Label.new()
    hud.root.add_child(status)
    status.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
    status.offset_left = 24
    status.offset_right = -24
    status.offset_top = -23
    status.offset_bottom = -2
    status.add_theme_font_size_override("font_size",12)
    selected = JSON.parse_string(FileAccess.get_file_as_string("res://assets/runtime/motions/v04/selected-motions.json"))
    for row in selected:
        if row.role == "boss" and "Attack" in row.category and row.id not in [COUNTER,HEAVY,REMOVED] and skills.has(row.id): attack_pool.append(row.id)
    selected = selected.filter(func(row): return row.id != REMOVED and (row.id != HEAVY or row.role != "boss"))
    crown_intro = preload("res://scripts/cinematic/crown_intro.gd").new()
    crown_intro.name = "CrownIntro"
    add_child(crown_intro)
    crown_intro.setup(self)
    reset()
    effects.warmup(player.global_position+Vector3.UP)
    if OS.has_feature("web"):
        review_dashboard = bool(JavaScriptBridge.eval("new URLSearchParams(location.search).has('motion-review')"))
        if review_dashboard:
            JavaScriptBridge.eval("window.__wardenCommand=null; window.addEventListener('message',e=>{if(e.origin===location.origin&&e.data?.type==='warden-motion')window.__wardenCommand=Object.assign(window.__wardenCommand||{},e.data);}); window.parent.postMessage({type:'warden-ready'},location.origin);")
    if OS.get_cmdline_user_args().has("--motion-review"): review_dashboard = true
    if review_dashboard:
        stage = "review"
        player.avatar.model.visible = false
        player.weapon.visible = false
        camera_director.review_camera = true
        hud.root.visible = false
        boss.action("Sword_Idle","review")
        boss.avatar.looping = true
    var direct_intro := OS.get_cmdline_user_args().has("--crown-intro")
    if OS.has_feature("web"):
        direct_intro = bool(JavaScriptBridge.eval("new URLSearchParams(location.search).has('crown-intro')"))
    if direct_intro and not review_dashboard:
        crown_preview = true
        start_crown_preview()

func start_crown_preview() -> void:
    player.position = world.ground(boss.position.x, boss.position.z + 12.0) + Vector3.UP * 0.05
    player.face(boss.position)
    boss.face(player.position)
    crown_intro.start()

func reset() -> void:
    if crown_intro: crown_intro.reset_sequence()
    director.reset()
    boss_closing = false
    boss_retreating = false
    last_boss_attack = ""
    shared_hitstop = 0
    pending_contacts.clear()
    effects.clear()
    skill_fx.clear()
    hazards.clear()
    audio.reset_cues()
    stage = "intro"
    camera_director.reset_execution()
    clock = 0
    victory_wait = -1
    boss_followup = ""
    pending_roar = false
    ai_wait = 2.2
    attack_count = 0
    player.reset_at(world.respawn_position + Vector3.UP * 0.05)
    boss.reset_at(world.boss_position)
    player.face(boss.global_position)
    boss.face(player.global_position)
    boss.idle()
    effects.materialize(player.avatar,true)
    player.weapon.visible = false
    camera_director.intro = true
    event_bus.emit_event("encounter_reset",{})
    if audio.ambient: audio.announce("spawn")
    if crown_preview and not review_dashboard: start_crown_preview()

func _unhandled_input(event: InputEvent) -> void:
    if crown_intro and crown_intro.active: return
    if event is InputEventKey and event.pressed and not event.echo:
        audio.start_ambient()
        if stage in ["intro","ready"] and not audio.cue_counts.has("announcement_spawn"):
            hud.show_location("古战场遗迹")
            audio.announce("spawn")
        if stage == "ready" and event.physical_keycode in [KEY_W,KEY_A,KEY_S,KEY_D,KEY_J,KEY_K,KEY_SPACE]: stage = "approach"
        if event.physical_keycode == KEY_R: reset()
        if event.physical_keycode == KEY_F: execute()
        if event.physical_keycode == KEY_B: review_next()
        if event.physical_keycode == KEY_F3: print_metrics()
        if event.physical_keycode == KEY_P:
            if stage in ["fight","approach","review","explore","ready"]:
                stage = "fight" if stage in ["review","explore"] else "explore"
                boss.idle()
    if event is InputEventMouseButton and event.pressed:
        audio.start_ambient()
        if stage in ["intro","ready"] and not audio.cue_counts.has("announcement_spawn"):
            hud.show_location("古战场遗迹")
            audio.announce("spawn")
        if stage == "ready" and event.button_index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]: stage = "approach"

var shared_hitstop := 0.0
var pending_contacts: Array[Dictionary] = []

func freeze_combat(frames: int) -> void:
    shared_hitstop = maxf(shared_hitstop,clampi(frames,6,10)/60.0)
    player.hitstop_left = shared_hitstop
    boss.hitstop_left = shared_hitstop

func queue_contact(actor: BattleActor, segment: int) -> void:
    pending_contacts.append({"actor":actor,"segment":segment})

func _physics_process(delta: float) -> void:
    if not player: return
    if crown_intro and crown_intro.active: return
    if review_dashboard:
        dashboard_tick(delta)
        return
    if shared_hitstop > 0:
        if Input.is_action_just_pressed("attack") and player.state=="attack" and not player.heavy_attack:
            player.queued = true
        shared_hitstop = maxf(0,shared_hitstop-delta)
        player.hitstop_left = shared_hitstop
        boss.hitstop_left = shared_hitstop
        return
    clock += delta
    tick_hazards(delta)
    if shared_hitstop > 0: return
    audio.set_combat(stage in ["fight","execution"])
    if not performance_reported and clock > 15:
        performance_reported = true
        print_metrics()
    var input := Input.get_vector("move_left","move_right","move_forward","move_back")
    var direction := camera_director.global_basis.x * input.x + camera_director.global_basis.z * input.y
    direction.y = 0
    direction = direction.normalized()
    if stage == "intro" and clock >= 3.2:
        stage = "explore" if preview_mode else "ready"
        player.weapon.visible = true
        camera_director.intro = false
    if stage in ["fight","approach","explore","review"]:
        if Input.is_action_just_pressed("roll") and player.state not in ["dead","execution","launch","pushback"] and player.stamina >= 25:
            player.stamina -= 25
            player.queued = false
            player.move_direction = direction if direction.length_squared() > 0.01 else player.forward()
            player.face(player.global_position+player.move_direction)
            player.action("Roll","roll",[],1.33333)
        if Input.is_action_just_pressed("heavy_attack") and player.state in ["idle","move"] and player.stamina >= 28:
            player_heavy_attack()
        if Input.is_action_just_pressed("attack") and player.stamina >= 16:
            if player.state in ["idle","move"]: player_attack(0 if player.time > 0.8 else player.combo)
            elif player.state == "attack" and not player.heavy_attack: player.queued = true
        if player.state in ["attack","execution"] and player.time < player.duration*0.2:
            player.face(boss.global_position,delta)
        if stage == "fight": boss_brain(delta)
    if stage == "approach":
        var approach_distance := Vector2(player.position.x-boss.position.x,player.position.z-boss.position.z).length()
        if approach_distance < 14 and absf(player.position.y-boss.position.y)<6:
            if not crown_intro.played:
                boss.face(player.global_position)
                crown_intro.start()
                return
            stage = "fight"
            boss.face(player.global_position)
            boss.action(INTRO,"intro",[],0.75)
            ai_wait = boss.duration+0.8
    if stage == "execution" and not execution_struck and player.time >= player.duration * 0.40:
        execution_struck = true
        audio.cue("execution",boss.global_position,3,true)
        for burst in 4:
            var hit_point := player.avatar.weapon_transform() * Vector3(0,1.12,0)
            effects.blood(hit_point + Vector3((burst-1.5)*0.22,burst*0.13,0),player.forward(),120)
        audio.cue("blood_hit",boss.global_position)
        boss.hp = maxf(0,boss.hp-120)
        camera_director.impulse(0.13,0.15)
        freeze_combat(10)
        return
    player.motion(delta,direction if stage in ["fight","approach","explore","review"] and player.hp > 0 else Vector3.ZERO,Input.is_action_pressed("sprint") and player.stamina > 8)
    var boss_direction := Vector3.ZERO
    if stage == "fight" and boss.state in ["idle","move"]:
        var offset := player.global_position-boss.global_position
        offset.y = 0
        var distance := offset.length()
        # Hysteresis avoids toggling run/strafe on alternating frames at one distance.
        if distance > 7.2: boss_closing = true
        elif distance < 5.5: boss_closing = false
        if distance < 2.7: boss_retreating = true
        elif distance > 4.1: boss_retreating = false
        if boss_closing: boss_direction = offset.normalized()
        elif boss_retreating: boss_direction = -offset.normalized()*0.65
        elif director.remaining == 0 and ai_wait > 0.4: boss_direction = boss.global_basis.x*0.4

    boss.motion(delta,boss_direction,boss.global_position.distance_to(player.global_position)>13)
    var contacts := pending_contacts.duplicate()
    pending_contacts.clear()
    for hit in contacts: contact(hit.actor,hit.segment)
    audio.foot_scrape(player.global_position,stage in ["fight","approach","explore","review"] and player.state == "move")
    if victory_wait >= 0:
        victory_wait -= delta
        if victory_wait <= 0:
            victory_wait = -1
            effects.materialize(boss.avatar,false)
            boss.weapon.visible = false
            audio.announce("victory")
            event_bus.emit_event("victory",{})
    status.text = "WASD Move  |  Shift Run  |  LMB / J Attack  |  RMB / K Thrust  |  Space Roll  |  Tab Lock  |  MMB Camera  |  F Execute  |  R Restart"
    if stage == "ready": status.text = "WASD — ascend to the golden tree  |  P — explore the dunes  |  B — review the general's motions"
    if boss.stagger_left > 0 and stage == "fight": status.text = "WARDEN KNEELING — approach and press F to execute"
    if stage == "approach": status.text = "ANCIENT BATTLEFIELD — ascend the dune and approach the Warden beneath the tree"
    if stage == "defeat": status.text = "YOU DIED — R to rise again at the golden sigil"
    if stage == "explore": status.text = "EXPLORE — WASD / Shift / MMB camera  |  B review selected motions  |  P resume combat"
    if crown_preview and stage == "explore": status.text = "CROWN INTRO REVIEW — R replay cinematic  |  P begin combat  |  WASD / MMB explore"
    if stage == "review":
        var title := boss.clip
        for row in selected:
            if row.id == boss.clip: title = row.name
        status.text = "MOTION REVIEW — B next / P resume combat: " + title

func player_attack(index: int) -> void:
    player.heavy_attack = false
    player.combo = index % 3
    player.stamina = maxf(0,player.stamina-16)
    player.queued = false
    var clips := ["ual2/Sword_Regular_A","ual2/Sword_Regular_B","ual2/Sword_Regular_Combo"]
    player.impact_damage = 18 if player.combo < 2 else 13
    player.action(clips[player.combo],"attack",[0.40] if player.combo < 2 else [0.09,0.25,0.41])

func player_heavy_attack() -> void:
    player.heavy_attack = true
    player.combo = 0
    player.queued = false
    player.stamina = maxf(0,player.stamina-28)
    player.impact_damage = 34
    player.action(HEAVY,"attack",[0.40],0.8)

func boss_brain(delta: float) -> void:
    if boss.hp <= 0 or player.hp <= 0 or boss.hitstop_left > 0: return
    director.elapsed += delta
    ai_wait -= delta
    if boss.state == "down":
        if boss.stagger_left <= 0:
            boss.action(STANDUP,"getup",[],0.85)
            pending_roar = true
        return
    if boss.state not in ["idle","move"]: return
    boss.face(player.global_position,delta*0.7)
    if ai_wait > 0: return
    if pending_roar:
        pending_roar = false
        boss.action(ROAR,"roar",[0.38],0.85)
        return
    var distance := boss.global_position.distance_to(player.global_position)
    if distance > 12.0: return
    if director.remaining <= 0: director.begin_sequence(rng)
    var next := director.choose(attack_pool,skills,distance,rng)
    if next == "": return
    last_boss_attack = next
    attack_count += 1
    start_boss_attack(next)

func start_boss_attack(id: String) -> void:
    var profile: Dictionary = skills[id]
    boss.impact_damage = float(profile.damage)
    boss.face(player.global_position)
    boss.action(id,"attack",profile.windows,float(profile.speed))
    if id != COUNTER: director.started(id,boss.duration,profile)
    if profile.has("voice"): audio.cue(str(profile.voice),boss.global_position,0)
    camera_director.impulse(0.018 if profile.damage < 30 else 0.035,0.05)

func swing(actor: BattleActor, _segment: int) -> void:
    audio.cue("boss_swing" if actor == boss else "player_swing_"+str(actor.combo+1),actor.global_position,1 if actor == boss else 0)

func contact(actor: BattleActor, _segment: int, delayed: Dictionary = {}) -> void:
    if stage != "fight" or actor.hp <= 0 or actor.state == "dead": return
    var target := player if actor == boss else boss
    if target.hp <= 0 or target.state in ["dead","execution"]: return
    var delta := target.global_position-actor.global_position
    var horizontal := Vector3(delta.x,0,delta.z)
    if actor == boss:
        if actor.state == "roar" and delayed.is_empty():
            skill_fx.roar(actor.global_position)
            if horizontal.length()>7.2: return
        else:
            var profile: Dictionary = delayed.get("profile",skills.get(actor.clip,{}))
            if profile.is_empty(): return
            var origin: Vector3 = delayed.get("origin",actor.global_position)
            var direction: Vector3 = delayed.get("forward",actor.forward())
            if delayed.is_empty() and float(profile.delay)>0:
                skill_fx.telegraph(origin,direction,profile)
                hazards.append({"profile":profile.duplicate(true),"origin":origin,"forward":direction,"wait":float(profile.delay)})
                return
            if not bool(delayed.get("wave",false)):
                skill_fx.impact(origin,direction,profile)
                if profile.shape=="lane":
                    hazards.append({"profile":profile.duplicate(true),"origin":origin,"forward":direction,"wait":0.0,"wave":true,"age":0.0,"hit":false})
                    return
            if not bool(delayed.get("wave",false)) or float(delayed.get("age",0))<=1.0/30.0:
                camera_director.impulse(0.09 if float(profile.damage)>=30 else 0.045,0.13 if float(profile.damage)>=30 else 0.075)
            var hit_profile := profile.duplicate()
            hit_profile["ground_y"] = DuneHeightV04.sample(target.global_position.x,target.global_position.z)
            if not WardenHitGeometry.contains(hit_profile,origin,direction,target.global_position): return
    else:
        var facing := actor.forward().dot(horizontal.normalized()) if horizontal.length()>0.01 else 1.0
        if horizontal.length()>3.1 or facing< -0.12 or absf(delta.y)>3.0: return
    if target == player and target.state == "roll" and target.time < target.duration * 0.78: return
    if actor == boss and delayed.is_empty() and (actor.state == "roar" or actor.clip == COUNTER):
        # Sekiro's standing Hit_Chest reaction; launch/down is reserved for damaging heavy blows.
        target.queued = false
        target.action("Hit_Chest","pushback",[],0.85)
        target.velocity = horizontal.normalized()*6.5
        audio.cue("player_hurt",target.global_position,-2)
        camera_director.impulse(0.04,0.075)
        freeze_combat(6)
        return
    var damage: float = float(delayed.profile.damage) if not delayed.is_empty() else actor.impact_damage
    target.hp = maxf(0,target.hp-damage)
    freeze_combat(10 if actor == player and player.heavy_attack else (8 if actor == player else 6))
    var point := target.global_position + Vector3.UP*(1.65 if target == boss else 1.0)
    effects.blood(point,actor.forward(),damage)
    audio.cue("blood_hit",point)
    camera_director.impulse(0.09 if actor == boss else 0.035,0.12 if actor == boss else 0.05)
    if target == boss:
        boss.hits_received += 1
        if boss.hp <= 0:
            win()
            return
        if boss.hits_received >= 7:
            boss.hits_received = 0
            boss_followup = ""
            director.cancel_sequence()
            pending_roar = false
            boss.stagger_left = 5.5
            boss.action("Warden_Kneel_Enter","stagger")
            audio.cue("boss_hurt",point,2)
        elif boss.hits_received % 3 == 0 and boss.state in ["idle","move","hit"]:
            director.cancel_sequence()
            start_boss_attack(COUNTER)
            pending_roar = false
        elif boss.state in ["idle","move"]:
            boss.action("combat-master-2671a40251ac813d8b61","hit")
    else:
        player.queued = false
        if player.hp <= 0:
            player.action("Death01","dead")
            player.weapon.visible = false
            stage = "defeat"
            director.cancel_sequence()
            pending_roar = false
            audio.cue("player_death",player.global_position,2)
            audio.cue("boss_victory",boss.global_position,2)
            boss.idle()
            audio.announce("death")
            event_bus.emit_event("player_died",{})
        elif damage >= 30:
            player.action("ual2/Hit_Knockback_RM","launch")
            player.velocity = actor.forward()*7 + Vector3.UP*2
            audio.cue("player_launch",player.global_position)
        else:
            player.action("Hit_Chest","hit")
            player.velocity = actor.forward()*2
            audio.cue("player_hurt",player.global_position)

func action_finished(actor: BattleActor) -> void:
    if actor == player:
        if player.state == "dead": return
        if player.state == "execution":
            camera_director.end_execution()
            if boss.hp <= 0: win()
            else:
                stage = "fight"
                boss.stagger_left = 0
                boss.action(STANDUP,"getup",[],0.85)
                pending_roar = true
        elif player.state == "launch":
            player.state = "down"
            return
        elif player.state == "attack" and player.queued and player.stamina >= 16:
            player_attack((player.combo+1)%3)
            return
        player.idle()
    else:
        if boss.state == "stagger":
            boss.action("Warden_Kneel_Hold","down")
            boss.avatar.looping = true
            return
        if boss_followup != "" and boss.state == "attack":
            var follow := boss_followup
            boss_followup = ""
            start_boss_attack(follow)
            return
        var completed_state := boss.state
        var completed_clip := boss.clip
        boss.idle()
        if stage != "fight":
            director.cancel_sequence()
            return
        if completed_state == "roar" or completed_clip == COUNTER:
            director.begin_sequence(rng,true)
            pending_roar = false
            ai_wait = rng.randf_range(0.18,0.30)
        elif completed_state == "intro":
            ai_wait = 0.28
        elif completed_state == "getup":
            ai_wait = 0.25
        elif completed_state == "hit":
            ai_wait = 0.20
        else:
            ai_wait = director.recovery(skills.get(completed_clip,{}),rng)

func execute() -> void:
    if stage != "fight" or boss.stagger_left <= 0 or player.global_position.distance_to(boss.global_position)>4: return
    stage = "execution"
    director.cancel_sequence()
    pending_roar = false
    execution_struck = false
    player.global_position = boss.global_position + boss.forward()*3.3
    player.global_position.y = DuneHeightV04.sample(player.global_position.x,player.global_position.z)
    player.face(boss.global_position)
    boss.action("Warden_Kneel_Hold","down")
    boss.avatar.looping = true
    player.action(EXECUTION,"execution")
    camera_director.begin_execution()

func win() -> void:
    director.cancel_sequence()
    pending_roar = false
    stage = "victory"
    camera_director.end_execution()
    boss.hp = 0
    boss.state = "down"
    boss_followup = ""
    victory_wait = 0.55
    player.idle()

func review_next() -> void:
    if stage != "review":
        player.global_position = world.ground(boss.global_position.x,boss.global_position.z+7.0)
        player.velocity = Vector3.ZERO
        player.face(boss.global_position)
        boss.face(player.global_position)
    stage = "review"
    var motions: Array = selected.filter(func(row): return row.role == "boss")
    motion_cursor = (motion_cursor+1) % motions.size()
    boss.action(motions[motion_cursor].id,"review",[],1.0)

func print_metrics() -> void:
    print("V04_RUNTIME_METRICS ",JSON.stringify({"fps":Engine.get_frames_per_second(),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"triangles":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),"stage":stage,"player_hp":player.hp,"boss_hp":boss.hp,"audio_events":audio.cue_counts,"web":OS.has_feature("web")}))

func dashboard_tick(delta: float) -> void:
    if OS.has_feature("web"):
        var raw = JavaScriptBridge.eval("JSON.stringify(window.__wardenCommand)")
        if raw != null and str(raw) != "null":
            JavaScriptBridge.eval("window.__wardenCommand=null")
            var request: Dictionary = JSON.parse_string(str(raw))
            var id := str(request.get("id",""))
            if id != "" and boss.avatar.manifest.has(id):
                boss.action(id,"review")
                boss.avatar.looping = true
                boss.trail.clear()
                JavaScriptBridge.eval("window.parent.postMessage("+JSON.stringify({"type":"warden-playing","id":id})+",location.origin)")
            review_paused = bool(request.get("paused",review_paused))
            review_rate = clampf(float(request.get("rate",review_rate)),0.2,1.5)
            if request.has("seek"):
                boss.avatar.elapsed = clampf(float(request.seek),0,1)*float(boss.avatar.manifest[boss.avatar.current].length)
                boss.avatar.tick(0)
                boss.weapon.tick(0)
    if not review_paused:
        boss.avatar.tick(delta*review_rate)
        boss.weapon.tick(delta*review_rate)
    if boss.eyes: boss.eyes.tick(delta)

func tick_hazards(delta: float) -> void:
    if stage != "fight":
        hazards.clear()
        return
    for index in range(hazards.size()-1,-1,-1):
        var hazard: Dictionary = hazards[index]
        if bool(hazard.get("wave",false)):
            var previous: float = hazard.age
            hazard.age += delta
            if not hazard.hit:
                var hit := hazard.duplicate(true)
                hit.profile["min_reach"] = maxf(-0.35,previous/0.32*float(hazard.profile.reach)-0.35)
                hit.profile["reach"] = minf(1,hazard.age/0.32)*float(hazard.profile.reach)
                var hp: float = player.hp
                contact(boss,0,hit)
                hazard.hit = player.hp<hp
            if hazard.age>=0.32: hazards.remove_at(index)
            continue
        hazard.wait -= delta
        if hazard.wait<=0:
            hazards.remove_at(index)
            contact(boss,0,hazard)
