extends SceneTree
func _initialize(): call_deferred("run")
func run():
    var a = DuelAvatar.new()
    root.add_child(a)
    a.setup("knight")
    a.play_clip("combat-master-e07664ecc25243ebbfdc",false,1,0)
    for fraction in [0.1,0.2,0.3,0.4,0.48,0.55,0.6,0.65,0.7,0.8,0.9]:
        a.elapsed=float(a.manifest[a.current].length)*fraction
        a.tick(0)
        print(fraction," tip=",a.weapon_transform()*Vector3(0,1.2,0)," hand=",a.bone_transform("hand.R").origin)
    quit()
