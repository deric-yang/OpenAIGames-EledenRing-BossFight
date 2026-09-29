class_name CombatCommandBuffer
extends RefCounted
## One pending intention; expiry advances only with the combat simulation clock.
var pending: Dictionary = {}
var ttl := 0.20
var policy := "protect_dodge"
var clock := 0.0
var serial := 0
var journal: Array[Dictionary] = []

func note(kind: String, details: Dictionary = {}) -> void:
    var row := details.duplicate(true)
    row["event"] = kind
    row["t"] = snappedf(clock, 0.001)
    journal.append(row)
    if journal.size() > 120: journal.pop_front()

func offer(action: String, direction: Vector3 = Vector3.ZERO) -> void:
    serial += 1
    note("press", {"action": action, "id": serial})
    if policy == "protect_dodge" and pending.get("action", "") == "roll" and action != "roll":
        note("protected", {"action": action, "kept": "roll", "id": serial})
        return
    if not pending.is_empty():
        note("replaced", {"action": pending.action, "by": action, "id": pending.id})
    pending = {"action": action, "direction": direction, "at": clock, "id": serial}

func advance(delta: float, frozen := false) -> void:
    if frozen: return
    clock += maxf(0.0, delta)
    if not pending.is_empty() and clock - float(pending.at) > ttl + 0.00001:
        clear("expired")

func consume() -> Dictionary:
    var result := pending.duplicate()
    if not result.is_empty():
        note("executed", {"action": result.action, "id": result.id,
            "wait_ms": roundi((clock - float(result.at)) * 1000)})
    pending.clear()
    return result

func clear(reason: String = "cleared") -> void:
    if not pending.is_empty(): note(reason, {"action": pending.action, "id": pending.id})
    pending.clear()

func reset() -> void:
    pending.clear()
    journal.clear()
    serial = 0
    clock = 0.0
