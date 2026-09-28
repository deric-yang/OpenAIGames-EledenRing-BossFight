class_name WardenSkillEffects
extends Node3D
## Sekiro rock-fault composition with layered sand, velocity jets and pooled mesh batches.
## Sources and visual iterations: docs/iteration-v08/PLAYABLE.zh-CN.md.
const H = preload("res://scripts/world/dune_height_v04.gd")
var groups: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()
var rock_mesh: ArrayMesh
var rock_material: StandardMaterial3D
var spark_material: StandardMaterial3D
var dust_material: ShaderMaterial

func _ready() -> void:
    rng.randomize()
    rock_mesh = make_rock()
    rock_material = StandardMaterial3D.new()
    rock_material.albedo_texture = load("res://assets/runtime/vfx/v08/rock_diffuse.jpg")
    rock_material.albedo_color = Color(0.28,0.23,0.17)
    rock_material.normal_enabled = true
    rock_material.normal_texture = load("res://assets/runtime/vfx/v08/rock_normal.jpg")
    rock_material.normal_scale = 0.8
    rock_material.roughness_texture = load("res://assets/runtime/vfx/v08/rock_rough.jpg")
    rock_material.uv1_triplanar = true
    rock_material.uv1_scale = Vector3.ONE*1.6
    spark_material = StandardMaterial3D.new()
    spark_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    spark_material.albedo_color = Color(1,0.32,0.045)
    spark_material.emission_enabled = true
    spark_material.emission = Color(1,0.15,0.015)
    spark_material.emission_energy_multiplier = 2
    dust_material = ShaderMaterial.new()
    dust_material.shader = preload("res://shaders/world/skill_dust.gdshader")
    dust_material.set_shader_parameter("cloud",load("res://assets/runtime/vfx/v08/dust.png"))

func ground(point: Vector3, lift := 0.03) -> Vector3:
    return Vector3(point.x,H.sample(point.x,point.z)+lift,point.z)

func make_rock() -> ArrayMesh:
    # The authored asymmetric six-sided stone from Sekiro's greatsword fissure.
    var tool := SurfaceTool.new()
    tool.begin(Mesh.PRIMITIVE_TRIANGLES)
    tool.set_smooth_group(-1)
    var lower: Array[Vector3] = []
    var upper: Array[Vector3] = []
    for i in 6:
        var a := i*TAU/6
        lower.append(Vector3(sin(a)*(0.72+0.12*sin(i*7.1)),0,cos(a)*0.66))
        upper.append(Vector3(sin(a+0.17)*(0.50+0.19*sin(i*2.3))+0.16,
            0.65+0.30*sin(i*1.7),cos(a+0.17)*0.40-0.11))
    var top := Vector3(0.24,0.92,-0.18)
    for i in 6:
        var j := (i+1)%6
        for point in [lower[i],upper[i],lower[j],lower[j],upper[i],upper[j],upper[i],top,upper[j]]:
            tool.add_vertex(point)
    tool.generate_normals()
    return tool.commit()

func batch(parent: Node3D, mesh: Mesh, material: Material, count: int) -> MultiMesh:
    var node := MultiMeshInstance3D.new()
    var mm := MultiMesh.new()
    mm.transform_format = MultiMesh.TRANSFORM_3D
    mm.use_colors = true
    mm.use_custom_data = true
    mm.mesh = mesh
    mm.instance_count = count
    node.multimesh = mm
    node.material_override = material
    node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    parent.add_child(node)
    for i in count: mm.set_instance_transform(i,Transform3D(Basis.from_scale(Vector3.ONE*0.0001),Vector3.ZERO))
    return mm

func telegraph(origin: Vector3, forward: Vector3, profile: Dictionary) -> void:
    # Moving pressure wisps communicate the lane without painting black lines on sand.
    for i in 4:
        footfall(origin+forward*float(profile.reach)*float(i+1)/4.0,forward,1.0)

func footfall(point: Vector3, direction: Vector3, strength: float) -> void:
    var container := Node3D.new()
    add_child(container)
    var quad := QuadMesh.new()
    quad.size = Vector2(2,2)
    var mm := batch(container,quad,dust_material,5)
    var particles: Array = []
    for i in 5:
        var spread := direction.rotated(Vector3.UP,rng.randf_range(-1.5,1.5))
        particles.append({"batch":mm,"index":i,"start":ground(point,0.10),
            "velocity":spread*strength*0.7+Vector3.UP*0.35,"delay":0.0,"life":0.65,
            "scale":Vector3.ONE*rng.randf_range(0.18,0.30)*strength,
            "spin":Vector3.ZERO,"kind":"dust","seed":rng.randf()})
    groups.append({"root":container,"age":0.0,"life":0.7,"kind":"foot","particles":particles})
    trim()

func roar(origin: Vector3) -> void:
    var container := Node3D.new()
    add_child(container)
    var quad := QuadMesh.new()
    quad.size = Vector2(2,2)
    var material: ShaderMaterial = dust_material.duplicate()
    material.set_shader_parameter("tint",Color(0.75,0.025,0.008,0.27))
    var mm := batch(container,quad,material,9)
    var particles: Array = []
    for i in 9:
        var direction := Vector3(cos(i*TAU/9),0,sin(i*TAU/9))
        particles.append({"batch":mm,"index":i,"start":origin+Vector3.UP*3.3+direction*0.7,"velocity":direction*4,
            "delay":0.0,"life":0.65,"scale":Vector3.ONE*1.7,"spin":Vector3.ZERO,"kind":"dust","seed":rng.randf()})
    groups.append({"root":container,"age":0.0,"life":0.8,"kind":"roar","particles":particles})
    trim()

func impact(origin: Vector3, forward: Vector3, profile: Dictionary) -> void:
    if profile.effect=="push":
        roar(origin)
        return
    var container := Node3D.new()
    add_child(container)
    var lane: bool = profile.shape=="lane"
    var heavy: bool = profile.effect in ["eruption","fissure"]
    if get_parent().get("camera_director") != null:
        get_parent().camera_director.impact_blur(ground(origin+forward*float(profile.get("offset",3))),0.016 if heavy else 0.007)
    var direction := Vector3(forward.x,0,forward.z).normalized()
    var side := direction.cross(Vector3.UP)
    var quad := QuadMesh.new()
    quad.size = Vector2(2,2)
    var rocks := batch(container,rock_mesh,rock_material,54 if heavy else 28)
    var dust := batch(container,quad,dust_material,64 if heavy else 32)
    var spark_mesh := BoxMesh.new()
    spark_mesh.size = Vector3(0.018,0.10,0.018)
    var sparks := batch(container,spark_mesh,spark_material,42 if heavy else 12)
    var jet_material: ShaderMaterial = dust_material.duplicate()
    jet_material.set_shader_parameter("jet",true)
    var jets := batch(container,quad,jet_material,36 if heavy else 18)
    var grit := batch(container,rock_mesh,rock_material,140 if heavy else 60)
    var particles: Array = []
    for kind in ["rock","dust","spark","jet","grit"]:
        var mm: MultiMesh = rocks if kind=="rock" else (dust if kind=="dust" else (jets if kind=="jet" else (grit if kind=="grit" else sparks)))
        for i in mm.instance_count:
            var fraction := (i+rng.randf())/mm.instance_count
            var angle := rng.randf()*TAU
            var outward := Vector3(cos(angle),0,sin(angle))
            var point := origin+direction*float(profile.get("offset",3))
            var delay := 0.0
            if lane:
                point = origin+direction*(fraction*float(profile.reach))+side*rng.randf_range(-1,1)*float(profile.width)*(0.3+0.7*fraction)
                outward = (side*(1 if i%2==0 else -1)+direction*0.2).normalized()
                delay = fraction*0.32
            elif profile.shape=="sector":
                var sweep := deg_to_rad(float(profile.angle))
                outward = direction.rotated(Vector3.UP,-sweep*0.5+fraction*sweep)
                point = origin+outward*rng.randf_range(1,float(profile.reach)*0.8)
                delay = fraction*0.13
            else:
                point += outward*sqrt(fraction)*float(profile.reach)*0.6
                delay = fraction*0.12
            point = ground(point,0.10)
            var size := rng.randf_range(0.07,0.24)*(1.3 if heavy else 0.7)
            var velocity := outward*rng.randf_range(2.0,6.0)+Vector3.UP*rng.randf_range(3,8)
            if kind=="dust": velocity = outward*rng.randf_range(2,5)+Vector3.UP*rng.randf_range(1.5,3.5)
            if kind=="spark": velocity = outward*rng.randf_range(4,10)+Vector3.UP*rng.randf_range(3,9)
            var scale := Vector3(size, size*rng.randf_range(0.5,1.7),size)
            if kind=="dust": scale = Vector3.ONE*rng.randf_range(0.7,1.3)
            elif kind=="spark": scale = Vector3.ONE*rng.randf_range(0.6,1.3)
            if kind=="jet":
                velocity=outward*rng.randf_range(7,15)+Vector3.UP*rng.randf_range(12 if heavy else 4,20 if heavy else 9)
                scale=Vector3(rng.randf_range(0.22,0.42),rng.randf_range(2.5 if heavy else 1.6,4.2 if heavy else 3.2),1)
            if kind=="grit":
                velocity=outward*rng.randf_range(3,12)+Vector3.UP*rng.randf_range(2,9)
                scale=Vector3.ONE*rng.randf_range(0.025,0.07)
            var particle_kind: String = kind
            if kind=="rock" and heavy and i%4==0 and lane:
                particle_kind="slab"
                scale=Vector3(rng.randf_range(0.6,1.0),rng.randf_range(0.7,1.5),rng.randf_range(0.4,0.8))
                velocity=Vector3.ZERO
            particles.append({"batch":mm,"index":i,"start":point,"velocity":velocity,"delay":delay,
                "life":rng.randf_range(0.24,0.42) if kind=="jet" else (rng.randf_range(1.1,1.8) if kind!="spark" else rng.randf_range(0.2,0.55)),
                "scale":scale,"spin":Vector3(rng.randf_range(-0.4,0.4),rng.randf()*TAU,rng.randf_range(-0.4,0.4))*(1.0 if particle_kind=="slab" else 5.0),"kind":particle_kind,"seed":rng.randf()})
            mm.set_instance_color(i,Color(0.72+fraction*0.28,0.72+fraction*0.28,0.72+fraction*0.28))
    groups.append({"root":container,"age":0.0,"life":2.6,"kind":"impact","particles":particles})
    trim()

func trim() -> void:
    while groups.size()>24:
        var old: Dictionary = groups.pop_front()
        old.root.queue_free()

func clear() -> void:
    for group in groups: group.root.queue_free()
    groups.clear()

func _process(delta: float) -> void:
    if get_parent().get("shared_hitstop") != null and float(get_parent().get("shared_hitstop"))>0: return
    for index in range(groups.size()-1,-1,-1):
        var group := groups[index]
        group.age += delta
        for p in group.particles:
            var age: float = group.age-p.delay
            var mm: MultiMesh = p.batch
            if age<0 or age>p.life:
                mm.set_instance_transform(p.index,Transform3D(Basis.from_scale(Vector3.ONE*0.0001),p.start))
                continue
            var normalized_age: float = age/p.life
            var dust: bool = p.kind in ["dust","jet"]
            var point: Vector3 = p.start+p.velocity*age
            if not dust and p.kind!="slab": point.y -= 9.8*age*age
            point.y = maxf(point.y,H.sample(point.x,point.z)+0.07)
            var fade := smoothstep(1.0,0.62,normalized_age)
            var size: Vector3 = p.scale*(1+age*1.6 if dust else fade)
            if p.kind=="slab":
                size = p.scale*smoothstep(0.0,0.13,age)*fade
                point.y -= (1.0-fade)*p.scale.y
            var basis := Basis.from_euler(p.spin*age if not dust else Vector3.ZERO).scaled(size)
            if p.kind=="slab": basis=Basis.from_euler(p.spin).scaled(size)
            if p.kind=="jet":
                var axis: Vector3 = p.velocity.normalized()
                var across := axis.cross(Vector3.FORWARD).normalized()
                if across.length_squared()<0.1: across=Vector3.RIGHT
                basis=Basis(across,axis,across.cross(axis)).scaled(size)
                point=p.start+p.velocity*(0.14*(1.0-exp(-age/0.14)))
            mm.set_instance_transform(p.index,Transform3D(basis,point))
            mm.set_instance_custom_data(p.index,Color(fade*smoothstep(0.0,0.08,age),p.seed,age,0))
        if group.age>=group.life:
            group.root.queue_free()
            groups.remove_at(index)
