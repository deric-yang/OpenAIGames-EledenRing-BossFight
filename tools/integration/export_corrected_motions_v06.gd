extends SceneTree
func _initialize(): call_deferred("run")
func run():
    var out := "res://assets/processed/animations_v06/"
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
    for role in ["knight","general"]:
        var avatar := DuelAvatar.new()
        root.add_child(avatar)
        avatar.setup(role)
        var ids := ["combat-master-e07664ecc25243ebbfdc"] if role=="knight" else ["combat-master-3c8d3a0c2bc89d15c58e","combat-master-577f7516d930b2ed0ead","combat-master-1409c47c83223aac5e53"]
        var replacements := {}
        for id in ids:
            avatar.play_clip(id,false,1,0)
            var anim := Animation.new()
            anim.length = float(avatar.manifest[id].length)
            var path := str(avatar.model.get_path_to(avatar.rig))
            var tracks := []
            for bone in avatar.rig.get_bone_count():
                var index := anim.add_track(Animation.TYPE_ROTATION_3D)
                anim.track_set_path(index,NodePath(path+":"+avatar.rig.get_bone_name(bone)))
                tracks.append(index)
            var hip := anim.add_track(Animation.TYPE_POSITION_3D)
            anim.track_set_path(hip,NodePath(path+":"+avatar.rig.get_bone_name(avatar.target_bones.hips)))
            var pos := anim.add_track(Animation.TYPE_POSITION_3D)
            var rot := anim.add_track(Animation.TYPE_ROTATION_3D)
            anim.track_set_path(pos,NodePath("WeaponGrip"))
            anim.track_set_path(rot,NodePath("WeaponGrip"))
            for frame in range(ceili(anim.length*30)+1):
                var t := minf(frame/30.0,anim.length-0.0001)
                avatar.elapsed=t
                avatar.tick(0)
                for bone in avatar.rig.get_bone_count():
                    anim.rotation_track_insert_key(tracks[bone],t,avatar.rig.get_bone_pose_rotation(bone))
                anim.position_track_insert_key(hip,t,avatar.rig.get_bone_pose_position(avatar.target_bones.hips))
                var grip := avatar.model.global_transform.affine_inverse()*avatar.weapon_transform()
                anim.position_track_insert_key(pos,t,grip.origin)
                anim.rotation_track_insert_key(rot,t,grip.basis.orthonormalized().get_rotation_quaternion())
            replacements[avatar.manifest[id].clip]=anim
        var library := avatar.animation.get_animation_library("")
        for name in replacements:
            library.remove_animation(name)
            library.add_animation(name,replacements[name])
        var allowed := []
        for value in avatar.manifest.values(): allowed.append(value.clip)
        for name in library.get_animation_list():
            if name not in allowed: library.remove_animation(name)
        avatar.animation.stop()
        avatar.rig.reset_bone_poses()
        var doc := GLTFDocument.new()
        var state := GLTFState.new()
        assert(doc.append_from_scene(avatar.model,state)==OK)
        assert(doc.write_to_filesystem(state,ProjectSettings.globalize_path(out+role+"_animated.glb"))==OK)
        print("V06_PORTABLE_ANIMATIONS ",role)
        avatar.free()
    quit()
