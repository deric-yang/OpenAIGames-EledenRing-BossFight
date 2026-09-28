extends Node3D
## Original branch crown. One deterministic clock drives metal removal and surface grains.
const GRAIN_COUNT := 22000
var crown: MeshInstance3D
var grains: MultiMeshInstance3D
var material: ShaderMaterial
var grain_material: ShaderMaterial
var triangles := PackedVector3Array()
var cumulative := PackedFloat32Array()
var area := 0.0
var frame := Transform3D.IDENTITY
var builder: SurfaceTool

func _ready() -> void:
    builder = SurfaceTool.new()
    builder.begin(Mesh.PRIMITIVE_TRIANGLES)
    # Two chased bands, a scalloped upper rim and branching laurel spires.
    for band in 3:
        var points := PackedVector3Array()
        for i in 97:
            var a := TAU * i / 96.0
            var y := band * 0.057 + (0.025 * sin(a * 12.0) if band == 2 else 0.0)
            points.append(Vector3(cos(a) * 0.65, y, sin(a) * 0.52))
        tube(points, 0.025 if band != 1 else 0.041)
    for i in 12:
        var a := TAU * i / 12.0
        var radial := Vector3(cos(a), 0, sin(a))
        var tangent := Vector3(-sin(a), 0, cos(a))
        var base := Vector3(cos(a) * 0.65, 0.10, sin(a) * 0.52)
        var height := 0.55 + 0.12 * cos(a * 2.0)
        var stem := PackedVector3Array()
        for k in 8:
            var f := k / 7.0
            stem.append(base + Vector3.UP * height * f + radial * (0.11 * f * f))
        tube(stem, 0.029)
        for k in 4:
            var f := 0.24 + k * 0.16
            var start := base + Vector3.UP * height * f + radial * (0.11 * f * f)
            for side in [-1.0, 1.0]:
                var tip: Vector3 = start + tangent * side * (0.17 - k * 0.028) + Vector3.UP * (0.14 - k * 0.012) + radial * 0.035
                tube(PackedVector3Array([start, start.lerp(tip, 0.55) - Vector3.UP * 0.025, tip]), 0.018)
                leaf(start.lerp(tip, 0.55), tip + Vector3.UP * 0.03, radial, 0.035)
        leaf(stem[6], stem[7] + Vector3.UP * 0.065, tangent, 0.044)
        var arc := PackedVector3Array()
        for k in 13:
            var b := a + TAU / 12.0 * k / 12.0
            arc.append(Vector3(cos(b) * 0.653, 0.17 + 0.09 * sin(PI * k / 12.0), sin(b) * 0.523))
        tube(arc, 0.012)
    builder.generate_normals()
    crown = MeshInstance3D.new()
    crown.name = "BranchCrown"
    crown.mesh = builder.commit()
    material = ShaderMaterial.new()
    material.shader = preload("res://shaders/cinematic/crown.gdshader")
    crown.material_override = material
    add_child(crown)

func triangle(a: Vector3, b: Vector3, c: Vector3) -> void:
    for point in [a, b, c]:
        builder.add_vertex(point)
        triangles.append(point)
    area += (b - a).cross(c - a).length() * 0.5
    cumulative.append(area)

func tube(points: PackedVector3Array, radius: float) -> void:
    for segment in points.size() - 1:
        var axis := (points[segment + 1] - points[segment]).normalized()
        var x := axis.cross(Vector3.FORWARD if absf(axis.dot(Vector3.UP)) > 0.95 else Vector3.UP).normalized()
        var z := axis.cross(x)
        for j in 7:
            var a := TAU * j / 7.0
            var b := TAU * (j + 1) / 7.0
            var ring_a := (x * cos(a) + z * sin(a)) * radius
            var ring_b := (x * cos(b) + z * sin(b)) * radius
            var taper := 1.0 if points.size() > 20 else lerpf(1.0, 0.35, float(segment + 1) / (points.size() - 1))
            var p := points[segment] + ring_a
            var q := points[segment] + ring_b
            var r := points[segment + 1] + ring_b * taper
            var s := points[segment + 1] + ring_a * taper
            triangle(p, r, q)
            triangle(p, s, r)

func leaf(base: Vector3, tip: Vector3, side: Vector3, width: float) -> void:
    var middle := base.lerp(tip, 0.43)
    var ridge := middle + Vector3.UP * 0.016
    triangle(base, middle - side * width, ridge)
    triangle(base, ridge, middle + side * width)
    triangle(tip, ridge, middle - side * width)
    triangle(tip, middle + side * width, ridge)

static func release_time(point: Vector3) -> float:
    var noise := sin(point.x * 19.0 + point.z * 13.0) * sin(point.y * 25.0 - point.z * 17.0)
    return 0.7 + 6.0 * clampf((point.y + 0.08) / 0.94 + noise * 0.065, 0.0, 1.0)

func transform_at(time: float) -> Transform3D:
    var tilt := lerpf(-0.06, -0.30, smoothstep(0.3, 5.5, time))
    var settle := smoothstep(6.8, 8.4, time)
    return frame * Transform3D(Basis.from_euler(Vector3(tilt, 0, 0.035 * sin(time * 0.4))), Vector3(0, -0.20 * settle, 0.04 * sin(time * 0.45)))

func prepare(at: Transform3D) -> void:
    frame = at
    if is_instance_valid(grains): grains.free()
    grains = MultiMeshInstance3D.new()
    grains.name = "CrownSurfaceSand"
    var multi := MultiMesh.new()
    multi.transform_format = MultiMesh.TRANSFORM_3D
    multi.use_custom_data = true
    var grain := SphereMesh.new()
    grain.radial_segments = 4
    grain.rings = 1
    grain.radius = 1.0
    grain.height = 2.0
    multi.mesh = grain
    multi.instance_count = GRAIN_COUNT
    grain_material = ShaderMaterial.new()
    grain_material.shader = preload("res://shaders/cinematic/crown_grains.gdshader")
    grains.material_override = grain_material
    grains.multimesh = multi
    grains.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(grains)
    grains.top_level = true
    grains.global_transform = Transform3D.IDENTITY
    # Shader motion is in world space, so the bounds include the entire fall corridor.
    multi.custom_aabb = AABB(frame.origin - Vector3(4, 8, 4), Vector3(8, 12, 8))
    var rng := RandomNumberGenerator.new()
    rng.seed = 9281729
    for i in GRAIN_COUNT:
        var index := cumulative.bsearch(rng.randf() * area)
        index = mini(index, cumulative.size() - 1) * 3
        var u := sqrt(rng.randf())
        var v := rng.randf()
        var point := triangles[index] * (1.0 - u) + triangles[index + 1] * (u * (1.0 - v)) + triangles[index + 2] * u * v
        var born := release_time(point)
        var world_point := transform_at(born) * point
        var size := rng.randf_range(0.0025, 0.006)
        multi.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(size, size * rng.randf_range(1.0, 1.8), size)), world_point))
        multi.set_instance_custom_data(i, Color(born, rng.randf(), DuneHeightV04.sample(world_point.x, world_point.z) + 0.025, rng.randf_range(1.25, 1.9)))
    sample(0.0)

func sample(time: float) -> void:
    crown.global_transform = transform_at(time)
    material.set_shader_parameter("cutscene_time", time)
    if grain_material: grain_material.set_shader_parameter("cutscene_time", time)
