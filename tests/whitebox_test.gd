extends SceneTree

var failures := 0
var checks := 0

func _init() -> void:
    _test_resolver()
    _test_surface_query()
    _test_phase_controller()
    if failures > 0:
        print("WHITEBOX_TEST_FAIL failures=%d" % failures)
        quit(1)
    print("WHITEBOX_TEST_PASS checks=%d" % checks)
    quit(0)

func _check(condition: bool, label: String) -> void:
    checks += 1
    if not condition:
        failures += 1
        print("FAIL: %s" % label)

func _test_resolver() -> void:
    var root := Node3D.new()
    get_root().add_child(root)
    var a := Node3D.new()
    var b := Node3D.new()
    root.add_child(a)
    root.add_child(b)
    a.position = Vector3.ZERO
    b.position = Vector3(2.0, 0.0, 0.0)
    _check(CombatResolver.in_range(a, b, 2.1), "range includes target")
    _check(not CombatResolver.in_range(a, b, 1.9), "range excludes target")
    _check(not CombatResolver.resolve_boss_hit(a, b, 3.0, true), "roll evades boss hit")
    root.free()

func _test_surface_query() -> void:
    var query := SurfaceQuery.new()
    query.setup(Vector3.ZERO, Vector2(4.0, 2.5))
    _check(query.query(Vector3(0.0, 0.0, 0.0)) == "wet_sand", "wet sand surface")
    _check(query.query(Vector3(5.0, 0.0, 0.0)) == "ruin_stone", "ruin stone surface")
    query.free()

func _test_phase_controller() -> void:
    var bus := CombatEventBus.new()
    var controller := PhaseController.new()
    controller.setup(bus)
    controller.evaluate_boss_hp(49.0)
    _check(controller.transitioning, "phase transition begins")
    controller._process(4.0)
    _check(controller.phase == 2, "phase transition finishes")
    _check(not controller.transitioning, "phase transition clears")
    bus.free()
    controller.free()
