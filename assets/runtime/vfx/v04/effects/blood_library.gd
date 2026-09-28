extends Node3D
## Deterministic, family-specific reconstruction. Parameters are authored in Godot, not Niagara defaults.
@export var config_file: String
@export var auto_play := true
var duration := 4.5
var time := 0.0
var config: Dictionary
var drops: MultiMeshInstance3D
var starts: Array[Vector3] = []
var velocities: Array[Vector3] = []
var births: Array[float] = []
var sizes: Array[float] = []
var hits: Array[float] = []
var splashes: Array[MeshInstance3D] = []
var decal_mesh: MultiMeshInstance3D
var decal_transforms: Array[Transform3D] = []
var decal_times: Array[float] = []
var splash_births: Array[float] = []
var splash_starts: Array[Vector3] = []
var rng := RandomNumberGenerator.new()
var ground_height: Callable

func local_floor(p: Vector3) -> float:
	if not ground_height.is_valid(): return 0.0
	var world := to_global(p)
	return to_local(Vector3(world.x, ground_height.call(world.x, world.z), world.z)).y

func _ready() -> void:
	config = JSON.parse_string(FileAccess.get_file_as_string(config_file))
	duration = config.duration
	rng.seed = int(config.seed)
	var family: String = config.family
	var count: int = config.count
	drops = MultiMeshInstance3D.new()
	drops.multimesh = MultiMesh.new()
	drops.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	var sphere := SphereMesh.new()
	sphere.radius = 1
	sphere.height = 2
	sphere.radial_segments = 8
	sphere.rings = 4
	drops.multimesh.mesh = sphere
	drops.multimesh.instance_count = count
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("43060b")
	mat.roughness = 0.38
	drops.material_override = mat
	add_child(drops)
	for i in count:
		var p := Vector3(-0.5,1.2,0)
		var v := Vector3(rng.randf_range(0.6,3.0),rng.randf_range(0.1,2.4),rng.randf_range(-1.2,1.2))
		var birth := rng.randf_range(0.08,0.18)
		match family:
			"artery", "amputated_limbs", "amputated_head":
				birth = 0.12 + float(i % 4) * 0.44 + rng.randf_range(0,0.08)
				v = Vector3(rng.randf_range(2.0,3.8),rng.randf_range(0.7,1.9),rng.randf_range(-0.3,0.3))
				if family == "amputated_head":
					p = Vector3(0,1.6,0)
					v = Vector3(rng.randf_range(-0.8,0.8),rng.randf_range(2.8,4.3),rng.randf_range(-0.8,0.8))
				elif family == "amputated_limbs":
					p = Vector3(-0.3,0.8,0)
					v.y -= 0.9
			"stab", "bullet":
				v = Vector3(rng.randf_range(2.5,5.0),rng.randf_range(-0.2,0.8),rng.randf_range(-0.38,0.38))
				if family == "stab": v *= 0.65
			"slash":
				var angle := rng.randf_range(-1.15,1.15)
				p.x = -0.7 + float(i) / count * 1.2
				birth = 0.08 + float(i) / count * 0.22
				v = Vector3(cos(angle)*2.5,rng.randf_range(0.1,1.0),sin(angle)*2.5)
			"dripping", "dynamic_dripping", "dripping_splash":
				birth = float(i) / count * 2.8 + 0.1
				p = Vector3(0,1.55,0)
				v = Vector3(rng.randf_range(-0.08,0.08),-0.3,rng.randf_range(-0.08,0.08))
				if family == "dynamic_dripping":
					p.x = sin(birth*2.4)*1.05
					p.z = cos(birth*2.4)*0.45
				if family == "dripping_splash":
					p = Vector3(rng.randf_range(-0.2,0.2),0.08,rng.randf_range(-0.2,0.2))
					birth = float(i % 5)*0.55 + rng.randf_range(0,0.07)
					v = Vector3(rng.randf_range(-1.5,1.5),rng.randf_range(0.6,1.4),rng.randf_range(-1.5,1.5))
			"splash":
				p.y = 0.08
				v = Vector3(rng.randf_range(-2.3,2.3),rng.randf_range(1.0,3.3),rng.randf_range(-2.3,2.3))
			"brain", "spherical":
				v = Vector3(rng.randf_range(-1,1),rng.randf_range(-0.4,1),rng.randf_range(-1,1)).normalized()*rng.randf_range(1.1,3.3)
				p = Vector3(0,1.45,0)
		v *= float(config.speed)
		var hit := (v.y + sqrt(v.y*v.y + 19.6*maxf(0.001,p.y-local_floor(p))))/9.8
		for iteration in 3:
			var landing := p+v*hit+Vector3(0,-4.9*hit*hit,0)
			hit = (v.y+sqrt(v.y*v.y+19.6*maxf(0.001,p.y-local_floor(landing))))/9.8
		starts.append(p)
		velocities.append(v)
		births.append(birth)
		hits.append(hit)
		sizes.append(rng.randf_range(0.004,0.014) * float(config.size))
		if family == "splash" and i % maxi(1,count/18) == 0:
			var width := rng.randf_range(0.28,0.55)
			var point := p+v*hit+Vector3(0,-4.9*hit*hit,0)
			point.y = local_floor(point)+0.009+decal_transforms.size()*0.0003
			var normal := Vector3(local_floor(point-Vector3.RIGHT*0.15)-local_floor(point+Vector3.RIGHT*0.15),0.30,local_floor(point-Vector3.BACK*0.15)-local_floor(point+Vector3.BACK*0.15)).normalized()
			var basis := Basis(Quaternion(Vector3.BACK,normal))*Basis(Vector3.BACK,rng.randf_range(-PI,PI))
			decal_transforms.append(Transform3D(basis.scaled(Vector3.ONE*width),point))
			decal_times.append(birth+hit)
	if not decal_transforms.is_empty():
		decal_mesh = MultiMeshInstance3D.new()
		decal_mesh.multimesh = MultiMesh.new()
		decal_mesh.multimesh.transform_format = MultiMesh.TRANSFORM_3D
		decal_mesh.multimesh.use_custom_data = true
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE
		decal_mesh.multimesh.mesh = quad
		decal_mesh.multimesh.instance_count = decal_transforms.size()
		var decal_material := ShaderMaterial.new()
		decal_material.shader = preload("res://assets/runtime/vfx/v04/shaders/blood_mask.gdshader")
		decal_material.set_shader_parameter("mask_texture",load("res://"+str(config.decal)))
		decal_material.set_shader_parameter("instance_fade",true)
		decal_mesh.material_override = decal_material
		decal_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(decal_mesh)
		for i in decal_transforms.size(): decal_mesh.multimesh.set_instance_transform(i,decal_transforms[i])
	# Large source masks distinguish sheets of liquid from individual droplets.
	var sheet_count := 5 if family in ["artery","amputated_limbs","amputated_head"] else 3
	if "dripping" in family or family == "spherical": sheet_count = 0
	for i in sheet_count:
		var card := make_mask(config.mask,Vector2(1.25,0.9))
		card.rotation.y = i*0.8
		if family == "slash": card.rotation.z = -0.6
		splashes.append(card)
		splash_births.append(0.1 + i * (0.42 if sheet_count == 5 else 0.025))
		splash_starts.append(starts[mini(i,starts.size()-1)])
	sample(0)

func make_mask(file: String, size: Vector2) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = size
	item.mesh = quad
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://assets/runtime/vfx/v04/shaders/blood_mask.gdshader")
	mat.set_shader_parameter("mask_texture",load("res://"+file))
	item.material_override = mat
	item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(item)
	return item

func sample(value: float) -> void:
	time = clampf(value,0,duration)
	var fade := 1.0-smoothstep(duration-0.7,duration,time)
	for i in starts.size():
		var age := time-births[i]
		var t := clampf(age,0,hits[i])
		var p := starts[i]+velocities[i]*t+Vector3(0,-4.9*t*t,0)
		var landed := age >= hits[i]
		var floor_y := local_floor(p) + 0.012
		landed = landed or p.y <= floor_y
		p.y = maxf(floor_y,p.y)
		var vel := velocities[i]+Vector3(0,-9.8*t,0)
		var basis := Basis.IDENTITY if landed else Basis(Quaternion(Vector3.UP,vel.normalized()))
		var stretch := Vector3(1.8,0.1,1.8) if landed else Vector3(0.7,2.6,0.7)
		var size := sizes[i]*fade if age>0 else 0.000001
		if config.family == "burst" and landed: size = 0.000001
		if config.family == "spherical" and not landed: size = 0.000001
		drops.multimesh.set_instance_transform(i,Transform3D(basis.scaled_local(stretch*maxf(size,0.000001)),p))
	for i in splashes.size():
		var age := time-splash_births[i]
		splashes[i].visible = age>0 and age<0.65
		splashes[i].position = splash_starts[i]+Vector3(age*1.3,age*0.3,0)
		splashes[i].scale = Vector3.ONE*(0.25+maxf(age,0)*1.8)*float(config.size)
		splashes[i].material_override.set_shader_parameter("opacity",maxf(0,1-age/0.65)*0.7)
	for i in decal_times.size():
		var amount := smoothstep(decal_times[i],decal_times[i]+0.12,time)*fade
		decal_mesh.multimesh.set_instance_custom_data(i,Color(amount*0.85,0,0,0))

func _process(delta: float) -> void:
	if auto_play: sample(fmod(time+delta,duration))
