extends SceneTree
## Bake verified semantic retargeting into portable animated character scenes and GLBs.
const OUT = "res://assets/runtime/characters/v09/"
const Avatar = preload("res://scripts/animation/duel_avatar.gd")
var report := {}
func _initialize() -> void:
    call_deferred("run")
func own_nodes(node: Node, owner_node: Node) -> void:
    for child in node.get_children():
        child.owner = owner_node
        own_nodes(child, owner_node)
func run() -> void:
    var selected: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/runtime/motions/v04/selected-motions.json"))
    for role in ["knight"]:
        var avatar = Avatar.new()
        root.add_child(avatar)
        avatar.setup(role, true)
        var clips: Array = []
        if role == "general":
            for row in selected:
                if row.role == "boss": clips.append(row.id)
            clips.append("Sword_Idle")
        else:
            for clip in avatar.manifest:
                if not str(clip).begins_with("combat-master-"): clips.append(clip)
            clips.append("combat-master-e07664ecc25243ebbfdc")
        var library := AnimationLibrary.new()
        var skeleton_path: String = str(avatar.model.get_path_to(avatar.rig))
        var marker := Node3D.new()
        marker.name = "WeaponGrip"
        avatar.model.add_child(marker)
        var info := {}
        for clip in clips:
            avatar.play_clip(clip, false, 1.0, 0.0)
            var duration: float = avatar.manifest[clip].length
            var anim := Animation.new()
            anim.length = duration
            var tracks := []
            for bone in avatar.rig.get_bone_count():
                var track := anim.add_track(Animation.TYPE_ROTATION_3D)
                anim.track_set_path(track, NodePath(skeleton_path + ":" + avatar.rig.get_bone_name(bone)))
                tracks.append(track)
            var hips: int = avatar.target_bones.hips
            var position_track := anim.add_track(Animation.TYPE_POSITION_3D)
            anim.track_set_path(position_track, NodePath(skeleton_path + ":" + avatar.rig.get_bone_name(hips)))
            var grip_position := anim.add_track(Animation.TYPE_POSITION_3D)
            var grip_rotation := anim.add_track(Animation.TYPE_ROTATION_3D)
            anim.track_set_path(grip_position, NodePath("WeaponGrip"))
            anim.track_set_path(grip_rotation, NodePath("WeaponGrip"))
            var frames := ceili(duration * 30.0)
            for frame in range(frames + 1):
                var time := minf(frame / 30.0, duration - 0.0001)
                avatar.elapsed = time
                avatar.animation.seek(time, true)
                avatar.update_pose()
                for bone in avatar.rig.get_bone_count():
                    anim.rotation_track_insert_key(tracks[bone], time, avatar.rig.get_bone_pose_rotation(bone))
                anim.position_track_insert_key(position_track, time, avatar.rig.get_bone_pose_position(hips))
                var grip: Transform3D = avatar.model.global_transform.affine_inverse() * avatar.weapon_transform()
                anim.position_track_insert_key(grip_position, time, grip.origin)
                anim.rotation_track_insert_key(grip_rotation, time, grip.basis.orthonormalized().get_rotation_quaternion())
            var name: String = str(clip).replace("/", "__")
            library.add_animation(name, anim)
            info[clip] = {"clip":name, "length":duration, "frames":frames + 1}
            print("BAKED ", role, " ", name, " ", frames + 1)
        avatar.rig.reset_bone_poses()
        var player := AnimationPlayer.new()
        player.name = "CharacterAnimations"
        avatar.model.add_child(player)
        player.add_animation_library("", library)
        var model: Node3D = avatar.model
        model.reparent(root)
        own_nodes(model, model)
        var scene := PackedScene.new()
        assert(scene.pack(model) == OK)
        assert(ResourceSaver.save(scene, OUT + role + "_animated.scn") == OK)
        var state := GLTFState.new()
        var doc := GLTFDocument.new()
        assert(doc.append_from_scene(model, state) == OK)
        assert(doc.write_to_filesystem(state, ProjectSettings.globalize_path(OUT + role + "_animated.glb")) == OK)
        report[role] = info
        model.free()
        avatar.free()
    var file := FileAccess.open(OUT + "animation-manifest.json", FileAccess.WRITE)
    file.store_string(JSON.stringify(report, "  ") + "\n")
    print("ANIMATED_CHARACTERS_BAKED")
    quit()
