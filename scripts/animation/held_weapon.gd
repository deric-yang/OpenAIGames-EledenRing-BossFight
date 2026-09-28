class_name HeldWeapon
extends Node3D
var avatar: DuelAvatar
var role := ""
var flag: Skeleton3D
var phase := 0.0
var previous := Vector3.ZERO
var sway := Vector3.ZERO
var blade: Node3D
var banner: Node3D

func setup(owner_avatar: DuelAvatar, kind: String) -> void:
    avatar = owner_avatar
    role = kind
    var file := "general_polearm" if role == "general" else "knight_sword"
    blade = load("res://assets/runtime/characters/v04/" + file + ".glb").instantiate()
    add_child(blade)
    blade.position.y = -0.95 if role == "general" else 0
    if role == "knight":
        # Tripo normalized the blade bounds, not the handle: its grip is offset in Z.
        blade.rotation.x = deg_to_rad(18)
        blade.position = -(blade.basis*Vector3(0.001,0.22,0.169))
    if role == "general":
        banner = load("res://assets/runtime/characters/v04/banner_cloth.glb").instantiate()
        blade.add_child(banner)
        for animation_player in banner.find_children("*", "AnimationPlayer", true, false):
            animation_player.active = false
        flag = banner.find_children("*", "Skeleton3D", true, false)[0]
        for mesh in banner.find_children("*", "MeshInstance3D", true, false):
            mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
            # Wind moves the thin cloth outside its imported rest bounds.
            mesh.extra_cull_margin = 0.5
    for mesh in blade.find_children("*", "MeshInstance3D", true, false):
        mesh.lod_bias = 128.0
        mesh.extra_cull_margin = maxf(mesh.extra_cull_margin,0.2)

func tick(delta: float) -> void:
    if avatar.current == "": return
    global_transform = avatar.weapon_transform()
    phase += delta
    if previous != Vector3.ZERO:
        var movement := (global_position - previous) / maxf(delta, 0.001)
        sway = sway.lerp(global_basis.inverse() * movement.limit_length(12.0), 1.0 - exp(-delta * 4.0))
    previous = global_position
    if flag:
        banner.rotation = Vector3.ZERO
        for i in flag.get_bone_count():
            var strength := float(i) / maxf(1, flag.get_bone_count() - 1)
            var angle := sin(phase * 3.2 - i * 0.8) * 0.055 * strength
            angle += clampf(sway.z * 0.01, -0.055, 0.055) * strength
            flag.set_bone_pose_rotation(i, flag.get_bone_rest(i).basis.get_rotation_quaternion() * Quaternion(Vector3.FORWARD, angle) * Quaternion(Vector3.UP, sin(phase * 5 - i) * 0.045 * strength))
        flag.force_update_all_bone_transforms()
