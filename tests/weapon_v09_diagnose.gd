extends SceneTree
func _initialize(): call_deferred("run")
func run():
    var avatar := DuelAvatar.new()
    root.add_child(avatar)
    avatar.setup("general")
    avatar.scale = Vector3.ONE*4.324325
    var rows: Array = []
    for clip in avatar.manifest:
        avatar.play_clip("Sword_Idle",true,1,0)
        avatar.tick(0.3)
        var previous := avatar.weapon_transform()
        avatar.play_clip(clip,false)
        var maximum := 0.0
        var wrist_gap := 0.0
        var maximum_angle := 0.0
        for frame in 12:
            avatar.tick(1.0/60)
            var weapon := avatar.weapon_transform()
            maximum = maxf(maximum,weapon.origin.distance_to(previous.origin))
            wrist_gap = maxf(wrist_gap,weapon.origin.distance_to(avatar.bone_transform("hand.R").origin))
            maximum_angle = maxf(maximum_angle,weapon.basis.orthonormalized().get_rotation_quaternion().angle_to(previous.basis.orthonormalized().get_rotation_quaternion()))
            previous = weapon
        rows.append({"clip":clip,"max_frame_jump":maximum,"wrist_gap":wrist_gap,"max_angle_deg":rad_to_deg(maximum_angle)})
    var suffix := "after" if OS.get_cmdline_user_args().has("--after") else "before"
    FileAccess.open("res://qa/iteration-v09/weapon-"+suffix+".json",FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
    print("WEAPON_DIAGNOSED ",suffix)
    quit()
