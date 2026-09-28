extends SceneTree
func _initialize(): call_deferred("run")
func run():
    var a = DuelAvatar.new()
    root.add_child(a)
    a.setup("general")
    a.play_clip("Sword_Idle",false,1,0)
    a.tick(0.016)
    for key in a.target_bones:
        print(key, " ", a.model.global_transform.affine_inverse()*a.bone_transform(key).origin)
    quit()
