extends SceneTree
func _initialize(): call_deferred("run")
func run():
    var file := "res://assets/runtime/characters/v04/knight_animated.scn"
    var avatar := DuelAvatar.new()
    root.add_child(avatar)
    avatar.setup("knight")
    var model := avatar.model
    for old in model.find_children("Closed_Back_Armor","MeshInstance3D",true,false): old.free()
    var original: Node3D = load("res://assets/runtime/characters/v04/knight.glb").instantiate()
    root.add_child(original)
    var source_mesh: MeshInstance3D = original.find_children("*","MeshInstance3D",true,false)[0]
    await process_frame
    await process_frame
    var posed: ArrayMesh = source_mesh.bake_mesh_from_current_skeleton_pose()
    assert(posed != null,"Run this mesh tool with a rendering backend, not --headless")
    var removed := 0
    for node in model.find_children("*","MeshInstance3D",true,false):
        node.mesh = source_mesh.mesh
        var mesh := ArrayMesh.new()
        for surface in node.mesh.get_surface_count():
            var arrays: Array = node.mesh.surface_get_arrays(surface)
            var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
            var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
            var kept := PackedInt32Array()
            var cape: Array[bool] = []
            var pose_vertices: PackedVector3Array = posed.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
            for i in vertices.size():
                var point: Vector3 = source_mesh.global_transform * pose_vertices[i]
                cape.append(point.z < 0.025 and point.y>0.12 and point.y<1.3)
            for i in range(0,indices.size(),3):
                if cape[indices[i]] or cape[indices[i+1]] or cape[indices[i+2]]:
                    removed += 1
                else:
                    kept.append_array(indices.slice(i,i+3))
            if kept.is_empty(): continue
            arrays[Mesh.ARRAY_INDEX] = kept
            mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
            mesh.surface_set_material(mesh.get_surface_count()-1,node.get_active_material(surface))
        node.mesh = mesh
    add_underarmor(avatar,model.find_children("*","MeshInstance3D",true,false)[0])
    avatar.animation.stop()
    avatar.rig.reset_bone_poses()
    var scene := PackedScene.new()
    assert(scene.pack(model)==OK)
    assert(ResourceSaver.save(scene,file)==OK)
    var doc := GLTFDocument.new()
    var state := GLTFState.new()
    assert(doc.append_from_scene(model,state)==OK)
    assert(doc.write_to_filesystem(state,ProjectSettings.globalize_path(file.replace(".scn",".glb")))==OK)
    print("V06_REMAINING_CAPE_REMOVED ",removed)
    quit()

func add_underarmor(avatar: DuelAvatar, reference: MeshInstance3D) -> void:
    # The generated cape concealed unfinished rear surfaces. Supply a closed, skinned armor lining.
    avatar.play_clip("Sword_Idle",false,1,0)
    avatar.tick(0.1)
    var vertices := PackedVector3Array()
    var normals := PackedVector3Array()
    var indices := PackedInt32Array()
    var bones := PackedInt32Array()
    var weights := PackedFloat32Array()
    var parts := [["hips","spine.001",0.19,0.13],["spine.001","spine.002",0.21,0.135],
        ["spine.002","spine.003",0.22,0.14],["spine.003","neck",0.21,0.13]]
    for side in [".L",".R"]:
        parts.append(["thigh"+side,"shin"+side,0.085,0.09])
        parts.append(["shin"+side,"foot"+side,0.068,0.073])
    for part in parts:
        var bone: int = avatar.target_bones[part[0]]
        var bind := -1
        for i in reference.skin.get_bind_count():
            if reference.skin.get_bind_name(i)==avatar.rig.get_bone_name(bone) or reference.skin.get_bind_bone(i)==bone:
                bind=i
                break
        assert(bind>=0)
        var start: Vector3 = avatar.bone_transform(part[0]).origin
        var end: Vector3 = avatar.bone_transform(part[1]).origin
        var axis := (end-start).normalized()
        start -= axis*0.025
        end += axis*0.035
        var side := Vector3.RIGHT
        side = (side-axis*side.dot(axis)).normalized()
        var back := axis.cross(side).normalized()
        var transform := avatar.rig.global_transform*avatar.rig.get_bone_global_pose(bone)*reference.skin.get_bind_pose(bind)
        var inverse := transform.affine_inverse()
        var offset := vertices.size()
        for ring in 5:
            var t := float(ring)/4
            var center := start.lerp(end,t)
            var width := 0.96 if ring%2==0 else 1.02
            for segment in 10:
                var angle := float(segment)/10*TAU
                var normal := (side*cos(angle)+back*sin(angle)).normalized()
                var point := center+side*cos(angle)*float(part[2])*width+back*sin(angle)*float(part[3])*width
                vertices.append(inverse*point)
                normals.append((transform.basis.transposed()*normal).normalized())
                bones.append_array(PackedInt32Array([bind,0,0,0]))
                weights.append_array(PackedFloat32Array([1,0,0,0]))
        for ring in 4:
            for segment in 10:
                var a := offset+ring*10+segment
                var b := offset+ring*10+(segment+1)%10
                indices.append_array(PackedInt32Array([a,b,b+10,a,b+10,a+10]))
    var arrays := []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX]=vertices
    arrays[Mesh.ARRAY_NORMAL]=normals
    arrays[Mesh.ARRAY_INDEX]=indices
    arrays[Mesh.ARRAY_BONES]=bones
    arrays[Mesh.ARRAY_WEIGHTS]=weights
    var mesh := ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
    var material := StandardMaterial3D.new()
    material.resource_name="Silver_Gray_Underarmor"
    material.albedo_color=Color(0.19,0.20,0.215)
    material.metallic=0.65
    material.roughness=0.62
    material.cull_mode=BaseMaterial3D.CULL_DISABLED
    mesh.surface_set_material(0,material)
    var node := MeshInstance3D.new()
    node.name="Closed_Back_Armor"
    node.mesh=mesh
    node.skin=reference.skin
    node.skeleton=reference.skeleton
    node.transform=reference.transform
    reference.get_parent().add_child(node)
    node.owner=avatar.model
