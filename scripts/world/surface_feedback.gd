class_name SurfaceFeedback
extends Node3D

var pulse := 0.0
var phase_two := false
var mesh_instance: MeshInstance3D

func setup(mesh: MeshInstance3D) -> void:
    mesh_instance = mesh

func trigger_step(_position: Vector3, heavy := false, surface_id := "sand") -> void:
    var amount := 0.18 if surface_id == "sand" else 0.28
    if surface_id == "wet_sand":
        amount = 0.36
    pulse = maxf(pulse, amount if not heavy else amount * 1.7)

func set_phase_two(active: bool) -> void:
    phase_two = active
    if mesh_instance and mesh_instance.material_override is StandardMaterial3D:
        var material := mesh_instance.material_override as StandardMaterial3D
        material.emission_enabled = active
        material.emission = Color("5a1e28") if active else Color.BLACK
        material.emission_energy_multiplier = 0.45 if active else 1.0

func _process(delta: float) -> void:
    pulse = move_toward(pulse, 0.0, delta * 1.8)
    if mesh_instance:
        mesh_instance.scale.y = 1.0 + pulse * 0.08
