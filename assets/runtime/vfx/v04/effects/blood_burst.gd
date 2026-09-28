extends Node3D
## Original BloodPack masks; deterministic Godot reconstruction for scrubbable review.
@export var auto_play := true
@export var intensity := 1.0
var duration := 3.6
var time := 0.0
var drops: MultiMeshInstance3D
var velocities: Array[Vector3] = []
var sizes: Array[float] = []
var cards: Array[MeshInstance3D] = []
var stains: Array[MeshInstance3D] = []
var origin := Vector3(-0.45, 1.15, 0)

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 238491
	drops = MultiMeshInstance3D.new()
	drops.multimesh = MultiMesh.new()
	drops.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 8
	sphere.rings = 4
	drops.multimesh.mesh = sphere
	drops.multimesh.instance_count = 110
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("43060b")
	material.roughness = 0.38
	drops.material_override = material
	add_child(drops)
	for i in 110:
		velocities.append(Vector3(rng.randf_range(0.8, 3.5), rng.randf_range(0.2, 2.9), rng.randf_range(-1.4, 1.4)))
		sizes.append(rng.randf_range(0.004, 0.014))
	for i in 4:
		var card := make_mask("res://assets/runtime/vfx/v04/textures/T_BloodSplatter_01.png", Vector2(1.1, 0.85))
		card.rotation.y = i * PI / 4
		cards.append(card)
	for i in 12:
		var stain := make_mask("res://assets/runtime/vfx/v04/textures/T_BloodSplotch_01.png", Vector2(0.42, 0.42))
		stain.rotation.x = -PI / 2
		stain.rotate_y(rng.randf_range(-PI, PI))
		stain.position = Vector3(rng.randf_range(0.0, 1.5), 0.008 + i * 0.0003, rng.randf_range(-0.7, 0.7))
		stains.append(stain)
	sample(0)

func make_mask(file: String, size: Vector2) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = size
	mesh.mesh = quad
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://assets/runtime/vfx/v04/shaders/blood_mask.gdshader")
	mat.set_shader_parameter("mask_texture", load(file))
	mesh.material_override = mat
	add_child(mesh)
	return mesh

func sample(value: float) -> void:
	time = clampf(value, 0, duration)
	var t := maxf(0, time - 0.12)
	for i in velocities.size():
		var velocity := velocities[i] * intensity
		var pos := origin + velocity * t + Vector3(0, -4.9 * t * t, 0)
		var landed := pos.y < 0.025
		if landed:
			var hit := (velocity.y + sqrt(velocity.y * velocity.y + 19.6 * origin.y)) / 9.8
			pos = origin + velocity * hit + Vector3(0, -4.9 * hit * hit, 0)
			pos.y = 0.012
		var fade := clampf((duration - time) / 0.6, 0, 1) if landed else 1.0
		var scale_value := sizes[i] * fade if time > 0.12 else 0.0
		var stretch := Vector3(1.6, 0.12, 1.6) if landed else Vector3(0.7, 2.6, 0.7)
		var basis := Basis.IDENTITY if landed else Basis(Quaternion(Vector3.UP, (velocity + Vector3(0, -9.8*t, 0)).normalized()))
		drops.multimesh.set_instance_transform(i, Transform3D(basis.scaled_local(stretch * maxf(scale_value, 0.00001)), pos))
	for i in cards.size():
		var age := t - i * 0.025
		cards[i].visible = age > 0 and age < 0.65
		cards[i].position = origin + Vector3(age * 1.4, age * 0.5, 0)
		cards[i].scale = Vector3.ONE * (0.25 + maxf(age, 0) * 1.7) * intensity
		cards[i].material_override.set_shader_parameter("opacity", maxf(0, 1 - age / 0.65) * 0.68)
	for i in stains.size():
		var amount := smoothstep(0.48 + i * 0.035, 0.75 + i * 0.035, time)
		amount *= 1.0 - smoothstep(3.0, 3.6, time)
		stains[i].material_override.set_shader_parameter("opacity", amount * 0.85)

func _process(delta: float) -> void:
	if auto_play: sample(fmod(time + delta, duration))
