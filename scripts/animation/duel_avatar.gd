class_name DuelAvatar
extends Node3D
## Semantic reference-pose retargeting with independent driver skeletons and skin lengths.
var rig: Skeleton3D
var model: Node3D
var driver: Node3D
var source: Skeleton3D
var animation: AnimationPlayer
var drivers := {}
var manifest: Dictionary
var links: Array[Dictionary] = []
var target_bones := {}
var current := ""
var elapsed := 0.0
var looping := false
var playing := true
var speed := 1.0
var hip_ratio := 1.0
var source_frame := Transform3D.IDENTITY
var target_frame := Transform3D.IDENTITY
var blend_from: Array[Transform3D] = []
var blend_left := 0.0
var baked := false
var grip_marker: Node3D
var cape_bones: Array[int] = []
var cape_clock := 0.0
var actor_role := ""
var corrected_grip := Transform3D.IDENTITY
var uses_corrected_grip := false
var last_world_position := Vector3.ZERO
var cloak_drag := 0.0
var palm_socket := Transform3D.IDENTITY
var cloak_velocity := 0.0
var general_socket := Transform3D.IDENTITY

static func semantic(raw: String) -> String:
    var name := raw.replace("mixamorig:", "").replace("mixamorig_", "")
    if name.begins_with("DEF-"): return name.substr(4)
    var core := {"Hips":"hips", "pelvis":"hips", "Spine":"spine.001", "Spine1":"spine.002",
        "Spine2":"spine.003", "spine_01":"spine.001", "spine_02":"spine.002", "spine_03":"spine.003",
        "Neck":"neck", "neck_01":"neck", "Head":"head", "head":"head"}
    if core.has(name): return core[name]
    var limbs := {"Shoulder":"shoulder", "Arm":"upper_arm", "ForeArm":"forearm", "Hand":"hand",
        "UpLeg":"thigh", "Leg":"shin", "Foot":"foot", "ToeBase":"toe",
        "clavicle":"shoulder", "upperarm":"upper_arm", "lowerarm":"forearm", "hand":"hand",
        "thigh":"thigh", "calf":"shin", "foot":"foot", "ball":"toe"}
    for side in ["Left", "Right"]:
        if name.begins_with(side):
            var stem := name.substr(side.length())
            if limbs.has(stem): return limbs[stem] + (".L" if side == "Left" else ".R")
    for suffix in ["_l", "_r"]:
        if name.ends_with(suffix):
            var stem := name.trim_suffix(suffix)
            if limbs.has(stem): return limbs[stem] + (".L" if suffix == "_l" else ".R")
    return ""

func setup(role: String, force_source: bool = false) -> void:
    actor_role = role
    var base := "res://assets/runtime/characters/v09/" if role == "knight" else "res://assets/runtime/characters/v04/"
    baked = not force_source and ResourceLoader.exists(base + role + "_animated.scn")
    if baked:
        manifest = JSON.parse_string(FileAccess.get_file_as_string(base + "animation-manifest.json"))[role]
        model = load(base + role + "_animated.scn").instantiate()
    else:
        manifest = JSON.parse_string(FileAccess.get_file_as_string("res://assets/runtime/motions/v04/manifest.json"))
        model = load(base + role + ".glb").instantiate()
    add_child(model)
    rig = model.find_children("*", "Skeleton3D", true, false)[0]
    for i in rig.get_bone_count():
        var key := semantic(rig.get_bone_name(i))
        if key != "": target_bones[key] = i
        if rig.get_bone_name(i).begins_with("Cape_"): cape_bones.append(i)
    if baked:
        animation = model.find_children("*", "AnimationPlayer", true, false)[0]
        animation.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
        grip_marker = model.get_node("WeaponGrip")
        animation.play(manifest["Sword_Idle"].clip)
        animation.seek(0.2,true)
        rig.force_update_all_bone_transforms()
        palm_socket = bone_transform("hand.R").affine_inverse()*grip_marker.global_transform
        general_socket = palm_socket
        if role == "knight":
            palm_socket = Transform3D(Basis(Vector3.BACK,Vector3.RIGHT,Vector3.UP),Vector3(0,0.095,0.025))

func play_clip(clip: String, loop: bool = false, playback: float = 1.0, blend: float = 0.14) -> void:
    if not manifest.has(clip):
        push_error("Unknown motion: " + clip)
        return
    blend_from.clear()
    for i in rig.get_bone_count(): blend_from.append(rig.get_bone_pose(i))
    blend_left = blend
    current = clip
    elapsed = 0.0
    looping = loop
    speed = playback
    if baked:
        animation.play(manifest[clip].clip)
        animation.seek(0.0, true)
        return
    var file: String = manifest[clip].driver
    if not drivers.has(file):
        var node: Node3D = load(file).instantiate()
        add_child(node)
        drivers[file] = node
        var ap: AnimationPlayer = node.find_children("*", "AnimationPlayer", true, false)[0]
        ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
        ap.active = true
    if driver != drivers[file]:
        driver = drivers[file]
        source = driver.find_children("*", "Skeleton3D", true, false)[0]
        animation = driver.find_children("*", "AnimationPlayer", true, false)[0]
        source.reset_bone_poses()
        build_links()
    animation.play(clip)
    animation.seek(0.0, true)
    update_pose()

func build_links() -> void:
    links.clear()
    var source_bones := {}
    for i in source.get_bone_count():
        var key := semantic(source.get_bone_name(i))
        if key != "": source_bones[key] = i
    source_frame = global_transform.affine_inverse() * source.global_transform
    target_frame = global_transform.affine_inverse() * rig.global_transform
    for i in rig.get_bone_count():
        var key := semantic(rig.get_bone_name(i))
        if not source_bones.has(key): continue
        var align := Basis.IDENTITY
        var next := ""
        for side in [".L", ".R"]:
            var chain := {"upper_arm":"forearm", "forearm":"hand", "thigh":"shin", "shin":"foot", "foot":"toe"}
            for stem in chain:
                if key == stem + side: next = chain[stem] + side
        if next != "" and target_bones.has(next) and source_bones.has(next):
            var a := target_frame.basis * (rig.get_bone_global_rest(target_bones[next]).origin - rig.get_bone_global_rest(i).origin)
            var b := source_frame.basis * (source.get_bone_global_rest(source_bones[next]).origin - source.get_bone_global_rest(source_bones[key]).origin)
            if a.length() > 0.001 and b.length() > 0.001: align = Basis(Quaternion(a.normalized(), b.normalized()))
        links.append({"target":i, "source":source_bones[key], "semantic":key, "align":align})
    for side in [".L", ".R"]:
        var forearm := Basis.IDENTITY
        for link in links:
            if link.semantic == "forearm" + side: forearm = link.align
        for link in links:
            if link.semantic == "hand" + side: link.align = forearm
    if source_bones.has("hips") and source_bones.has("foot.L"):
        var a := target_frame * rig.get_bone_global_rest(target_bones["hips"]).origin
        var b := target_frame * rig.get_bone_global_rest(target_bones["foot.L"]).origin
        var c := source_frame * source.get_bone_global_rest(source_bones["hips"]).origin
        var d := source_frame * source.get_bone_global_rest(source_bones["foot.L"]).origin
        hip_ratio = a.distance_to(b) / maxf(c.distance_to(d), 0.001)

func tick(delta: float) -> void:
    if current == "" or not playing: return
    elapsed += delta * speed
    var duration: float = manifest[current].length
    var sample_time := fmod(elapsed, duration) if looping else minf(elapsed, duration - 0.001)
    if current == "combat-master-1409c47c83223aac5e53":
        var phase := sample_time / duration
        sample_time = duration * (phase * 0.55 if phase < 0.6 else 0.33 + (phase-0.6)*1.675)
    animation.seek(sample_time, true)
    update_pose()
    if baked and actor_role == "general":
        rig.force_update_all_bone_transforms()
        # Sample authored grip in HAND space before pose correction. Blend it with the
        # same weight as the skeleton, then attach to the final hand after the blend.
        var socket := bone_transform("hand.R").affine_inverse()*grip_marker.global_transform
        general_socket = general_socket.interpolate_with(socket,minf(1.0,delta/maxf(blend_left,0.001))) if blend_left>0 else socket
    apply_motion_corrections()
    if blend_left > 0.0:
        var weight := minf(1.0, delta / maxf(blend_left, 0.001))
        for i in rig.get_bone_count():
            var pose := blend_from[i].interpolate_with(rig.get_bone_pose(i), weight)
            rig.set_bone_pose(i, pose)
            blend_from[i] = pose
        blend_left = maxf(0.0, blend_left - delta)
    rig.force_update_all_bone_transforms()
    if actor_role == "knight" and current in ["Sprint_Loop","Jog_Fwd_Loop"]:
        # Keep the anatomical hand socket; turn the wrist with the blade outside the torso.
        var hand: int = target_bones["hand.R"]
        var axis := (global_basis*Vector3(-0.25,-0.28,1.0)).normalized()
        var side := global_basis.x.normalized()
        side = (side-axis*side.dot(axis)).normalized()
        var desired := Basis(side,axis,side.cross(axis))*palm_socket.basis.inverse()
        var parent := rig.get_bone_parent(hand)
        var local := rig.get_bone_global_pose(parent).basis.inverse()*rig.global_basis.inverse()*desired
        rig.set_bone_pose_rotation(hand,local.orthonormalized().get_rotation_quaternion())
        rig.force_update_all_bone_transforms()
    if baked:
        cape_clock += delta
        var movement := global_position.distance_to(last_world_position) / maxf(delta,0.001) if last_world_position != Vector3.ZERO else 0.0
        # Critically damped, small secondary motion; shoulders stay pinned.
        var target_drag := minf(movement,8.0)*0.006
        cloak_velocity += ((target_drag-cloak_drag)*36.0-cloak_velocity*12.0)*minf(delta,0.033)
        cloak_drag = clampf(cloak_drag+cloak_velocity*minf(delta,0.033),-0.025,0.055)
        last_world_position = global_position
        for bone in cape_bones:
            var parts := rig.get_bone_name(bone).split("_")
            var column := int(parts[1])
            var row := int(parts[2])
            var weight := pow(float(row)/3.0,2)
            var sway := sin(cape_clock*1.7-row*0.45+column*0.25)*0.008*weight
            var rest := rig.get_bone_global_rest(bone)
            var chest := target_bones["spine.003"] as int
            var rig_to_model := model.global_transform.affine_inverse()*rig.global_transform
            var chest_rest := rig_to_model*rig.get_bone_global_rest(chest)
            var chest_pose := rig_to_model*rig.get_bone_global_pose(chest)
            var turn := atan2(-chest_pose.basis.x.z,chest_pose.basis.x.x)-atan2(-chest_rest.basis.x.z,chest_rest.basis.x.x)
            var heading := Basis(Vector3.UP,turn)
            var rest_model := rig_to_model*rest
            var offset := Vector3(sway*0.4,0,-(cloak_drag*weight+sway))
            var desired := Transform3D(heading*rest_model.basis,chest_pose.origin+heading*(rest_model.origin-chest_rest.origin+offset))
            desired = rig_to_model.affine_inverse()*desired
            var parent := rig.get_bone_parent(bone)
            var local := rig.get_bone_global_pose(parent).affine_inverse()*desired
            rig.set_bone_pose(bone,local)
            rig.force_update_all_bone_transforms()
        rig.force_update_all_bone_transforms()

func update_pose() -> void:
    if baked: return
    for link in links:
        var i: int = link.target
        var s: int = link.source
        var source_rest := (source_frame.basis * source.get_bone_global_rest(s).basis).orthonormalized()
        var source_pose := (source_frame.basis * source.get_bone_global_pose(s).basis).orthonormalized()
        var target_rest := (target_frame.basis * rig.get_bone_global_rest(i).basis).orthonormalized()
        var desired: Basis = source_pose * source_rest.inverse() * link.align * target_rest
        desired = target_frame.basis.orthonormalized().inverse() * desired
        var parent := rig.get_bone_parent(i)
        var parent_basis := rig.get_bone_global_pose(parent).basis.orthonormalized() if parent >= 0 else Basis.IDENTITY
        rig.set_bone_pose_rotation(i, (parent_basis.inverse() * desired).orthonormalized().get_rotation_quaternion())
        if link.semantic == "hips":
            var offset := source_frame.basis * (source.get_bone_global_pose(s).origin - source.get_bone_global_rest(s).origin) * hip_ratio
            offset.x = 0.0
            offset.z = 0.0
            var position := rig.get_bone_global_rest(i).origin + target_frame.basis.inverse() * offset
            var parent_transform := rig.get_bone_global_pose(parent) if parent >= 0 else Transform3D.IDENTITY
            rig.set_bone_pose_position(i, parent_transform.affine_inverse() * position)
        rig.force_update_all_bone_transforms()

func finished() -> bool:
    return current != "" and not looping and elapsed >= float(manifest[current].length)

func bone_transform(key: String) -> Transform3D:
    return rig.global_transform * rig.get_bone_global_pose(target_bones[key])

func weapon_transform() -> Transform3D:
    if baked:
        if actor_role == "general":
            return bone_transform("hand.R")*general_socket
        # Never replay an independent world-space marker through an animation blend.
        # One calibrated socket remains rigidly attached to the final right-hand pose.
        return bone_transform("hand.R") * palm_socket
    var right := bone_transform("hand.R")
    var index := source.find_bone("index_01_r")
    var pinky := source.find_bone("pinky_01_r")
    var wrist := source.find_bone("hand_r")
    if index < 0:
        index = source.find_bone("DEF-f_index.01.R")
        pinky = source.find_bone("DEF-f_pinky.01.R")
        wrist = source.find_bone("DEF-hand.R")
    if index < 0 or pinky < 0 or wrist < 0: return right
    var a := source.global_transform * source.get_bone_global_pose(index).origin
    var b := source.global_transform * source.get_bone_global_pose(pinky).origin
    var c := source.global_transform * source.get_bone_global_pose(wrist).origin
    var axis := (a - b).normalized()
    var palm := (a.lerp(b, 0.5) - c).normalized()
    var side := palm.cross(axis).normalized()
    var scale_factor := global_basis.get_scale().x
    var basis := Basis(side, axis, side.cross(axis)).orthonormalized().scaled(Vector3.ONE * scale_factor)
    return Transform3D(basis, right.origin + palm * 0.055 * scale_factor)

func apply_motion_corrections() -> void:
    uses_corrected_grip = false
    if not baked: return
    var mirror := current == "combat-master-e07664ecc25243ebbfdc" or current == "combat-master-3c8d3a0c2bc89d15c58e"
    var straighten := actor_role == "general" and current == "combat-master-577f7516d930b2ed0ead"
    if not mirror and not straighten: return
    corrected_grip = bone_transform("hand.R").affine_inverse() * grip_marker.global_transform
    uses_corrected_grip = true
    var frame := model.global_transform.affine_inverse() * rig.global_transform
    var reflection := Basis.from_scale(Vector3(-1,1,1))
    var poses := {}
    for key in target_bones:
        poses[key] = frame * rig.get_bone_global_pose(target_bones[key])
    # Mirror global motion deltas, exchanging anatomical sides while preserving target rest axes.
    for i in rig.get_bone_count():
        var key := semantic(rig.get_bone_name(i))
        if key == "": continue
        var opposite := key
        if key.ends_with(".L"): opposite = key.trim_suffix(".L") + ".R"
        elif key.ends_with(".R"): opposite = key.trim_suffix(".R") + ".L"
        var desired: Basis = poses[key].basis
        if mirror and poses.has(opposite):
            var rest_other := frame * rig.get_bone_global_rest(target_bones[opposite])
            var rest_self := frame * rig.get_bone_global_rest(i)
            desired = reflection * poses[opposite].basis * rest_other.basis.inverse() * reflection * rest_self.basis
        elif straighten and key in ["spine.001","spine.002","spine.003","neck","head","shoulder.L","shoulder.R","upper_arm.L","upper_arm.R","forearm.L","forearm.R","hand.L","hand.R"]:
            desired = Basis(Vector3.RIGHT,deg_to_rad(-17)) * desired
        desired = frame.basis.inverse() * desired
        var parent := rig.get_bone_parent(i)
        var parent_basis := rig.get_bone_global_pose(parent).basis if parent >= 0 else Basis.IDENTITY
        rig.set_bone_pose_rotation(i,(parent_basis.inverse()*desired).orthonormalized().get_rotation_quaternion())
        rig.force_update_all_bone_transforms()

    if actor_role == "knight" and current == "combat-master-e07664ecc25243ebbfdc":
        # Orient the hand and its rigid socket together, never point the sword independently.
        var hand := target_bones["hand.R"] as int
        var wrist := bone_transform("hand.R")
        var axis := (wrist.origin-bone_transform("forearm.R").origin).normalized()
        var side := wrist.basis.z.normalized()
        side = (side-axis*side.dot(axis)).normalized()
        var desired := Basis(side,axis,side.cross(axis))*palm_socket.basis.inverse()
        var local_basis := rig.global_basis.inverse()*desired
        var parent := rig.get_bone_parent(hand)
        local_basis = rig.get_bone_global_pose(parent).basis.inverse()*local_basis
        rig.set_bone_pose_rotation(hand,local_basis.orthonormalized().get_rotation_quaternion())
        rig.force_update_all_bone_transforms()
