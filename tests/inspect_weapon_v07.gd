extends SceneTree
func _initialize(): call_deferred("run")
func run():
    var sword: Node3D = load("res://assets/runtime/characters/v04/knight_sword.glb").instantiate()
    root.add_child(sword)
    var points := []
    for node in sword.find_children("*","MeshInstance3D",true,false):
        for s in node.mesh.get_surface_count():
            for v in node.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
                var p: Vector3 = node.global_transform*v
                points.append([p.x,p.y,p.z])
    FileAccess.open("res://qa/iteration-v07/sword-points.json",FileAccess.WRITE).store_string(JSON.stringify(points))
    quit()
