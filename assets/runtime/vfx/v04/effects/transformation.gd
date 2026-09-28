extends Node3D
## Original TransformationVFX noise; Godot shader and surface-particle reconstruction.
@export var auto_play := true
var duration := 6.4
var time := 0.0
var body_template: Node3D
var effect_color := Color(1.0, 0.55, 0.12)
var body: Node3D
var materials: Array[ShaderMaterial] = []
var dust: MultiMeshInstance3D
var seeds: Array[Vector3] = []
var births: Array[float] = []
var drifts: Array[Vector3] = []

func _ready() -> void:
	assert(body_template != null, "NS Basic SKM requires the actual actor model")
	body = body_template.duplicate()
	for ap in body.find_children("*", "AnimationPlayer", true, false): ap.active = false
	add_child(body)
	var vertices: Array[Vector3] = []
	for mesh in body.find_children("*", "MeshInstance3D", true, false):
		var skeleton: Skeleton3D = mesh.get_node_or_null(mesh.skeleton) as Skeleton3D
		var skin: Skin = mesh.skin
		var skin_matrices: Array[Transform3D] = []
		if skeleton and skin:
			skeleton.force_update_all_bone_transforms()
			for index in skin.get_bind_count():
				var bone := skin.get_bind_bone(index)
				if bone < 0: bone = skeleton.find_bone(skin.get_bind_name(index))
				var transform_at := skeleton.get_bone_global_pose(bone) * skin.get_bind_pose(index) if bone >= 0 else Transform3D.IDENTITY
				skin_matrices.append(global_transform.affine_inverse()*skeleton.global_transform*transform_at)
		for surface in mesh.mesh.get_surface_count():
			var mat := ShaderMaterial.new()
			mat.shader = preload("res://assets/runtime/vfx/v04/shaders/dissolve.gdshader")
			mat.set_shader_parameter("source_noise", preload("res://assets/runtime/vfx/v04/textures/T_Perlin_Noise.png"))
			mat.set_shader_parameter("edge_color", Vector3(effect_color.r,effect_color.g,effect_color.b))
			var original: Material = mesh.get_active_material(surface)
			if original is StandardMaterial3D:
				mat.set_shader_parameter("body_tint",Vector3(original.albedo_color.r,original.albedo_color.g,original.albedo_color.b))
				if original.albedo_texture:
					mat.set_shader_parameter("body_texture", original.albedo_texture)
					mat.set_shader_parameter("textured", true)
			mesh.set_surface_override_material(surface,mat)
			materials.append(mat)
			var arrays: Array = mesh.mesh.surface_get_arrays(surface)
			var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_BONES] if arrays[Mesh.ARRAY_BONES] != null else PackedInt32Array()
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS] if arrays[Mesh.ARRAY_WEIGHTS] != null else PackedFloat32Array()
			var stride := indices.size()/maxi(points.size(),1)
			for vertex in range(0,points.size(),maxi(1,points.size()/1800)):
				var point: Vector3 = points[vertex]
				var posed: Vector3 = global_transform.affine_inverse()*mesh.global_transform*point
				if not skin_matrices.is_empty() and stride > 0:
					posed = Vector3.ZERO
					for influence in stride:
						var index := vertex*stride+influence
						posed += (skin_matrices[indices[index]]*point)*weights[index]
				vertices.append(posed)
	assert(not vertices.is_empty())
	var noise: Image = preload("res://assets/runtime/vfx/v04/textures/T_Perlin_Noise.png").get_image()
	if noise.is_compressed(): noise.decompress()
	var rng := RandomNumberGenerator.new()
	rng.seed = 71821
	dust = MultiMeshInstance3D.new()
	dust.multimesh = MultiMesh.new()
	dust.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	dust.multimesh.use_colors = true
	var sphere := SphereMesh.new()
	sphere.radius = 1
	sphere.height = 2
	sphere.radial_segments = 6
	sphere.rings = 3
	dust.multimesh.mesh = sphere
	dust.multimesh.instance_count = 700
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	dust.material_override = material
	add_child(dust)
	for i in 700:
		var point: Vector3 = vertices[rng.randi_range(0, vertices.size() - 1)]
		seeds.append(point)
		var uv := Vector2(fposmod(point.x * 0.8, 1), fposmod(point.y * 0.8, 1))
		var n := noise.get_pixel(mini(int(uv.x * noise.get_width()), noise.get_width()-1), mini(int(uv.y * noise.get_height()), noise.get_height()-1)).r
		var field := clampf(point.y / 2.2, 0, 1) * 0.72 + n * 0.28
		births.append(0.35 + (field + 0.1) / 1.2 * 2.2)
		drifts.append(Vector3(rng.randf_range(-0.6,0.6), rng.randf_range(0.4,1.2), rng.randf_range(-0.6,0.6)))
	sample(0)

func sample(value: float) -> void:
	time = clampf(value, 0, duration)
	var phase := minf(time, duration - time)
	var progress := clampf((phase - 0.35) / 2.2 * 1.2 - 0.1, -0.1, 1.1)
	for material in materials:
		material.set_shader_parameter("progress", progress)
		material.set_shader_parameter("body_color", Vector3(0.48,0.31,0.10) if time > duration/2 else Vector3(0.32,0.39,0.44))
	for i in seeds.size():
		var age := phase - births[i]
		var visible_size := (0.005 + (i % 5) * 0.0017) * maxf(0, 1-age/1.8) if age > 0 and age < 1.8 else 0.0
		var offset := drifts[i] * maxf(age, 0) + Vector3(sin(age*3+i)*age*0.08, 0.1*age*age, cos(age*2+i)*age*0.08)
		dust.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * maxf(visible_size,0.000001)), seeds[i] + offset))
		dust.multimesh.set_instance_color(i, effect_color.lightened(float(i%7)*0.025))

func _process(delta: float) -> void:
	if auto_play: sample(fmod(time + delta, duration))
