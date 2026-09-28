class_name RespawnBonfire
extends Node3D
## Procedural gameplay marker, pending replacement with authored assets.

var fire_light: OmniLight3D
var elapsed := 0.0
var include_sword := true

func _ready() -> void:
    var coal := StandardMaterial3D.new()
    coal.albedo_color = Color("241d17")
    coal.roughness = 1.0
    var sphere := SphereMesh.new()
    sphere.radius = 0.18
    sphere.height = 0.25
    sphere.radial_segments = 7
    sphere.rings = 3
    sphere.material = coal
    var stones := MultiMeshInstance3D.new()
    stones.multimesh = MultiMesh.new()
    stones.multimesh.transform_format = MultiMesh.TRANSFORM_3D
    stones.multimesh.mesh = sphere
    stones.multimesh.instance_count = 9
    stones.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(stones)
    for i in 9:
        stones.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY,Vector3(cos(i*TAU/9)*0.55,0.09,sin(i*TAU/9)*0.55)))
    var steel := StandardMaterial3D.new()
    steel.albedo_color = Color("a6a7a2")
    steel.metallic = 0.85
    steel.roughness = 0.4
    if include_sword:
        _part(Vector3(0, 0.72, 0), Vector3(0.10, 1.38, 0.035), steel)
        _part(Vector3(0, 1.28, 0), Vector3(0.48, 0.06, 0.09), coal)
        _part(Vector3(0, 1.47, 0), Vector3(0.07, 0.36, 0.07), coal)
    for i in range(3):
        var log_mesh := MeshInstance3D.new()
        var shape := CylinderMesh.new()
        shape.top_radius = 0.07
        shape.bottom_radius = 0.10
        shape.height = 0.9
        shape.radial_segments = 7
        log_mesh.mesh = shape
        log_mesh.material_override = coal
        log_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        log_mesh.position.y = 0.14 + i * 0.025
        log_mesh.rotation = Vector3(PI / 2, i * PI / 3, 0)
        add_child(log_mesh)
    var flame_material := ShaderMaterial.new()
    flame_material.shader = load("res://shaders/world/bonfire.gdshader")
    for i in range(3):
        var flame := MeshInstance3D.new()
        var quad := QuadMesh.new()
        quad.size = Vector2(1.0, 1.1)
        flame.mesh = quad
        flame.material_override = flame_material
        flame.position.y = 0.52
        flame.rotation.y = i * PI / 3
        flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        add_child(flame)
    fire_light = OmniLight3D.new()
    fire_light.position.y = 0.7
    fire_light.light_color = Color("ff913c")
    fire_light.omni_range = 5.0
    fire_light.light_energy = 2.0
    add_child(fire_light)

func _part(center: Vector3, dimensions: Vector3, material: Material) -> void:
    var mesh := MeshInstance3D.new()
    var box := BoxMesh.new()
    box.size = dimensions
    mesh.mesh = box
    mesh.material_override = material
    mesh.position = center
    add_child(mesh)

func _process(delta: float) -> void:
    elapsed += delta
    fire_light.light_energy = 1.8 + sin(elapsed * 9.0) * 0.15 + sin(elapsed * 13.7) * 0.1
