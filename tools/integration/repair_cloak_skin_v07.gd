extends SceneTree
## Rebind the complete cloak in evaluated rest space; preserve every triangle and UV.
func _initialize(): call_deferred("run")
func run():
    var original: Node3D = load("res://assets/runtime/characters/v04/knight.glb").instantiate()
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
    var cape: Array[int] = []
    for i in rig.get_bone_count():
        if rig.get_bone_name(i).begins_with("Cape_"): cape.append(i)
    var spine := rig.find_bone("mixamorig_Spine2")
    assert(spine>=0 and cape.size()==12)
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
                a[Mesh.ARRAY_VERTEX][v] = source.global_transform.affine_inverse()*(hand_world*hand_point)
            var weights := {}
            for j in 4:
                var bind: int = a[Mesh.ARRAY_BONES][v*4+j]
                var name: String = source.skin.get_bind_name(bind)
                var bone := rig.find_bone(name) if name!="" else source.skin.get_bind_bone(bind)
                if bone in cape: bone = spine
                weights[bone] = float(weights.get(bone,0))+float(a[Mesh.ARRAY_WEIGHTS][v*4+j])
            # The rear surface behind the calves is cloth, never the armor/hand silhouette.
            var amount := smoothstep(0.13,0.015,point.z)*smoothstep(1.54,1.35,point.y)*smoothstep(0.06,0.16,point.y)
            # Keep the calf/thigh armor weighted to its limb even where it lies behind the body.
            for side in ["Left","Right"]:
                for segment in [["UpLeg","Leg"],["Leg","Foot"],["Arm","ForeArm"],["ForeArm","Hand"]]:
                    var first := rig.find_bone("mixamorig_"+side+segment[0])
                    var last := rig.find_bone("mixamorig_"+side+segment[1])
                    var start: Vector3 = rig.global_transform*rig.get_bone_global_rest(first).origin
                    var end: Vector3 = rig.global_transform*rig.get_bone_global_rest(last).origin
                    var nearest := Geometry3D.get_closest_point_to_segment(point,start,end)
                    amount *= smoothstep(0.11,0.17,point.distance_to(nearest))
            if amount>0:
                changed += 1
                for key in weights: weights[key] *= 1-amount
                var row := clampf((1.43-point.y)/0.29,0,3)
                var col := clampf((point.x+0.25)/0.25,0,2)
                for c in 3:
                    for r in 4:
                        var bone := rig.find_bone("Cape_%d_%d"%[c,r])
                        var weight := maxf(0,1-absf(c-col))*maxf(0,1-absf(r-row))*amount
                        if weight>0: weights[bone] = float(weights.get(bone,0))+weight
            var keys := weights.keys()
            keys.sort_custom(func(x,y): return weights[x]>weights[y])
            var total := 0.0
            for j in mini(4,keys.size()): total += weights[keys[j]]
            for j in 4:
                a[Mesh.ARRAY_BONES][v*4+j] = keys[j] if j<keys.size() else 0
                a[Mesh.ARRAY_WEIGHTS][v*4+j] = weights[keys[j]]/total if j<keys.size() else 0
        mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,a)
        var mat: StandardMaterial3D = source.get_active_material(surface).duplicate()
        if mat.resource_name=="Knight_Charcoal_Cloth": mat.albedo_color=Color(0.24,0.255,0.28)
        mesh.surface_set_material(surface,mat)
    var file := "res://assets/runtime/characters/v04/knight_animated.scn"
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
    print("V07_CLOAK_REWEIGHTED ",changed," vertices; zero triangles removed")
    quit()
