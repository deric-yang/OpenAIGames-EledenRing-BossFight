class_name DunesScenery
extends Node3D

## Self-contained Weeping Dunes scenery pass.
## Runtime geometry is intentionally procedural: it is not a Tripo or approved asset proxy.

const TREE_ROOT := Vector3(0.0, 0.0, -38.0)
const PLAYABLE_EXTENTS := Vector2(11.0, 9.0)
const GOLD := Color("b98225")
const DARK_BARK := Color("121116")

var playable_surface: MeshInstance3D
var _built := false
var _sand_material: StandardMaterial3D
var _core_material: StandardMaterial3D
var _bark_material: StandardMaterial3D
var _masonry_material: StandardMaterial3D
var _masonry_light_material: StandardMaterial3D
var _flag_material: StandardMaterial3D
var _weapon_material: StandardMaterial3D
var _gold_material: StandardMaterial3D
var _veil_shader: Shader


func build() -> void:
    if _built:
        return
    _built = true
    _make_materials()
    _build_ground()
    _build_tree()
    _build_veils()
    _build_border_ruins()
    _build_flags()
    _build_weapon_debris()


func _make_materials() -> void:
    _sand_material = _material(Color("5d4940"), 0.0, 0.98)
    _core_material = _material(Color("332d31"), 0.08, 0.88)
    _bark_material = _material(DARK_BARK, 0.04, 0.94)
    _masonry_material = _material(Color("514348"), 0.05, 0.9)
    _masonry_light_material = _material(Color("675254"), 0.0, 0.94)
    _flag_material = _material(Color("503238"), 0.0, 0.9)
    _weapon_material = _material(Color("6f6870"), 0.72, 0.3)

    # Keep the fissures gold rather than white-hot. Compatibility has no bloom requirement here.
    _gold_material = StandardMaterial3D.new()
    _gold_material.albedo_color = Color("6f4814")
    _gold_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    _gold_material.emission_enabled = true
    _gold_material.emission = GOLD
    _gold_material.emission_energy_multiplier = 0.82
    _gold_material.cull_mode = BaseMaterial3D.CULL_DISABLED


func _build_ground() -> void:
    var terrain := MeshInstance3D.new()
    terrain.name = "Scenery_RollingSandTerrain"
    terrain.mesh = _build_terrain_mesh(23, 27)
    terrain.material_override = _sand_material
    add_child(terrain)
    _build_terrain_collision(23, 27)

    # The top face is exactly y=0 and stays within x +/-11, z +/-9.
    playable_surface = MeshInstance3D.new()
    playable_surface.name = "Scenery_PlayableCore"
    var core_mesh := BoxMesh.new()
    core_mesh.size = Vector3(22.0, 0.08, 18.0)
    playable_surface.mesh = core_mesh
    playable_surface.position = Vector3(0.0, -0.04, 0.0)
    playable_surface.material_override = _core_material
    add_child(playable_surface)
    _build_playable_collision()


func _build_playable_collision() -> void:
    var body := StaticBody3D.new()
    body.name = "Scenery_PlayableCoreCollision"
    body.collision_layer = 1
    body.collision_mask = 0
    var collision := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = Vector3(22.0, 0.2, 18.0)
    collision.shape = shape
    collision.position.y = -0.1
    body.add_child(collision)
    add_child(body)


func _build_terrain_mesh(columns: int, rows: int) -> ArrayMesh:
    var vertices := PackedVector3Array()
    var normals := PackedVector3Array()
    var uvs := PackedVector2Array()
    var indices := PackedInt32Array()
    var x_step := 120.0 / float(columns - 1)
    var z_step := 140.0 / float(rows - 1)

    for z_index in range(rows):
        var z := -70.0 + float(z_index) * z_step
        for x_index in range(columns):
            var x := -60.0 + float(x_index) * x_step
            vertices.append(Vector3(x, _terrain_height(x, z), z))
            uvs.append(Vector2(float(x_index) / float(columns - 1), float(z_index) / float(rows - 1)))

            var h_left := _terrain_height(x - x_step, z)
            var h_right := _terrain_height(x + x_step, z)
            var h_back := _terrain_height(x, z - z_step)
            var h_front := _terrain_height(x, z + z_step)
            normals.append(Vector3(
                (h_left - h_right) / (2.0 * x_step),
                1.0,
                (h_back - h_front) / (2.0 * z_step)
            ).normalized())

    for z_index in range(rows - 1):
        for x_index in range(columns - 1):
            var row_start := z_index * columns + x_index
            var next_row := row_start + columns
            indices.append(row_start)
            indices.append(next_row)
            indices.append(row_start + 1)
            indices.append(row_start + 1)
            indices.append(next_row)
            indices.append(next_row + 1)

    var arrays: Array = []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = vertices
    arrays[Mesh.ARRAY_NORMAL] = normals
    arrays[Mesh.ARRAY_TEX_UV] = uvs
    arrays[Mesh.ARRAY_INDEX] = indices
    var mesh := ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    return mesh


func _build_terrain_collision(columns: int, rows: int) -> void:
    var faces := PackedVector3Array()
    var x_step := 120.0 / float(columns - 1)
    var z_step := 140.0 / float(rows - 1)
    for z_index in range(rows - 1):
        var z := -70.0 + float(z_index) * z_step
        for x_index in range(columns - 1):
            var x := -60.0 + float(x_index) * x_step
            var a := Vector3(x, _terrain_height(x, z), z)
            var b := Vector3(x, _terrain_height(x, z + z_step), z + z_step)
            var c := Vector3(x + x_step, _terrain_height(x + x_step, z), z)
            var d := Vector3(x + x_step, _terrain_height(x + x_step, z + z_step), z + z_step)
            faces.append(a)
            faces.append(b)
            faces.append(c)
            faces.append(c)
            faces.append(b)
            faces.append(d)

    var body := StaticBody3D.new()
    body.name = "Scenery_RollingSandCollision"
    body.collision_layer = 1
    body.collision_mask = 0
    var collision := CollisionShape3D.new()
    var shape := ConcavePolygonShape3D.new()
    shape.set_faces(faces)
    collision.shape = shape
    body.add_child(collision)
    add_child(body)


func _terrain_height(x: float, z: float) -> float:
    var edge_x := maxf(absf(x) - PLAYABLE_EXTENTS.x, 0.0)
    var edge_z := maxf(absf(z) - PLAYABLE_EXTENTS.y, 0.0)
    var edge := clampf(maxf(edge_x / 18.0, edge_z / 18.0), 0.0, 1.0)
    if edge <= 0.0:
        return 0.0

    var shoulder := smoothstep(0.0, 1.0, edge)
    var broad_dune := sin(x * 0.13 + z * 0.035) * 0.52
    broad_dune += cos(z * 0.11 - x * 0.045) * 0.38
    broad_dune += sin((x + z) * 0.055) * 0.24
    return maxf(0.0, shoulder * (0.18 + edge * 1.65) + broad_dune * edge)


func _build_tree() -> void:
    var tree := Node3D.new()
    tree.name = "Scenery_WeepingBlackTree"
    tree.position = TREE_ROOT
    add_child(tree)

    # Every path is a tapered tube and all paths share one mesh. Branches overlap the
    # trunk/root rings, producing a joined silhouette rather than detached poles.
    var paths: Array = [
        _path(
            [Vector3(0.0, 0.0, 0.0), Vector3(-0.45, 3.2, 0.0), Vector3(0.3, 7.0, 0.0), Vector3(-0.2, 11.0, 0.0), Vector3(0.35, 15.1, 0.0), Vector3(-0.25, 20.0, 0.0), Vector3(0.25, 25.7, 0.0)],
            [3.5, 3.15, 2.75, 2.35, 1.85, 1.25, 0.34]
        ),
        _path(
            [Vector3(-0.15, 10.8, 0.0), Vector3(-2.9, 13.8, 0.15), Vector3(-6.7, 15.5, 0.25), Vector3(-10.6, 17.2, 0.1), Vector3(-14.0, 19.3, 0.0)],
            [2.1, 1.55, 1.1, 0.7, 0.22]
        ),
        _path(
            [Vector3(0.15, 11.7, 0.0), Vector3(3.0, 14.6, 0.1), Vector3(6.7, 16.7, 0.0), Vector3(10.6, 18.6, -0.2), Vector3(14.0, 20.8, -0.1)],
            [2.0, 1.55, 1.05, 0.65, 0.2]
        ),
        _path(
            [Vector3(-0.18, 15.2, 0.0), Vector3(-2.4, 19.2, 0.2), Vector3(-5.7, 21.8, 0.35), Vector3(-9.0, 24.2, 0.55)],
            [1.55, 1.05, 0.6, 0.16]
        ),
        _path(
            [Vector3(0.25, 16.4, 0.0), Vector3(2.7, 20.0, 0.1), Vector3(5.8, 22.2, 0.4), Vector3(9.1, 25.0, 0.7)],
            [1.35, 0.95, 0.54, 0.15]
        ),
        _path(
            [Vector3(-0.12, 9.7, 0.45), Vector3(-1.8, 11.8, 2.0), Vector3(-4.1, 14.1, 3.1), Vector3(-7.0, 16.0, 3.6)],
            [1.35, 0.95, 0.55, 0.16]
        ),
        _path(
            [Vector3(0.15, 13.5, -0.2), Vector3(1.8, 16.3, -1.3), Vector3(4.3, 18.3, -2.3), Vector3(7.3, 20.0, -2.6)],
            [1.2, 0.82, 0.45, 0.14]
        ),
        _path(
            [Vector3(0.0, 0.0, 0.0), Vector3(-3.0, 0.18, 0.8), Vector3(-6.8, 0.08, 1.0), Vector3(-9.6, 0.0, 0.65)],
            [2.2, 1.35, 0.7, 0.18]
        ),
        _path(
            [Vector3(0.0, 0.0, 0.0), Vector3(3.1, 0.16, 0.7), Vector3(6.9, 0.08, 0.85), Vector3(9.4, 0.0, 0.45)],
            [2.1, 1.25, 0.62, 0.18]
        ),
        _path(
            [Vector3(0.0, 0.0, 0.2), Vector3(0.8, 0.16, 2.0), Vector3(1.8, 0.08, 4.2), Vector3(2.8, 0.0, 5.6)],
            [2.0, 1.2, 0.58, 0.14]
        )
    ]

    var trunk_mesh := MeshInstance3D.new()
    trunk_mesh.name = "TreeJoinedTaperedTubes"
    trunk_mesh.mesh = _build_tube_mesh(paths, 9)
    trunk_mesh.material_override = _bark_material
    tree.add_child(trunk_mesh)
    _build_tree_cracks(tree)


func _path(points: Array, radii: Array) -> Dictionary:
    return {"points": points, "radii": radii}


func _build_tube_mesh(paths: Array, radial_segments: int) -> ArrayMesh:
    var vertices := PackedVector3Array()
    var normals := PackedVector3Array()
    var uvs := PackedVector2Array()
    var indices := PackedInt32Array()
    var ring_starts: Array = []

    for path_data in paths:
        var points: Array = path_data["points"]
        var radii: Array = path_data["radii"]
        var path_start := vertices.size()
        ring_starts.append(path_start)
        for point_index in range(points.size()):
            var point: Vector3 = points[point_index]
            var tangent: Vector3
            if point_index == 0:
                tangent = (points[1] - points[0]).normalized()
            elif point_index == points.size() - 1:
                tangent = (points[point_index] - points[point_index - 1]).normalized()
            else:
                tangent = (points[point_index + 1] - points[point_index - 1]).normalized()
            var side := tangent.cross(Vector3.UP)
            if side.length_squared() < 0.01:
                side = tangent.cross(Vector3.RIGHT)
            side = side.normalized()
            var up := side.cross(tangent).normalized()
            var ring_radius := float(radii[point_index])
            for radial_index in range(radial_segments):
                var angle := TAU * float(radial_index) / float(radial_segments)
                var radial := side * cos(angle) + up * sin(angle)
                vertices.append(point + radial * ring_radius)
                normals.append(radial)
                uvs.append(Vector2(float(radial_index) / float(radial_segments), float(point_index) / float(points.size() - 1)))

        for point_index in range(points.size() - 1):
            var ring_a := path_start + point_index * radial_segments
            var ring_b := ring_a + radial_segments
            for radial_index in range(radial_segments):
                var next_radial := (radial_index + 1) % radial_segments
                indices.append(ring_a + radial_index)
                indices.append(ring_b + radial_index)
                indices.append(ring_a + next_radial)
                indices.append(ring_a + next_radial)
                indices.append(ring_b + radial_index)
                indices.append(ring_b + next_radial)

    var arrays: Array = []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = vertices
    arrays[Mesh.ARRAY_NORMAL] = normals
    arrays[Mesh.ARRAY_TEX_UV] = uvs
    arrays[Mesh.ARRAY_INDEX] = indices
    var mesh := ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    return mesh


func _build_tree_cracks(tree: Node3D) -> void:
    var cracks: Array = [
        {"width": 0.075, "points": [Vector3(0.45, 3.3, 2.65), Vector3(0.18, 5.2, 2.7), Vector3(0.42, 7.0, 2.45), Vector3(0.1, 8.8, 2.32)]},
        {"width": 0.055, "points": [Vector3(-0.88, 7.4, 2.52), Vector3(-0.62, 9.1, 2.5), Vector3(-0.98, 10.8, 2.25), Vector3(-0.72, 12.2, 2.12)]},
        {"width": 0.06, "points": [Vector3(-1.1, 12.3, 2.02), Vector3(-2.3, 13.8, 1.08), Vector3(-3.7, 14.7, 0.68), Vector3(-5.0, 15.0, 0.52)]},
        {"width": 0.05, "points": [Vector3(0.72, 15.9, 1.58), Vector3(1.75, 17.6, 1.1), Vector3(3.1, 18.8, 0.92), Vector3(4.5, 19.5, 0.75)]},
        {"width": 0.048, "points": [Vector3(-0.15, 17.7, 1.42), Vector3(-1.2, 19.2, 1.0), Vector3(-2.15, 20.6, 0.82)]}
    ]
    var crack_mesh := MeshInstance3D.new()
    crack_mesh.name = "TreeCameraFacingGoldCracks"
    crack_mesh.mesh = _build_ribbon_mesh(cracks)
    crack_mesh.material_override = _gold_material
    tree.add_child(crack_mesh)


func _build_ribbon_mesh(ribbons: Array) -> ArrayMesh:
    var vertices := PackedVector3Array()
    var normals := PackedVector3Array()
    var uvs := PackedVector2Array()
    var indices := PackedInt32Array()

    for ribbon in ribbons:
        var points: Array = ribbon["points"]
        var width := float(ribbon["width"])
        var ribbon_start := vertices.size()
        for point_index in range(points.size()):
            var point: Vector3 = points[point_index]
            var previous: Vector3 = points[maxi(point_index - 1, 0)]
            var next_point: Vector3 = points[mini(point_index + 1, points.size() - 1)]
            var direction := (next_point - previous).normalized()
            var across := Vector3(-direction.y, direction.x, 0.0).normalized() * width
            vertices.append(point - across)
            vertices.append(point + across)
            normals.append(Vector3.FORWARD)
            normals.append(Vector3.FORWARD)
            uvs.append(Vector2(0.0, float(point_index) / float(points.size() - 1)))
            uvs.append(Vector2(1.0, float(point_index) / float(points.size() - 1)))

        for point_index in range(points.size() - 1):
            var quad := ribbon_start + point_index * 2
            indices.append(quad)
            indices.append(quad + 2)
            indices.append(quad + 1)
            indices.append(quad + 1)
            indices.append(quad + 2)
            indices.append(quad + 3)

    var arrays: Array = []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = vertices
    arrays[Mesh.ARRAY_NORMAL] = normals
    arrays[Mesh.ARRAY_TEX_UV] = uvs
    arrays[Mesh.ARRAY_INDEX] = indices
    var mesh := ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    return mesh


func _build_veils() -> void:
    _veil_shader = load("res://shaders/world/veil.gdshader") as Shader
    if _veil_shader == null:
        return

    var veil_data := [
        {"position": Vector3(-14.0, 11.0, -28.0), "size": Vector2(6.0, 16.0), "curve": 1.0, "phase": 0.0, "color": Color(0.56, 0.32, 0.4, 0.38)},
        {"position": Vector3(-5.2, 14.0, -31.0), "size": Vector2(5.5, 19.0), "curve": -0.8, "phase": 1.4, "color": Color(0.5, 0.29, 0.37, 0.34)},
        {"position": Vector3(5.4, 13.0, -32.0), "size": Vector2(6.5, 17.0), "curve": 0.9, "phase": 2.7, "color": Color(0.6, 0.36, 0.43, 0.34)},
        {"position": Vector3(14.5, 10.0, -28.0), "size": Vector2(5.0, 14.0), "curve": -0.7, "phase": 3.8, "color": Color(0.48, 0.28, 0.36, 0.32)}
    ]

    for veil_index in range(veil_data.size()):
        var data: Dictionary = veil_data[veil_index]
        var veil := MeshInstance3D.new()
        veil.name = "Scenery_TornVeil_%02d" % veil_index
        veil.mesh = _build_veil_mesh(data["size"], float(data["curve"]), veil_index)
        veil.position = data["position"]
        veil.rotation_degrees = Vector3(0.0, -4.0 + float(veil_index) * 3.0, -2.0 + float(veil_index % 2) * 4.0)
        var veil_material := ShaderMaterial.new()
        veil_material.shader = _veil_shader
        veil_material.set_shader_parameter("veil_color", data["color"])
        veil_material.set_shader_parameter("phase", float(data["phase"]))
        veil.material_override = veil_material
        add_child(veil)


func _build_veil_mesh(size: Vector2, curve: float, seed: int) -> ArrayMesh:
    var columns := 7
    var rows := 9
    var vertices := PackedVector3Array()
    var normals := PackedVector3Array()
    var uvs := PackedVector2Array()
    var indices := PackedInt32Array()

    for row in range(rows):
        var v := float(row) / float(rows - 1)
        for column in range(columns):
            var u := float(column) / float(columns - 1)
            var x := (u - 0.5) * size.x
            var edge_wave := sin(u * PI * 2.0 + float(seed) * 0.7) * 0.22
            var bottom := -0.55 - absf(sin(u * PI * 2.5 + float(seed))) * 0.8 + edge_wave
            var y := lerpf(bottom, size.y, v)
            var z := sin(u * PI) * curve * sin(v * PI) + sin(v * PI * 1.7 + u * 2.0) * 0.12
            vertices.append(Vector3(x, y, z))
            normals.append(Vector3.FORWARD)
            uvs.append(Vector2(u, v))

    for row in range(rows - 1):
        for column in range(columns - 1):
            var current := row * columns + column
            var next_row := current + columns
            indices.append(current)
            indices.append(next_row)
            indices.append(current + 1)
            indices.append(current + 1)
            indices.append(next_row)
            indices.append(next_row + 1)

    var arrays: Array = []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = vertices
    arrays[Mesh.ARRAY_NORMAL] = normals
    arrays[Mesh.ARRAY_TEX_UV] = uvs
    arrays[Mesh.ARRAY_INDEX] = indices
    var mesh := ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    return mesh


func _build_border_ruins() -> void:
    var blocks := [
        {"position": Vector3(-15.0, 0.0, -3.0), "size": Vector3(2.8, 1.55, 2.0), "rotation": Vector3(-3.0, -18.0, 4.0), "light": false},
        {"position": Vector3(-18.5, 0.0, 1.8), "size": Vector3(2.1, 2.8, 2.3), "rotation": Vector3(7.0, 12.0, -3.0), "light": true},
        {"position": Vector3(15.0, 0.0, 3.0), "size": Vector3(2.6, 2.1, 2.1), "rotation": Vector3(2.0, 24.0, -5.0), "light": false},
        {"position": Vector3(19.0, 0.0, -1.8), "size": Vector3(2.0, 3.2, 2.7), "rotation": Vector3(-4.0, -13.0, 5.0), "light": true},
        {"position": Vector3(-5.5, 0.0, 13.6), "size": Vector3(3.4, 1.25, 2.0), "rotation": Vector3(4.0, -22.0, 0.0), "light": false},
        {"position": Vector3(5.2, 0.0, 15.4), "size": Vector3(2.2, 2.2, 2.8), "rotation": Vector3(-4.0, 31.0, 3.0), "light": true},
        {"position": Vector3(-15.8, 0.0, 16.0), "size": Vector3(3.6, 1.7, 2.1), "rotation": Vector3(3.0, 8.0, 5.0), "light": false},
        {"position": Vector3(16.8, 0.0, 16.8), "size": Vector3(3.2, 1.35, 2.4), "rotation": Vector3(-2.0, -28.0, -4.0), "light": false},
        {"position": Vector3(-18.0, 0.0, -16.0), "size": Vector3(2.8, 1.6, 2.6), "rotation": Vector3(6.0, 17.0, 1.0), "light": true},
        {"position": Vector3(18.5, 0.0, -15.5), "size": Vector3(2.8, 2.3, 2.0), "rotation": Vector3(-5.0, -19.0, 4.0), "light": false}
    ]
    var ruin_body := StaticBody3D.new()
    ruin_body.name = "Scenery_RuinCollisionProxies"
    ruin_body.collision_layer = 1
    ruin_body.collision_mask = 0
    add_child(ruin_body)
    for index in range(blocks.size()):
        var data: Dictionary = blocks[index]
        var block := _box_mesh("Scenery_RuinBlock_%02d" % index, data["position"], data["size"], _masonry_light_material if data["light"] else _masonry_material)
        block.rotation_degrees = data["rotation"]

        var ruin_collision := CollisionShape3D.new()
        ruin_collision.name = "RuinBlockCollision_%02d" % index
        var ruin_shape := BoxShape3D.new()
        ruin_shape.size = data["size"]
        ruin_collision.shape = ruin_shape
        var block_position: Vector3 = data["position"]
        ruin_collision.position = Vector3(block_position.x, _terrain_height(block_position.x, block_position.z) + float(data["size"].y) * 0.5, block_position.z)
        ruin_collision.rotation_degrees = data["rotation"]
        ruin_body.add_child(ruin_collision)


func _build_flags() -> void:
    var flag_data := [
        {"position": Vector3(-20.0, 0.0, -5.0), "height": 4.2, "phase": 0.0},
        {"position": Vector3(21.0, 0.0, 6.0), "height": 3.7, "phase": 1.8},
        {"position": Vector3(-9.0, 0.0, 20.0), "height": 3.4, "phase": 3.2}
    ]
    for index in range(flag_data.size()):
        var data: Dictionary = flag_data[index]
        var position: Vector3 = data["position"]
        var pole := MeshInstance3D.new()
        pole.name = "Scenery_FlagPole_%02d" % index
        var pole_mesh := CylinderMesh.new()
        pole_mesh.top_radius = 0.055
        pole_mesh.bottom_radius = 0.09
        pole_mesh.height = float(data["height"])
        pole_mesh.radial_segments = 6
        pole.mesh = pole_mesh
        pole.position = Vector3(position.x, _terrain_height(position.x, position.z) + float(data["height"]) * 0.5, position.z)
        pole.material_override = _bark_material
        add_child(pole)

        var cloth := MeshInstance3D.new()
        cloth.name = "Scenery_TornFlag_%02d" % index
        cloth.mesh = _build_flag_mesh(float(data["phase"]))
        cloth.position = pole.position + Vector3(0.04, float(data["height"]) * 0.5 - 0.12, 0.0)
        cloth.material_override = _flag_material
        add_child(cloth)


func _build_flag_mesh(phase: float) -> ArrayMesh:
    var vertices := PackedVector3Array([
        Vector3(0.0, 0.0, 0.0), Vector3(2.25, -0.18, 0.12 + sin(phase) * 0.08),
        Vector3(2.05, -1.2, 0.05), Vector3(1.45, -1.0, -0.05), Vector3(0.0, -1.05, 0.0)
    ])
    var normals := PackedVector3Array()
    var uvs := PackedVector2Array([
        Vector2(0.0, 1.0), Vector2(1.0, 1.0), Vector2(0.92, 0.0), Vector2(0.58, 0.12), Vector2(0.0, 0.08)
    ])
    for _i in range(vertices.size()):
        normals.append(Vector3.FORWARD)
    var indices := PackedInt32Array([0, 1, 4, 1, 2, 4, 2, 3, 4])
    var arrays: Array = []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = vertices
    arrays[Mesh.ARRAY_NORMAL] = normals
    arrays[Mesh.ARRAY_TEX_UV] = uvs
    arrays[Mesh.ARRAY_INDEX] = indices
    var mesh := ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    return mesh


func _build_weapon_debris() -> void:
    var debris := [
        {"position": Vector3(-13.3, 0.0, 8.8), "rotation": Vector3(7.0, -24.0, 18.0)},
        {"position": Vector3(13.8, 0.0, 9.5), "rotation": Vector3(-5.0, 32.0, -12.0)},
        {"position": Vector3(-11.8, 0.0, -13.2), "rotation": Vector3(12.0, 68.0, 9.0)},
        {"position": Vector3(11.7, 0.0, -14.0), "rotation": Vector3(-11.0, -51.0, -14.0)},
        {"position": Vector3(-22.0, 0.0, 11.0), "rotation": Vector3(4.0, 17.0, 28.0)},
        {"position": Vector3(22.5, 0.0, -10.0), "rotation": Vector3(-8.0, 4.0, -22.0)}
    ]
    for index in range(debris.size()):
        var data: Dictionary = debris[index]
        var weapon := _box_mesh("Scenery_BrokenWeapon_%02d" % index, data["position"], Vector3(0.16, 0.13, 2.7), _weapon_material)
        weapon.rotation_degrees = data["rotation"]


func _box_mesh(label: String, position: Vector3, size: Vector3, material: StandardMaterial3D) -> MeshInstance3D:
    var mesh_instance := MeshInstance3D.new()
    mesh_instance.name = label
    var box := BoxMesh.new()
    box.size = size
    mesh_instance.mesh = box
    mesh_instance.position = Vector3(position.x, _terrain_height(position.x, position.z) + size.y * 0.5, position.z)
    mesh_instance.material_override = material
    add_child(mesh_instance)
    return mesh_instance


func _material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.metallic = metallic
    material.roughness = roughness
    return material
