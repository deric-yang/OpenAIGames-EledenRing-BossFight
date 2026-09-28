class_name WeaponTrail
extends MeshInstance3D
## A short world-space ribbon sampled from the real blade, never a canned slash sprite.
var actor: BattleActor
var samples: Array[Dictionary] = []
var ribbon := ImmediateMesh.new()
var previous_blade := Transform3D.IDENTITY
var previous_active := false
var sampled_attack := -1
const LIFETIME := 0.22
func setup(owner_actor: BattleActor) -> void:
    actor = owner_actor
    mesh = ribbon
    cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    var material := ShaderMaterial.new()
    material.shader = load("res://shaders/vfx/weapon_trail.gdshader")
    material_override = material
func clear() -> void:
    samples.clear()
    previous_active = false
    ribbon.clear_surfaces()
func _process(delta: float) -> void:
    if not is_instance_valid(actor): queue_free(); return
    if actor.hitstop_left > 0: return
    for sample in samples: sample.age += delta
    samples = samples.filter(func(sample): return sample.age < LIFETIME)
    var active := actor.state in ["attack","execution"] and actor.weapon.visible and actor.hp > 0
    var phase := actor.time / maxf(actor.duration,0.001)
    var window := actor.state == "execution" and phase > 0.25 and phase < 0.52
    for hit in actor.impacts:
        if phase >= float(hit)-0.19 and phase <= float(hit)+0.09: window = true
    if actor.attack_id!=sampled_attack:
        clear()
        sampled_attack=actor.attack_id
    if active and window:
        var blade := actor.weapon.blade.global_transform
        var subdivisions := 1
        if previous_active:
            var distance := previous_blade.origin.distance_to(blade.origin)
            if distance>8.0: clear()
            else: subdivisions=4
        for i in subdivisions:
            var weight := float(i+1)/subdivisions
            var pose := previous_blade.interpolate_with(blade,weight) if previous_active else blade
            var inner := pose*Vector3(0,0.43 if actor.role=="knight" else 1.65,0.12 if actor.role=="knight" else 0)
            var tip := pose*Vector3(0,1.55 if actor.role=="knight" else 2.43,-0.22 if actor.role=="knight" else 0)
            if samples.is_empty() or samples.back().tip.distance_to(tip)>0.012:
                samples.append({"inner":inner,"tip":tip,"age":(1.0-weight)*delta})
        previous_blade=blade
        previous_active=true
    else:
        previous_active=false
    while samples.size()>96: samples.pop_front()
    ribbon.clear_surfaces()
    if samples.size()<2: return
    var smooth_samples: Array = samples.duplicate()
    for iteration in 2:
        var refined: Array = [smooth_samples[0]]
        for i in range(1,smooth_samples.size()):
            for weight in [0.25,0.75]:
                var a: Dictionary = smooth_samples[i-1]
                var b: Dictionary = smooth_samples[i]
                refined.append({"inner":a.inner.lerp(b.inner,weight),"tip":a.tip.lerp(b.tip,weight),
                    "age":lerpf(a.age,b.age,weight)})
        refined.append(smooth_samples.back())
        smooth_samples = refined
    ribbon.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
    for i in range(1,smooth_samples.size()):
        var a: Dictionary = smooth_samples[i-1]
        var b: Dictionary = smooth_samples[i]
        vertex(a,"inner",0); vertex(a,"tip",1); vertex(b,"tip",1)
        vertex(a,"inner",0); vertex(b,"tip",1); vertex(b,"inner",0)
    ribbon.surface_end()
func vertex(sample: Dictionary, key: String, edge: float) -> void:
    ribbon.surface_set_color(Color(1,1,1,pow(1.0-float(sample.age)/LIFETIME,1.5)*0.72))
    ribbon.surface_set_uv(Vector2(edge,1.0-float(sample.age)/LIFETIME))
    ribbon.surface_add_vertex(sample[key])
