class_name BattlefieldV04
extends Node3D
const H = preload("res://scripts/world/dune_height_v04.gd")
const ASSETS = "res://assets/runtime/assembly/"
var placements: Array[Dictionary] = []
var fragment_placements: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()
var respawn_position := Vector3(0.4, 0, 28)
var boss_position := Vector3.ZERO

func _ready() -> void:
    rng.seed = 927264
    environment()
    var terrain := add_asset("res://assets/runtime/world/v09/terrain.glb", Vector3.ZERO)
    var sand := ShaderMaterial.new()
    sand.shader = preload("res://shaders/world/assembly_sand.gdshader")
    for mesh in terrain.find_children("*", "MeshInstance3D", true, false):
        mesh.material_override = sand
        mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        mesh.create_trimesh_collision()
    var tree := add_asset(ASSETS + "tree.glb", ground(8, -107) - Vector3.UP * 18)
    golden_tree(tree)
    boss_position = ground(8,-53)+Vector3.UP*0.05
    scatter()
    scattered_fragments()
    standards()
    atmosphere()
    respawn_position = ground(7, -26) + Vector3.UP * 0.05
    var sigil = preload("res://scripts/world/golden_respawn.gd").new()
    sigil.position = respawn_position
    add_child(sigil)
    ruins()
    fallen_mounds()
    var relics := LuminousRelics.new()
    add_child(relics)

func ground(x: float, z: float) -> Vector3:
    return Vector3(x, H.sample(x, z), z)

func add_asset(file: String, position_at: Vector3, yaw: float = 0, size: float = 1.0) -> Node3D:
    var node: Node3D = load(file).instantiate()
    node.position = position_at
    node.rotation.y = yaw
    node.scale = Vector3.ONE * size
    add_child(node)
    for mesh in node.find_children("*","MeshInstance3D",true,false):
        mesh.lod_bias = 0.35
        if file.contains("tree.glb"): mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        if file.contains("rubble.glb") or file.contains("broken_bow.glb") or file.contains("fallen_soldier.glb"):
            mesh.visibility_range_end = 85
            mesh.visibility_range_end_margin = 8
            mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    placements.append({"asset":file, "position":[position_at.x,position_at.y,position_at.z], "yaw":yaw,"scale":size})
    return node

func environment() -> void:
    var world := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_SKY
    var sky := Sky.new()
    var sky_material := ShaderMaterial.new()
    sky_material.shader = preload("res://shaders/world/assembly_sky.gdshader")
    sky.sky_material = sky_material
    env.sky = sky
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color("b5bac4")
    env.ambient_light_energy = 0.40
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    env.fog_enabled = true
    env.fog_light_color = Color("8c7f6e")
    env.fog_light_energy = 0.55
    env.fog_density = 0.0038
    env.fog_height = 1.5
    env.fog_height_density = 0.012
    env.fog_sky_affect = 0.32
    world.environment = env
    add_child(world)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-28, -32, 0)
    sun.light_color = Color("e6dfd0")
    sun.light_energy = 0.88
    sun.shadow_enabled = true
    sun.directional_shadow_max_distance = 50
    sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
    add_child(sun)

func scatter() -> void:
    for i in 34:
        var x := rng.randf_range(-105, 105)
        var z := rng.randf_range(-120, 80)
        if Vector2(x, z - 28).length() < 5: continue
        var file: String = ASSETS + ["rubble.glb", "graves.glb", "polearms.glb"][i % 3]
        var size := rng.randf_range(0.35, 1.4)
        var node := add_asset(file, ground(x, z) - Vector3.UP * rng.randf_range(0.1, 0.35), rng.randf_range(-PI, PI), size)
        node.rotation.x = rng.randf_range(-0.1, 0.1)
        node.rotation.z = rng.randf_range(-0.12, 0.12)
    var shaft := CylinderMesh.new()
    shaft.top_radius = 0.015
    shaft.bottom_radius = 0.022
    shaft.height = 1.0
    shaft.radial_segments = 5
    var shaft_mat := StandardMaterial3D.new()
    shaft_mat.albedo_color = Color("322923")
    shaft_mat.roughness = 0.97
    shaft.material = shaft_mat
    var shards := BoxMesh.new()
    shards.size = Vector3(0.10, 0.016, 0.24)
    var iron := StandardMaterial3D.new()
    iron.albedo_color = Color("49413a")
    iron.metallic = 0.5
    iron.roughness = 0.88
    shards.material = iron
    for group in 2:
        var multi := MultiMeshInstance3D.new()
        multi.multimesh = MultiMesh.new()
        multi.multimesh.transform_format = MultiMesh.TRANSFORM_3D
        multi.multimesh.mesh = shaft if group == 0 else shards
        multi.multimesh.instance_count = 680 if group == 0 else 800
        multi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        add_child(multi)
        for i in multi.multimesh.instance_count:
            var x := rng.randf_range(-45,45) if i % 3 != 0 else rng.randf_range(-115,115)
            var z := rng.randf_range(-55,45) if i % 3 != 0 else rng.randf_range(-135,85)
            var length := rng.randf_range(0.35, 1.8)
            var upright := group == 0 and rng.randf() < 0.25
            var basis := Basis.from_euler(Vector3(rng.randf_range(-0.5, 0.5) if upright else PI * 0.48, rng.randf_range(-PI, PI), rng.randf_range(-0.4, 0.4)))
            if group == 1: basis = Basis.from_euler(Vector3(rng.randf_range(-0.15,0.15),rng.randf_range(-PI,PI),rng.randf_range(-0.1,0.1)))
            basis = basis.scaled(Vector3.ONE * length)
            var pos := ground(x, z) + Vector3.UP * (length * 0.28 if upright else 0.015)
            multi.multimesh.set_instance_transform(i, Transform3D(basis, pos))
    for item in [["broken_bow.glb", 22], ["fallen_soldier.glb", 16]]:
        var file: String = "res://assets/runtime/world/v04/" + item[0]
        if not ResourceLoader.exists(file): continue
        for i in int(item[1]):
            var x := rng.randf_range(-90, 90)
            var z := rng.randf_range(-100, 65)
            add_asset(file, ground(x, z) - Vector3.UP * 0.04, rng.randf_range(-PI, PI), rng.randf_range(0.65, 1.3))

func scattered_fragments() -> void:
    var metal := StandardMaterial3D.new()
    metal.albedo_color = Color("443e37")
    metal.metallic = 0.65
    metal.roughness = 0.82
    var shield := CylinderMesh.new()
    shield.top_radius = 0.28
    shield.bottom_radius = 0.31
    shield.height = 0.06
    shield.radial_segments = 9
    var helmet := SphereMesh.new()
    helmet.radius = 0.19
    helmet.height = 0.30
    helmet.radial_segments = 8
    helmet.rings = 4
    var blade := PrismMesh.new()
    blade.size = Vector3(0.10,0.025,0.70)
    var plate := BoxMesh.new()
    plate.size = Vector3(0.21,0.018,0.31)
    var meshes: Array[Mesh] = [shield,helmet,blade,plate]
    for kind in meshes.size():
        meshes[kind].material = metal
        var node := MultiMeshInstance3D.new()
        var multi := MultiMesh.new()
        multi.transform_format = MultiMesh.TRANSFORM_3D
        multi.mesh = meshes[kind]
        multi.instance_count = 95 if kind < 2 else 170
        node.multimesh = multi
        add_child(node)
        for i in multi.instance_count:
            var x := rng.randf_range(-48,48) if i % 3 != 0 else rng.randf_range(-108,108)
            var z := rng.randf_range(-65,40) if i % 3 != 0 else rng.randf_range(-120,80)
            var size := rng.randf_range(0.55,1.7)
            var angles := Vector3(rng.randf_range(-0.35,0.35),rng.randf_range(-PI,PI),rng.randf_range(-0.25,0.25))
            var pos := ground(x,z)+Vector3.UP*(0.04 if kind == 1 else 0.025)
            var basis := Basis.from_euler(angles).scaled(Vector3.ONE*size)
            multi.set_instance_transform(i,Transform3D(basis,pos))
            fragment_placements.append({"kind":kind,"position":[pos.x,pos.y,pos.z],"angles":[angles.x,angles.y,angles.z],"scale":size})

func standards() -> void:
    for point in [Vector2(-32,-33),Vector2(35,-57),Vector2(-60,-87),Vector2(66,-103),Vector2(3,-75),Vector2(-72,20),Vector2(83,15)]:
        var size := rng.randf_range(1.8, 3.2)
        var flag := add_asset("res://assets/runtime/world/v04/standard.glb", ground(point.x,point.y) - Vector3.UP * 1.1 * size, rng.randf_range(-0.5,0.5), size)
        for mesh in flag.find_children("*", "MeshInstance3D", true, false):
            mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
            for surface in mesh.mesh.get_surface_count():
                var old: Material = mesh.get_active_material(surface)
                var mat := ShaderMaterial.new()
                mat.shader = preload("res://shaders/world/spirit_cloth.gdshader")
                mat.set_shader_parameter("rune", old.resource_name.contains("Runes"))
                mesh.set_surface_override_material(surface, mat)
        for ap in flag.find_children("*", "AnimationPlayer", true, false):
            for clip in ap.get_animation_list():
                if clip != "RESET":
                    ap.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
                    ap.play(clip)
                    ap.seek(rng.randf_range(0, 4), true)
                    break

func atmosphere() -> void:
    for i in 15:
        var haze := MeshInstance3D.new()
        var plane := PlaneMesh.new()
        plane.size = Vector2(rng.randf_range(50, 85), rng.randf_range(24, 46))
        haze.mesh = plane
        haze.position = ground(rng.randf_range(-70, 70), rng.randf_range(-90, 70)) + Vector3.UP * rng.randf_range(1.3, 4.0)
        haze.rotation_degrees = Vector3(rng.randf_range(-8, 8), rng.randf_range(-180,180), 0)
        var material := ShaderMaterial.new()
        material.shader = preload("res://shaders/world/battle_haze.gdshader")
        material.set_shader_parameter("seed", float(i) * 7.9)
        haze.material_override = material
        haze.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        add_child(haze)
    for i in 6:
        var shaft := MeshInstance3D.new()
        var quad := QuadMesh.new()
        quad.size = Vector2(7 + i * 1.1, 80)
        shaft.mesh = quad
        shaft.position = Vector3(-45 + i * 17, 35, -72 - i * 7)
        shaft.rotation_degrees = Vector3(0, 15, -24)
        var material := ShaderMaterial.new()
        material.shader = preload("res://shaders/world/battle_haze.gdshader")
        material.set_shader_parameter("shaft", true)
        material.set_shader_parameter("tint", Color(0.94, 0.82, 0.56, 0.065))
        shaft.material_override = material
        shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        add_child(shaft)

func ruins() -> void:
    for entry in [Vector3(-15,-32,0.25),Vector3(22,-47,-0.35),Vector3(-17,-74,0.4),Vector3(30,-82,0.1),Vector3(43,-16,0.65)]:
        var file := "res://assets/runtime/world/v05/column.glb"
        if ResourceLoader.exists(file):
            var column := add_asset(file,ground(entry.x,entry.y)-Vector3.UP*0.8,entry.z,1.0)
            column.rotation.z = entry.z*0.3
            for mesh in column.find_children("*","MeshInstance3D",true,false): mesh.create_trimesh_collision()
    for entry in [Vector3(-23,-46,0.3),Vector3(27,-61,-0.55),Vector3(-13,-93,1.1),Vector3(42,-35,0.6)]:
        var file := "res://assets/runtime/world/v05/wall.glb"
        if ResourceLoader.exists(file):
            var wall := add_asset(file,ground(entry.x,entry.y)-Vector3.UP*0.65,entry.z,1.0)
            for mesh in wall.find_children("*","MeshInstance3D",true,false): mesh.create_trimesh_collision()

func golden_tree(tree: Node3D) -> void:
    for mesh in tree.find_children("*","MeshInstance3D",true,false):
        for surface in mesh.mesh.get_surface_count():
            var old: StandardMaterial3D = mesh.get_active_material(surface)
            if not old: continue
            var material := ShaderMaterial.new()
            material.shader = load("res://shaders/world/golden_fissures.gdshader")
            material.set_shader_parameter("albedo_tex",old.albedo_texture)
            material.set_shader_parameter("base_color",old.albedo_color)
            mesh.set_surface_override_material(surface,material)

func fallen_mounds() -> void:
    # Independent scattered draws: no fixed cluster size, with a clear approach corridor.
    var scatter_rng := RandomNumberGenerator.new()
    scatter_rng.seed = 928266
    for i in 58:
        var angle := scatter_rng.randf_range(-PI,PI)
        var radius := scatter_rng.randf_range(13,67)
        var point := ground(8+sin(angle)*radius,-65+cos(angle)*radius*0.8)
        if absf(point.x-7)<5.5 and point.z> -59 and point.z< -12: continue
        var variant := scatter_rng.randi_range(1,3)
        var size := scatter_rng.randf_range(0.55,1.65)
        var toward := Vector3(8,0,-80)-point
        var yaw := atan2(toward.x,toward.z)+scatter_rng.randf_range(-0.95,0.95)
        var asset := "res://assets/runtime/world/v06/fallen_%d.glb" % variant
        var mound := add_asset(asset,point-Vector3.UP*scatter_rng.randf_range(0.04,0.23),yaw,size)
        for mesh in mound.find_children("*","MeshInstance3D",true,false):
            mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
            mesh.visibility_range_end = 80
            mesh.visibility_range_end_margin = 8
