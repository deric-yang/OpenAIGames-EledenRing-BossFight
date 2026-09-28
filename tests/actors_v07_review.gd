extends SceneTree
var avatar: DuelAvatar
var weapon: HeldWeapon
var camera: Camera3D
func _initialize(): call_deferred("run")
func shot(name: String) -> void:
    await process_frame
    await process_frame
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://qa/iteration-v07/"+name+".png"))
func run():
    root.size = Vector2i(1200,900)
    var world := Node3D.new()
    root.add_child(world)
    var env := WorldEnvironment.new()
    env.environment = Environment.new()
    env.environment.background_mode = Environment.BG_COLOR
    env.environment.background_color = Color(0.12,0.14,0.17)
    env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.environment.ambient_light_color = Color.WHITE
    env.environment.ambient_light_energy = 0.6
    world.add_child(env)
    var light := DirectionalLight3D.new()
    light.rotation_degrees = Vector3(-45,-30,0)
    light.light_energy = 2
    world.add_child(light)
    camera = Camera3D.new()
    world.add_child(camera)
    avatar = DuelAvatar.new()
    world.add_child(avatar)
    avatar.setup("knight")
    weapon = HeldWeapon.new()
    world.add_child(weapon)
    weapon.setup(avatar,"knight")
    for clip in ["Sword_Idle","ual2/Sword_Regular_A","combat-master-e07664ecc25243ebbfdc","Sprint_Loop"]:
        avatar.play_clip(clip,false,1,0)
        avatar.tick(float(avatar.manifest[clip].length)*0.4)
        weapon.tick(0)
        camera.position = Vector3(1.6,1.2,1.8)
        camera.look_at(Vector3(0,0.9,0))
        await shot(clip.replace("/","_")+"-front")
        camera.position = Vector3(-1.5,1.2,-1.8)
        camera.look_at(Vector3(0,0.9,0))
        await shot(clip.replace("/","_")+"-back")
        var palm := avatar.bone_transform("hand.R").origin
        camera.position = palm+Vector3(-0.48,0.22,-0.5)
        camera.look_at(palm)
        await shot(clip.replace("/","_")+"-grip")
    print("SOCKET ",avatar.palm_socket)
    quit()
