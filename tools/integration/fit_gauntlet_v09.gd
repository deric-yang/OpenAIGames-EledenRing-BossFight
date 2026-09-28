extends SceneTree
## Close the generated gauntlet around the calibrated grip; preserve all UVs and triangles.
func _initialize(): call_deferred("run")
func run():
    var original: Node3D = load("res://assets/runtime/characters/v09/knight.glb").instantiate()
    root.add_child(original)
    var source: MeshInstance3D = original.find_children("*","MeshInstance3D",true,false)[0]
    var rig: Skeleton3D = original.find_children("*","Skeleton3D",true,false)[0]
    rig.reset_bone_poses()
    await process_frame
    await process_frame
    var posed: ArrayMesh = source.bake_mesh_from_current_skeleton_pose()
    assert(posed!=null,"Requires native renderer")
    var skin := Skin.new()
    var mesh := ArrayMesh.new()
    for i in rig.get_bone_count():
        skin.add_named_bind(rig.get_bone_name(i),(rig.global_transform*rig.get_bone_global_rest(i)).affine_inverse()*source.global_transform)
    var changed := 0
    for surface in source.mesh.get_surface_count():
        var a: Array = source.mesh.surface_get_arrays(surface)
        var baked: Array = posed.surface_get_arrays(surface)
        a[Mesh.ARRAY_VERTEX] = baked[Mesh.ARRAY_VERTEX]
        a[Mesh.ARRAY_NORMAL] = baked[Mesh.ARRAY_NORMAL]
        a[Mesh.ARRAY_TANGENT] = null
        var vertices: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
        for v in vertices.size():
            var point: Vector3 = source.global_transform*vertices[v]
            var hand := rig.find_bone("mixamorig_RightHand")
            var hand_world := rig.global_transform*rig.get_bone_global_rest(hand)
            var hand_point := hand_world.affine_inverse()*point
            if hand_point.y>0.072 and hand_point.y<0.20 and absf(hand_point.x)<0.065 and absf(hand_point.z)<0.065:
                # This generated rig has no finger bones: close the four fingers in the bind mesh.
                var angle := clampf((hand_point.y-0.072)/0.075*2.5,0,2.5)
                hand_point.y = 0.072+sin(angle)*0.032
                hand_point.z += (1-cos(angle))*0.032
                changed += 1
                a[Mesh.ARRAY_VERTEX][v] = source.global_transform.affine_inverse()*(hand_world*hand_point)
            var weights := {}
            for j in 4:
                var bind: int = a[Mesh.ARRAY_BONES][v*4+j]
                var name: String = source.skin.get_bind_name(bind)
                var bone := rig.find_bone(name) if name!="" else source.skin.get_bind_bone(bind)
                weights[bone] = float(weights.get(bone,0))+float(a[Mesh.ARRAY_WEIGHTS][v*4+j])
            var keys := weights.keys()
            keys.sort_custom(func(x,y): return weights[x]>weights[y])
            var total := 0.0
            for j in mini(4,keys.size()): total += weights[keys[j]]
            for j in 4:
                a[Mesh.ARRAY_BONES][v*4+j] = keys[j] if j<keys.size() else 0
                a[Mesh.ARRAY_WEIGHTS][v*4+j] = weights[keys[j]]/total if j<keys.size() else 0
        mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,a)
        var mat: StandardMaterial3D = source.get_active_material(surface).duplicate()
        mesh.surface_set_material(surface,mat)
    var file := "res://assets/runtime/characters/v09/knight_animated.scn"
    var model: Node3D = load(file).instantiate()
    root.add_child(model)
    for node in model.find_children("*","MeshInstance3D",true,false):
        node.mesh=mesh
        node.skin=skin
    var packed := PackedScene.new()
    assert(packed.pack(model)==OK)
    assert(ResourceSaver.save(packed,file)==OK)
    var doc := GLTFDocument.new()
    var state := GLTFState.new()
    assert(doc.append_from_scene(model,state)==OK)
    assert(doc.write_to_filesystem(state,ProjectSettings.globalize_path(file.replace(".scn",".glb")))==OK)
    print("V09_GAUNTLET_CURLED ",changed," vertices; zero triangles removed")
    quit()
