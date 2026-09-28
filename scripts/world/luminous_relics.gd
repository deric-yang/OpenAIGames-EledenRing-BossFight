class_name LuminousRelics
extends Node3D
## Sparse emissive runes physically laid onto selected buried blades, with batched geometry.
var rune_mesh := ImmediateMesh.new()
var metal_mesh := ImmediateMesh.new()
var records: Array[Dictionary] = []
func _ready() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = 9272658
    var metal := StandardMaterial3D.new()
    metal.albedo_color = Color("454641")
    metal.metallic = 0.75
    metal.roughness = 0.65
    var glow := StandardMaterial3D.new()
    glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    glow.albedo_color = Color("ffd77d")
    glow.emission_enabled = true
    glow.emission = Color("ffb933")
    glow.emission_energy_multiplier = 1.6
    glow.cull_mode = BaseMaterial3D.CULL_DISABLED
    for pair in [[metal_mesh,metal],[rune_mesh,glow]]:
        var node := MeshInstance3D.new()
        node.mesh = pair[0]
        node.material_override = pair[1]
        node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        add_child(node)
    metal_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
    rune_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
    for i in 22:
        var x := rng.randf_range(-26,30)
        var z := rng.randf_range(-98,24)
        if i<3: x = -3.0-i*2; z = 24-i*7
        var upright := i%3 != 0
        var basis := Basis.from_euler(Vector3(0.18 if upright else 1.50,rng.randf_range(-PI,PI),rng.randf_range(-0.3,0.3)))
        var pos := Vector3(x,DuneHeightV04.sample(x,z)+(0.18 if upright else 0.07),z)
        var transform := Transform3D(basis.scaled(Vector3.ONE*rng.randf_range(0.9,1.5)),pos)
        records.append({"position":pos,"basis":basis})
        quad(metal_mesh,transform,Vector3(-0.13,0,0),Vector3(0.13,0,0),Vector3(0.1,1.5,0),Vector3(-0.1,1.5,0))
        quad(metal_mesh,transform,Vector3(-0.31,1.23,0.012),Vector3(0.31,1.23,0.012),Vector3(0.31,1.3,0.012),Vector3(-0.31,1.3,0.012))
        for symbol in 4:
            var center := Vector3(0,0.28+symbol*0.22,0.012)
            stroke(transform,center+Vector3(0,-0.08,0),center+Vector3(0,0.08,0))
            stroke(transform,center+Vector3(0,0.07,0),center+Vector3(0.066,0.025,0))
            stroke(transform,center+Vector3(0,-0.025,0),center+Vector3(-0.06,0.02 if symbol%2 else 0.07,0))
        var halo := MeshInstance3D.new()
        var plane := QuadMesh.new()
        plane.size = Vector2(0.5,1.35)
        halo.mesh = plane
        halo.position = transform*Vector3(0,0.65,0.04)
        var shader := ShaderMaterial.new()
        shader.shader = load("res://shaders/vfx/soft_glow.gdshader")
        shader.set_shader_parameter("tint",Color(1,0.6,0.14,0.16))
        halo.material_override = shader
        halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        halo.visibility_range_end = 45
        add_child(halo)
    metal_mesh.surface_end()
    rune_mesh.surface_end()
func quad(mesh: ImmediateMesh,t: Transform3D,a: Vector3,b: Vector3,c: Vector3,d: Vector3) -> void:
    for point in [a,b,c,a,c,d]:
        mesh.surface_set_normal(t.basis*Vector3.FORWARD)
        mesh.surface_add_vertex(t*point)
func stroke(t: Transform3D,a: Vector3,b: Vector3) -> void:
    var direction := (b-a).normalized()
    var side := Vector3(-direction.y,direction.x,0)*0.008
    quad(rune_mesh,t,a-side,b-side,b+side,a+side)
