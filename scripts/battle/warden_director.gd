class_name WardenDirector
extends RefCounted
## Distance-gated weighted attacks, bounded pressure sequences and explicit recovery.
var elapsed := 0.0
var cooldowns: Dictionary = {}
var recent: Array[String] = []
var remaining := 0
var pressure := false

func reset() -> void:
    elapsed = 0.0
    cooldowns.clear()
    recent.clear()
    cancel_sequence()

func cancel_sequence() -> void:
    remaining = 0
    pressure = false

func begin_sequence(rng: RandomNumberGenerator, after_push := false) -> void:
    pressure = after_push
    remaining = rng.randi_range(1,2) if after_push else (2 if rng.randf() < 0.42 else 1)

func choose(pool: Array[String], profiles: Dictionary, distance: float, rng: RandomNumberGenerator) -> String:
    var candidates: Array[String] = []
    var weights: Array[float] = []
    var total := 0.0
    for id in pool:
        var profile: Dictionary = profiles[id]
        if float(cooldowns.get(id,0)) > elapsed: continue
        if not recent.is_empty() and id == recent.back(): continue
        var reach := float(profile.reach)
        if profile.shape == "disc": reach += float(profile.get("offset",0))
        if distance > reach + 0.2: continue
        var weight := 1.0
        if profile.shape == "lane": weight *= 2.8 if distance > 7 else 0.32
        elif profile.shape == "disc": weight *= 1.6 if distance < 5.5 else 0.8
        if pressure and profile.windows.size() > 1: weight *= 2.2
        if id in recent: weight *= 0.25
        candidates.append(id)
        weights.append(weight)
        total += weight
    if candidates.is_empty(): return ""
    var roll := rng.randf()*total
    for i in candidates.size():
        roll -= weights[i]
        if roll <= 0: return candidates[i]
    return candidates.back()

func started(id: String, duration: float, profile: Dictionary) -> void:
    remaining = maxi(0,remaining-1)
    cooldowns[id] = elapsed+duration+(4.0 if profile.shape == "lane" else 2.5)
    recent.append(id)
    if recent.size() > 3: recent.pop_front()

func recovery(profile: Dictionary, rng: RandomNumberGenerator) -> float:
    if remaining > 0: return rng.randf_range(0.18,0.32)
    pressure = false
    # Animation already contains its follow-through. Extra breathing room remains punishable.
    return clampf(float(profile.get("recovery",1.3))*0.53,0.65,1.2)+rng.randf_range(0,0.12)
