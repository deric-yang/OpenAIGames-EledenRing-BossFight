extends SceneTree
func _initialize(): call_deferred("run")
func run():
    var avatar := DuelAvatar.new()
    root.add_child(avatar)
    avatar.setup("knight")
    avatar.play_clip("combat-master-e07664ecc25243ebbfdc",false,1,0)
    var length: float = avatar.manifest[avatar.current].length
    for i in 11:
        avatar.elapsed = length*i/10.0
        avatar.tick(0)
        var right := avatar.bone_transform("hand.R").origin
        var left := avatar.bone_transform("hand.L").origin
        var tip := avatar.weapon_transform()*Vector3(0,1.2,0)
        print("THRUST ",i/10.0," R ",right," L ",left," TIP ",tip)
    quit()
