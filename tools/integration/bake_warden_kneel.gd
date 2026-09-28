extends SceneTree
## Author an asymmetrical one-knee pose on the existing target rig and bake transitions.
const OUT := "res://assets/runtime/characters/v04/"
const REMOVED := "combat-master-f19e2a7d3ad551bf0341"
var avatar: DuelAvatar
func _initialize() -> void: call_deferred("run")
func position_of(key: String) -> Vector3:
    return avatar.bone_transform(key).origin
func aim_bone(key: String, child: String, point: Vector3) -> void:
    var bone: int = avatar.target_bones[key]
    var from := position_of(child)-position_of(key)
    var to := point-position_of(key)
    var transform := avatar.bone_transform(key)
    var desired := Basis(Quaternion(from.normalized(),to.normalized()))*transform.basis.orthonormalized()
    var parent: int = avatar.rig.get_bone_parent(bone)
    var parent_basis := avatar.rig.global_basis * avatar.rig.get_bone_global_pose(parent).basis
    avatar.rig.set_bone_pose_rotation(bone,(parent_basis.inverse()*desired).get_rotation_quaternion())
    avatar.rig.force_update_all_bone_transforms()
func solve_limb(a: String,b: String,c: String,target: Vector3,pole: Vector3) -> void:
    var start := position_of(a)
    var upper := start.distance_to(position_of(b))
    var lower := position_of(b).distance_to(position_of(c))
    var axis := (target-start).normalized()
    var distance := clampf(start.distance_to(target),absf(upper-lower)+0.001,upper+lower-0.001)
    var along := (upper*upper-lower*lower+distance*distance)/(2*distance)
    var bend := (pole-start-axis*(pole-start).dot(axis)).normalized()
    var joint := start+axis*along+bend*sqrt(maxf(0,upper*upper-along*along))
    aim_bone(a,b,joint)
    aim_bone(b,c,target)
func capture() -> Array[Transform3D]:
    var poses: Array[Transform3D] = []
    for i in avatar.rig.get_bone_count(): poses.append(avatar.rig.get_bone_pose(i))
    return poses
func apply(poses: Array[Transform3D]) -> void:
    for i in poses.size(): avatar.rig.set_bone_pose(i,poses[i])
    avatar.rig.force_update_all_bone_transforms()
func run() -> void:
    avatar = DuelAvatar.new()
    root.add_child(avatar)
    avatar.setup("general")
    avatar.play_clip("Sword_Idle",false,1,0)
    avatar.tick(0.01)
    var standing := capture()
    var hand_offset := avatar.bone_transform("hand.R").affine_inverse()*avatar.weapon_transform()
    var hips: int = avatar.target_bones.hips
    var hip_parent := avatar.rig.get_bone_parent(hips)
    var parent_frame := avatar.rig.global_transform * avatar.rig.get_bone_global_pose(hip_parent)
    var hip_pose := parent_frame.affine_inverse() * (position_of("hips")-Vector3.UP*0.29)
    avatar.rig.set_bone_pose_position(hips,hip_pose)
    avatar.rig.force_update_all_bone_transforms()
    solve_limb("thigh.L","shin.L","foot.L",Vector3(0.20,0.008,0.57),Vector3(0.22,0.6,1.1))
    solve_limb("thigh.R","shin.R","foot.R",Vector3(-0.18,0.085,-0.43),Vector3(-0.2,-0.4,0.38))
    # Bow the torso and helmet, keep the left hand braced over the raised knee.
    aim_bone("spine.001","spine.002",position_of("spine.002")+Vector3(0,-0.025,0.09))
    aim_bone("neck","head",position_of("head")+Vector3(0,-0.015,0.055))
    solve_limb("upper_arm.L","forearm.L","hand.L",Vector3(0.25,0.48,0.57),Vector3(0.65,0.65,0.15))
    solve_limb("upper_arm.R","forearm.R","hand.R",Vector3(-0.40,0.60,0.26),Vector3(-0.65,0.65,-0.10))
    var kneeling := capture()
    var info: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OUT+"animation-manifest.json"))
    var library: AnimationLibrary = avatar.animation.get_animation_library("")
    if library.has_animation(REMOVED): library.remove_animation(REMOVED)
    info.general.erase(REMOVED)
    var path: String = str(avatar.model.get_path_to(avatar.rig))
    for entry in [{"name":"Warden_Kneel_Enter","length":0.75},{"name":"Warden_Kneel_Hold","length":2.0},{"name":"Warden_Rise","length":1.25}]:
        var anim := Animation.new()
        anim.length = entry.length
        var rotations := []
        var positions := []
        for i in avatar.rig.get_bone_count():
            var rotation := anim.add_track(Animation.TYPE_ROTATION_3D)
            anim.track_set_path(rotation,NodePath(path+":"+avatar.rig.get_bone_name(i)))
            rotations.append(rotation)
            var position := anim.add_track(Animation.TYPE_POSITION_3D)
            anim.track_set_path(position,NodePath(path+":"+avatar.rig.get_bone_name(i)))
            positions.append(position)
        var gp := anim.add_track(Animation.TYPE_POSITION_3D)
        var gr := anim.add_track(Animation.TYPE_ROTATION_3D)
        anim.track_set_path(gp,NodePath("WeaponGrip"))
        anim.track_set_path(gr,NodePath("WeaponGrip"))
        var frames := ceili(anim.length*30)
        for frame in range(frames+1):
            var t := minf(frame/30.0,anim.length)
            var fraction := smoothstep(0.0,1.0,t/anim.length)
            var weight := fraction if entry.name == "Warden_Kneel_Enter" else (1.0-fraction if entry.name == "Warden_Rise" else 1.0)
            for i in avatar.rig.get_bone_count():
                avatar.rig.set_bone_pose(i,standing[i].interpolate_with(kneeling[i],weight))
                anim.rotation_track_insert_key(rotations[i],t,avatar.rig.get_bone_pose_rotation(i))
                anim.position_track_insert_key(positions[i],t,avatar.rig.get_bone_pose_position(i))
            avatar.rig.force_update_all_bone_transforms()
            var grip := avatar.model.global_transform.affine_inverse()*avatar.bone_transform("hand.R")*hand_offset
            # Plant the polearm butt near the ground as the general braces himself.
            var upright := Basis(Vector3.UP,-0.35)
            grip.basis = grip.basis.slerp(upright,weight)
            anim.position_track_insert_key(gp,t,grip.origin)
            anim.rotation_track_insert_key(gr,t,grip.basis.get_rotation_quaternion())
        if library.has_animation(entry.name): library.remove_animation(entry.name)
        library.add_animation(entry.name,anim)
        info.general[entry.name] = {"clip":entry.name,"length":anim.length,"frames":frames+1,"authored":"one-knee target-rig pose"}
    apply(standing)
    avatar.animation.stop()
    var scene := PackedScene.new()
    assert(scene.pack(avatar.model)==OK)
    assert(ResourceSaver.save(scene,OUT+"general_animated.scn")==OK)
    var doc := GLTFDocument.new()
    var state := GLTFState.new()
    assert(doc.append_from_scene(avatar.model,state)==OK)
    assert(doc.write_to_filesystem(state,ProjectSettings.globalize_path(OUT+"general_animated.glb"))==OK)
    var file := FileAccess.open(OUT+"animation-manifest.json",FileAccess.WRITE)
    file.store_string(JSON.stringify(info,"  ")+"\n")
    print("WARDEN_KNEEL_BAKED ",info.general.size())
    quit()
