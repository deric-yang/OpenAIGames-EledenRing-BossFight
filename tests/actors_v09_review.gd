extends SceneTree
var avatar: DuelAvatar
var weapon: HeldWeapon
var camera: Camera3D
func _initialize(): call_deferred("run")
func shot(name: String) -> void:
    await process_frame
    await process_frame
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://qa/iteration-v09/"+name+".png"))
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
    for clip in ["Sword_Idle","Sprint_Loop","Jog_Fwd_Loop","combat-master-e07664ecc25243ebbfdc","Roll","Death01"]:
        for phase in range(8):
            avatar.play_clip(clip,false,1,0)
            avatar.tick(float(avatar.manifest[clip].length)*float(phase)/8.0)
            weapon.tick(0)
            for side in [-1,1]:
                camera.projection = Camera3D.PROJECTION_ORTHOGONAL
                camera.size = 2.5
                camera.position=Vector3(1.1,1.3,2.0*side)
                camera.look_at(Vector3(0,0.9,0))
                await shot(clip+"-"+str(phase)+("-front" if side>0 else "-back"))
    avatar.visible = false
    weapon.visible = false
    var spear: Node3D = load("res://assets/runtime/characters/v04/general_polearm.glb").instantiate()
    world.add_child(spear)
    var flag: Node3D = load("res://assets/runtime/characters/v04/banner_cloth.glb").instantiate()
    spear.add_child(flag)
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.size = 3.1
    camera.position = Vector3(0,1.2,6)
    camera.look_at(Vector3(0,1.2,0))
    await shot("polearm-reference")
    for mesh in spear.find_children("*","MeshInstance3D",true,false):
        print("WEAPON_MESH ",mesh.name," bounds ",mesh.get_aabb()," skeleton ",mesh.skeleton)
        for surface in mesh.mesh.get_surface_count():
            var material = mesh.get_active_material(surface)
            print("MATERIAL ", material, " ", material.transparency if material is BaseMaterial3D else "shader")
    for ap in spear.find_children("*","AnimationPlayer",true,false):
        print("WEAPON_ANIM ",ap.get_animation_list()," active=",ap.active," autoplay=",ap.autoplay)
    quit()
