class_name BattleActor
extends CharacterBody3D
var game: Node3D
var role := "knight"
var avatar: DuelAvatar
const BOSS_STRIDE_CYCLE_METERS := 12.4
var foot_phase := -1
var last_dust_position := Vector3.ZERO
var weapon: HeldWeapon
var hp := 100.0
var max_hp := 100.0
var stamina := 100.0
var max_stamina := 100.0
var state := "idle"
var time := 0.0
var duration := 0.0
var clip := ""
var impacts: Array = []
var fired := {}
var step_clock := 0.0
var hits_received := 0
var queued := false
var combo := 0
var attack_id := 0
var stagger_left := 0.0
var impact_damage := 18.0
var move_direction := Vector3.ZERO
var hitstop_left := 0.0
var heavy_attack := false
var trail: WeaponTrail
var eyes: Node3D

func setup(owner_game: Node3D, actor_role: String) -> void:
    game = owner_game
    role = actor_role
    max_hp = 680.0 if role == "general" else 100.0
    hp = max_hp
    avatar = DuelAvatar.new()
    add_child(avatar)
    avatar.setup(role)
    avatar.scale = Vector3.ONE * (4.324325 if role == "general" else 1.0)
    weapon = HeldWeapon.new()
    add_child(weapon)
    weapon.setup(avatar, role)
    trail = WeaponTrail.new()
    game.add_child(trail)
    trail.setup(self)
    if role == "general":
        eyes = WardenEyes.new()
        avatar.model.add_child(eyes)
        eyes.setup(avatar)
    var shape := CollisionShape3D.new()
    var capsule := CapsuleShape3D.new()
    capsule.radius = 1.4375 if role == "general" else 0.32
    capsule.height = 7.375 if role == "general" else 1.8
    shape.shape = capsule
    shape.position.y = capsule.height / 2
    add_child(shape)
    collision_layer = 2 if role == "general" else 4
    collision_mask = 1 | (4 if role == "general" else 2)
    floor_snap_length = 0.5
    floor_max_angle = deg_to_rad(48)
    idle()

func face(point: Vector3, delta: float = 1.0) -> void:
    var direction := point - global_position
    direction.y = 0
    if direction.length_squared() > 0.001:
        rotation.y = lerp_angle(rotation.y, atan2(direction.x,direction.z), minf(1,delta * 8))

func forward() -> Vector3:
    return global_basis.z.normalized()

func idle() -> void:
    state = "idle"
    time = 0
    avatar.play_clip("Sword_Idle",true)

func action(id: String, action_state: String, windows: Array = [], playback: float = 1.0) -> void:
    state = action_state
    clip = id
    time = 0
    impacts = windows
    fired.clear()
    attack_id += 1
    avatar.play_clip(id,false,playback)
    duration = float(avatar.manifest[id].length) / playback
    if state == "attack": game.swing(self,0)
    if state == "roll": game.audio.cue("player_roll",global_position)
    if state == "roar": game.audio.cue("boss_roar",global_position,3)

func motion(delta: float, input_direction: Vector3, sprint: bool) -> void:
    if hitstop_left > 0: return
    time += delta
    stagger_left = maxf(0,stagger_left-delta)
    stamina = minf(max_stamina,stamina + delta * (24.0 if state in ["idle","move"] else 5.0))
    if state in ["idle","move"]:
        var speed := (5.8 if sprint else 3.9) if role == "knight" else (8.4 if sprint else 4.6)
        if sprint and role == "knight": stamina = maxf(0,stamina-delta*34)
        if input_direction.length_squared() > 0.01:
            if role == "knight": face(global_position + input_direction,delta)
            velocity.x = input_direction.x * speed
            velocity.z = input_direction.z * speed
            var wanted := "Sprint_Loop" if sprint else "Jog_Fwd_Loop"
            var pace := speed / (5.8 if sprint else 4.3)
            if role == "general":
                var local_move := global_basis.inverse() * input_direction
                wanted = "combat-master-577f7516d930b2ed0ead"
                pace = velocity.length() / 10.5
                if local_move.z < -0.25:
                    wanted = "combat-master-1f059a763b2ce804220f"
                    pace = velocity.length() / 4.4
                elif absf(local_move.x) > absf(local_move.z):
                    wanted = "combat-master-6d0ba7c3ad4d32ebe094"
                    pace = velocity.length() / 4.4
            if state != "move" or clip != wanted:
                state = "move"
                clip = wanted
                avatar.play_clip(clip,true,pace)
            avatar.speed = lerpf(avatar.speed,clampf(pace,0.22,1.35),1-exp(-delta*10))
            if role == "general" and wanted == "combat-master-577f7516d930b2ed0ead":
                # Two planted-foot advances per cycle; displacement follows the stride phase.
                var cycle: float = float(avatar.manifest[wanted].length)
                var phase := fmod(avatar.elapsed/cycle,1.0)
                var next := phase+delta*avatar.speed/cycle
                var travel := BOSS_STRIDE_CYCLE_METERS*((next-phase)-0.30*(sin(next*TAU*2)-sin(phase*TAU*2))/(TAU*2))
                velocity.x = input_direction.x*travel/delta
                velocity.z = input_direction.z*travel/delta
            step_clock -= delta
            if step_clock <= 0:
                game.audio.cue(("boss_run" if sprint else "boss_step") if role == "general" else "player_step",global_position,-5)
                step_clock = (0.44 if sprint else 0.68) if role == "general" else (0.29 if sprint else 0.4)
        else:
            velocity.x = move_toward(velocity.x,0,delta*25)
            velocity.z = move_toward(velocity.z,0,delta*25)
            if state != "idle": idle()
    elif state == "roll":
        velocity.x = move_direction.x * 8.0 * sin(PI*clampf(time/duration,0,1))
        velocity.z = move_direction.z * 8.0 * sin(PI*clampf(time/duration,0,1))
    elif state in ["attack","roar"]:
        velocity.x = move_toward(velocity.x,0,delta*22)
        velocity.z = move_toward(velocity.z,0,delta*22)
        for index in impacts.size():
            if time >= float(impacts[index])*duration and not fired.has(index):
                fired[index] = true
                if index > 0 and state == "attack": game.swing(self,index)
                game.queue_contact(self,index)
    elif state == "pushback":
        velocity.x = move_toward(velocity.x,0,delta*13)
        velocity.z = move_toward(velocity.z,0,delta*13)
    else:
        velocity.x = move_toward(velocity.x,0,delta*10)
        velocity.z = move_toward(velocity.z,0,delta*10)
    velocity.y -= delta * 24
    move_and_slide()
    global_position.x = clampf(global_position.x,-110,110)
    global_position.z = clampf(global_position.z,-120,85)
    if state not in ["idle","move","dead","down"] and time >= duration:
        game.action_finished(self)
    avatar.tick(delta)
    weapon.tick(delta)
    if state == "move" and is_on_floor():
        var left := avatar.bone_transform("foot.L").origin
        var right := avatar.bone_transform("foot.R").origin
        var side := 0 if left.y < right.y else 1
        var foot := left if side==0 else right
        var ground_height := DuneHeightV04.sample(foot.x,foot.z)
        if side!=foot_phase and foot.y-ground_height<(0.45 if role=="general" else 0.16):
            if global_position.distance_to(last_dust_position)>0.25:
                foot_phase=side
                last_dust_position=global_position
                game.skill_fx.footfall(foot,-forward(),1.7 if role=="general" else 0.65)
    else:
        foot_phase = -1
    if eyes: eyes.tick(delta)

func reset_at(point: Vector3) -> void:
    global_position = point
    hp = max_hp
    stamina = max_stamina
    velocity = Vector3.ZERO
    foot_phase = -1
    last_dust_position = point
    queued = false
    heavy_attack = false
    hitstop_left = 0
    if trail: trail.clear()
    combo = 0
    hits_received = 0
    stagger_left = 0
    avatar.model.visible = true
    weapon.visible = true
    idle()
