extends SceneTree
func _initialize(): call_deferred("run")
func run():
    var avatar := DuelAvatar.new()
    root.add_child(avatar)
    avatar.setup("knight")
    avatar.rig.reset_bone_poses()
    await process_frame
    await process_frame
    var data := {}
    for node in avatar.model.find_children("*","MeshInstance3D",true,false):
        var posed: ArrayMesh = node.bake_mesh_from_current_skeleton_pose()
        for surface in node.mesh.get_surface_count():
            var a: Array = node.mesh.surface_get_arrays(surface)
            var vertices = posed.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
            for v in vertices.size():
                for j in 4:
                    var weight: float = a[Mesh.ARRAY_WEIGHTS][v*4+j]
                    if weight<0.4: continue
                    var bind: int = a[Mesh.ARRAY_BONES][v*4+j]
                    var name: String = node.skin.get_bind_name(bind)
                    if name=="": name = avatar.rig.get_bone_name(node.skin.get_bind_bone(bind))
                    if not data.has(name): data[name]=[]
                    var p: Vector3 = node.global_transform*vertices[v]
                    data[name].append([p.x,p.y,p.z])
    for key in ["hand.R","forearm.R","hand.L","spine.003"]:
        print(key," ",avatar.bone_transform(key))
    var file := FileAccess.open("res://qa/iteration-v07/skin-points.json",FileAccess.WRITE)
    file.store_string(JSON.stringify(data))
    quit()
