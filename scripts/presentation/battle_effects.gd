class_name BattleEffects
extends Node3D
const ROOT = "res://assets/runtime/vfx/v04/effects/"
const H = preload("res://scripts/world/dune_height_v04.gd")
var live: Array[Dictionary] = []
var pending: Array[Dictionary] = []
func warmup(point: Vector3) -> void:
    blood(point,Vector3.FORWARD,18)
    live[-1].warming = true
    live[-1].duration = 1.4
    pending[-1].warming = true
func blood(point: Vector3, direction: Vector3, damage: float) -> void:
    var tier := "Med" if damage < 25 else ("High" if damage < 60 else "Extreme")
    var node = load(ROOT + "realistic-blood_NS_BloodBurst_" + tier + ".tscn").instantiate()
    node.auto_play = false
    node.ground_height = H.sample
    node.position = point + Vector3(0.5,-1.2,0)
    add_child(node)
    live.append({"node":node,"time":0.0,"duration":4.5,"kind":"blood"})
    var ground_point := point + direction.normalized() * 0.7
    ground_point.y = H.sample(ground_point.x,ground_point.z)
    pending.append({"point":ground_point,"tier":"Low" if damage < 25 else ("Med" if damage < 60 else "High"),"wait":0.23})
    trim()
func materialize(avatar: DuelAvatar, appearing: bool) -> void:
    var node = load(ROOT + "transformation.tscn").instantiate()
    node.auto_play = false
    node.body_template = avatar.model
    node.effect_color = Color(1.0,0.62,0.13) if appearing else Color(0.31,0.30,0.28)
    node.transform = avatar.global_transform
    add_child(node)
    avatar.model.visible = false
    node.body.visible = true
    live.append({"node":node,"time":0.0,"duration":3.2,"kind":"appear" if appearing else "disappear","avatar":avatar})
    trim()
func trim() -> void:
    while live.size() > 14:
        var index := -1
        for i in live.size():
            if live[i].kind == "blood": index = i; break
        if index < 0: break
        live[index].node.queue_free()
        live.remove_at(index)
func clear() -> void:
    for item in live:
        if is_instance_valid(item.node): item.node.queue_free()
    live.clear()
    pending.clear()
func _process(delta: float) -> void:
    for i in range(pending.size()-1,-1,-1):
        pending[i].wait -= delta
        if pending[i].wait <= 0:
            var item: Dictionary = pending[i]
            var node = load(ROOT + "realistic-blood_NS_BloodSplash_" + item.tier + ".tscn").instantiate()
            node.auto_play = false
            node.ground_height = H.sample
            node.position = item.point + Vector3(0.5,0,0)
            add_child(node)
            live.append({"node":node,"time":0.0,"duration":4.5,"kind":"blood"})
            if item.get("warming",false):
                live[-1].warming = true
                live[-1].duration = 1.0
            pending.remove_at(i)
            trim()
    for i in range(live.size()-1,-1,-1):
        var item: Dictionary = live[i]
        item.time += delta
        var time: float = item.time
        if item.kind == "appear": item.node.sample(3.2 + time)
        elif item.kind == "disappear": item.node.sample(time)
        else: item.node.sample(time)
        if item.get("warming",false):
            for mesh in item.node.find_children("*","GeometryInstance3D",true,false): mesh.scale = Vector3.ONE*0.00001
        if time >= float(item.duration):
            if item.kind == "appear" and is_instance_valid(item.avatar): item.avatar.model.visible = true
            item.node.queue_free()
            live.remove_at(i)
