class_name WardenEyes
extends Node3D
var avatar: DuelAvatar
var attachment: BoneAttachment3D
var cores: Array[Node3D] = []
var history: Array[Dictionary] = []
var streak := ImmediateMesh.new()
var streak_node: MeshInstance3D
func setup(owner_avatar: DuelAvatar) -> void:
    avatar = owner_avatar
    attachment = BoneAttachment3D.new()
    avatar.rig.add_child(attachment)
    attachment.bone_idx = avatar.target_bones.head
    avatar.rig.force_update_all_bone_transforms()
    var head_frame := avatar.rig.global_transform * avatar.rig.get_bone_global_rest(avatar.target_bones.head)
    var material := StandardMaterial3D.new()
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.albedo_color = Color(1,0.025,0.012)
    material.emission_enabled = true
    material.emission = Color(1,0.02,0.006)
    material.emission_energy_multiplier = 2.5
    for side in [-1,1]:
        var eye := MeshInstance3D.new()
        var sphere := SphereMesh.new()
        sphere.radius = 0.005
        sphere.height = 0.008
        sphere.radial_segments = 12
        sphere.rings = 6
        eye.mesh = sphere
        eye.material_override = material
        eye.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        attachment.add_child(eye)
        var offset := avatar.model.global_basis * Vector3(side*0.027,0.11,0.10)
        eye.position = head_frame.basis.inverse() * offset
        cores.append(eye)
        var halo := MeshInstance3D.new()
        var quad := QuadMesh.new()
        quad.size = Vector2(0.15,0.085)
        halo.mesh = quad
        eye.add_child(halo)
        var glow := ShaderMaterial.new()
        glow.shader = load("res://shaders/vfx/soft_glow.gdshader")
        glow.set_shader_parameter("tint",Color(1,0.045,0.012,0.8))
        halo.material_override = glow
        halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    streak_node = MeshInstance3D.new()
    add_child(streak_node)
    streak_node.top_level = true
    streak_node.global_transform = Transform3D.IDENTITY
    streak_node.mesh = streak
    streak_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    var tail_material := StandardMaterial3D.new()
    tail_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    tail_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    tail_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
    tail_material.vertex_color_use_as_albedo = true
    tail_material.cull_mode = BaseMaterial3D.CULL_DISABLED
    streak_node.material_override = tail_material
func tick(delta: float) -> void:
    attachment.global_transform = avatar.bone_transform("head")
    attachment.visible = avatar.model.visible

    for sample in history: sample.age += delta
    history = history.filter(func(sample): return sample.age < 0.16)
    if cores.size()==2:
        if history.is_empty() or history.back().a.distance_to(cores[0].global_position)>0.012:
            history.append({"a":cores[0].global_position,"b":cores[1].global_position,"age":0.0})
    while history.size()>14: history.pop_front()
    streak.clear_surfaces()
    if history.size()<2: return
    var vertices: Array[Dictionary] = []
    for i in range(1,history.size()):
        for side in ["a","b"]:
            var a: Vector3 = history[i-1][side]
            var b: Vector3 = history[i][side]
            if a.distance_to(b)>2: continue
            var width := Vector3.UP*0.025
            for point in [a-width,b-width,b+width,a-width,b+width,a+width]:
                vertices.append({"point":point,"alpha":(1.0-history[i-1].age/0.16)*0.48})
    if vertices.is_empty(): return
    streak.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
    for vertex in vertices:
        streak.surface_set_color(Color(1,0.045,0.012,vertex.alpha))
        streak.surface_add_vertex(vertex.point)
    streak.surface_end()
