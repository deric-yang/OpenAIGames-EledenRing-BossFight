extends Node3D
## Luminous resurrection marker with a single instanced mote draw.

var sparks: MultiMeshInstance3D
var elapsed := 0.0

func _ready() -> void:
    var path := "res://assets/runtime/assembly/sigil.glb"
    if ResourceLoader.exists(path):
        var model := load(path).instantiate() as Node3D
        model.position.y = -0.04
        add_child(model)
    var ring := MeshInstance3D.new()
    var plane := PlaneMesh.new()
    plane.size = Vector2(3.8, 3.8)
    ring.mesh = plane
    ring.position.y = 0.12
    var glow := ShaderMaterial.new()
    glow.shader = load("res://shaders/world/respawn_sigil.gdshader")
    ring.material_override = glow
    ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(ring)
    var light := OmniLight3D.new()
    light.position.y = 0.8
    light.light_color = Color("ffd063")
    light.light_energy = 3.2
    light.omni_range = 7
    add_child(light)
    var spark_material := ShaderMaterial.new()
    spark_material.shader = load("res://shaders/world/golden_mote.gdshader")
    var quad := QuadMesh.new()
    quad.size = Vector2(0.15, 0.15)
    sparks = MultiMeshInstance3D.new()
    sparks.multimesh = MultiMesh.new()
    sparks.multimesh.transform_format = MultiMesh.TRANSFORM_3D
    sparks.multimesh.mesh = quad
    sparks.multimesh.instance_count = 30
    sparks.material_override = spark_material
    sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(sparks)

func _process(delta: float) -> void:
    elapsed += delta
    var camera := get_viewport().get_camera_3d()
    var facing := global_basis.inverse()*camera.global_basis if camera else Basis.IDENTITY
    for i in 30:
        var phase := fmod(elapsed * 0.18 + float(i) / 30.0, 1.0)
        var angle := float(i) * 2.399 + elapsed * 0.1
        var radius := 0.3 + float(i % 7) * 0.20
        var point := Vector3(cos(angle) * radius, 0.15 + phase * 2.3, sin(angle) * radius)
        sparks.multimesh.set_instance_transform(i,Transform3D(facing.scaled(Vector3.ONE*maxf(0.0001,sin(phase*PI))),point))
