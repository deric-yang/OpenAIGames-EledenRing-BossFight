class_name WardenHitGeometry
extends RefCounted

static func contains(profile: Dictionary, origin: Vector3, forward: Vector3, point: Vector3) -> bool:
    var offset := point-origin
    if str(profile.get("shape","sector")) in ["lane","disc"]:
        if absf(point.y-float(profile.get("ground_y",origin.y)))>3.0: return false
    elif absf(offset.y)>4.0: return false
    offset.y = 0
    var facing := Vector3(forward.x,0,forward.z).normalized()
    var along := offset.dot(facing)
    var across := absf(offset.dot(Vector3(facing.z,0,-facing.x)))
    var reach := float(profile.get("reach",8))
    match str(profile.get("shape","sector")):
        "lane": return along >= float(profile.get("min_reach",-0.35)) and along <= reach and across <= float(profile.get("width",2))
        "disc": return (offset-facing*float(profile.get("offset",3))).length() <= reach
        _: return offset.length() <= reach and (offset.length()<0.35 or facing.dot(offset.normalized()) >= cos(deg_to_rad(float(profile.get("angle",100))*0.5)))
