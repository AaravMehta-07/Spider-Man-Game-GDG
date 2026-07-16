extends SceneTree

var failures: Array[String] = []


func _init() -> void:
    _test_clock_boundaries()
    _test_reset()
    _test_state_order()
    if failures.is_empty():
        print("GDScript tests passed: 3 suites")
        quit(0)
        return
    for failure in failures:
        push_error(failure)
    quit(1)


func _test_clock_boundaries() -> void:
    var controller = preload("res://scripts/core/session_controller.gd").new()
    _expect(controller.state_for_time(0.0) == &"CALIBRATION", "0.0 calibration")
    _expect(controller.state_for_time(5.5) == &"WEB_VERIFICATION", "5.5 verification")
    _expect(controller.state_for_time(9.5) == &"CHASE", "9.5 chase")
    _expect(controller.state_for_time(55.0) == &"BOSS_INTRO", "55 boss intro")
    _expect(controller.state_for_time(58.0) == &"BOSS_COMBAT", "58 boss combat")
    _expect(controller.state_for_time(78.0) == &"FINISHER", "78 finisher")
    _expect(controller.state_for_time(83.0) == &"RESULTS", "83 results")
    _expect(controller.state_for_time(90.0) == &"RESETTING", "90 reset")
    controller.free()


func _test_reset() -> void:
    var controller = preload("res://scripts/core/session_controller.gd").new()
    controller.start_session()
    controller.advance(10.0)
    _expect(controller.state == &"CHASE", "clock advances into chase")
    controller.reset_to_attract()
    _expect(controller.state == &"ATTRACT", "reset returns attract")
    _expect(controller.elapsed == 0.0, "reset clears elapsed")
    controller.free()


func _test_state_order() -> void:
    var controller = preload("res://scripts/core/session_controller.gd").new()
    var expected := [&"CALIBRATION", &"WEB_VERIFICATION", &"CHASE", &"BOSS_INTRO", &"BOSS_COMBAT", &"FINISHER", &"RESULTS"]
    var actual: Array[StringName] = []
    for time in [0.0, 5.5, 9.5, 55.0, 58.0, 78.0, 83.0]:
        actual.append(controller.state_for_time(time))
    _expect(actual == expected, "state order is continuous")
    controller.free()


func _expect(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)