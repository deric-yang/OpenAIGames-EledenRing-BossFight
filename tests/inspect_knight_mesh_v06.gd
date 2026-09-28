extends SceneTree
func _initialize(): call_deferred("run")
func run():
    var model = load("res://assets/runtime/characters/v04/knight_animated.scn").instantiate()
    root.add_child(model)
    for node in model.find_children("*","MeshInstance3D",true,false):
        print("MESH ",node.name," ",node.global_transform," ",node.get_aabb())
        for i in node.mesh.get_surface_count():
            var arr: Array = node.mesh.surface_get_arrays(i)
            var boxes := {}
            for index in arr[Mesh.ARRAY_INDEX]:
                var v: Vector3 = node.global_transform*arr[Mesh.ARRAY_VERTEX][index]
                var key := int(v.y*5)
                if not boxes.has(key): boxes[key]=AABB(v,Vector3.ZERO)
                else: boxes[key]=boxes[key].expand(v)
            print(boxes)
    quit()
