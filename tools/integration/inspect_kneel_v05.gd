extends SceneTree
func _initialize(): call_deferred("run")
func run():
    var a = DuelAvatar.new()
    root.add_child(a)
    a.setup("general")
    for clip in ["Sword_Idle","Warden_Kneel_Hold"]:
        a.play_clip(clip,false,1,0)
        a.tick(0.016)
        print(clip)
        for key in ["hips","thigh.R","shin.R","foot.R","thigh.L","shin.L","foot.L","head"]:
            print(key, " ", a.bone_transform(key).origin)
    quit()
