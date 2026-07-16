extends SceneTree

var failures: Array[String] = []
var passed := 0


func _init() -> void:
    _test_clock_boundaries()
    _test_reset()
    _test_state_order()
    _test_one_hundred_session_resets()
    _test_chase_actions()
    _test_chase_schedule_has_no_overlap()
    _test_city_obstacles_and_scoring()
    _test_boss_counter()
    _test_finisher_always_completes()
    _test_udp_sequence_deduplication()
    _test_leaderboard_sort_and_corruption()
    if failures.is_empty():
        print("GDScript tests passed: %d assertions" % passed)
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

func _test_one_hundred_session_resets() -> void:
    var controller = preload("res://scripts/core/session_controller.gd").new()
    var all_reset := true
    for run in range(100):
        controller.start_session()
        controller.advance(90.0)
        all_reset = all_reset and controller.state == &"ATTRACT" and not controller.session_active
    _expect(all_reset, "100 consecutive session clocks reset without restart")
    controller.free()

func _test_chase_actions() -> void:
    var director = preload("res://scripts/chase/chase_director.gd").new()
    director.update(12.0, {"dodge_left": true, "move": -1.0})
    _expect(director.index == 1, "correct dodge resolves first chase event")
    _expect(director.perfect_dodges == 1, "perfect dodge is counted")
    director.update(16.0, {"web_left": true})
    _expect(director.index == 2, "web shot resolves drone event")
    _expect(director.web_hits == 1, "web hit is counted")
    director.free()


func _test_chase_schedule_has_no_overlap() -> void:
    var script = preload("res://scripts/chase/chase_director.gd")
    for index in range(script.CHALLENGES.size() - 1):
        var current: Dictionary = script.CHALLENGES[index]
        var next: Dictionary = script.CHALLENGES[index + 1]
        var deadline := float(current["time"]) + float(current["duration"])
        _expect(deadline < float(next["time"]), "chase events never require impossible simultaneous actions")
    var director = script.new()
    director.update(15.0, {})
    _expect(director.index == 1, "missed event advances instead of deadlocking")
    director.free()


func _test_city_obstacles_and_scoring() -> void:
    var director_script = preload("res://scripts/chase/chase_director.gd")
    var expected_kinds := [&"billboard", &"drone", &"vent", &"barrier", &"scaffold", &"swing", &"rescue", &"crane", &"shockwave", &"collapse"]
    var actual_kinds: Array[StringName] = []
    for challenge in director_script.CHALLENGES:
        actual_kinds.append(challenge["kind"])
    _expect(actual_kinds == expected_kinds, "chase uses recognizable city obstacles")
    _expect(director_script.score_with_combo(1000, 1) == 1000, "base score is exact")
    _expect(director_script.score_with_combo(1000, 4) == 1540, "combo multiplier is deterministic")
    _expect(director_script.score_with_combo(1000, 99) == 2260, "combo score is capped at x8")
    var director = director_script.new()
    director.register_web_shot()
    director.update(12.0, {"dodge_left": true})
    director.update(16.0, {"web_left": true})
    _expect(director.web_accuracy() == 100, "web accuracy uses fired shots and confirmed web hits")
    director.free()

func _test_boss_counter() -> void:
    var controller = preload("res://scripts/boss/boss_controller.gd").new()
    controller.update(58.8, 0.1, {"dodge_left": true, "move": -1.0})
    _expect(controller.index == 1, "boss defense advances on correct response")
    _expect(controller.health < 100.0, "boss is revealed and damaged after counter")
    _expect(controller.successful_counters == 1, "boss counter is recorded")
    controller.free()


func _test_finisher_always_completes() -> void:
    var controller = preload("res://scripts/boss/boss_controller.gd").new()
    controller.update(78.5, 0.5, {"web_left": true, "web_right": true, "two_hand_pull": 1.0})
    _expect(controller.tension > 0.0, "two-hand pull builds tension")
    controller.update(82.4, 0.1, {})
    _expect(controller.final_contained, "finisher timed assist guarantees containment")
    _expect(controller.health == 0.0, "contained boss health reaches zero")
    controller.free()

func _test_udp_sequence_deduplication() -> void:
    var receiver = preload("res://scripts/networking/udp_vision_receiver.gd").new()
    var first := JSON.stringify({"v": 1, "kind": "input", "data": {"sequence": 8, "move": 0.25}}).to_utf8_buffer()
    var stale := JSON.stringify({"v": 1, "kind": "input", "data": {"sequence": 7, "move": -1.0}}).to_utf8_buffer()
    var current := JSON.stringify({"v": 1, "kind": "input", "data": {"sequence": 9, "move": 0.75}}).to_utf8_buffer()
    receiver._accept_packet(first)
    receiver._accept_packet(stale)
    _expect(receiver.latest_sequence == 8, "duplicate input sequence is rejected")
    _expect(is_equal_approx(float(receiver.latest.get("move")), 0.25), "stale payload cannot overwrite current input")
    receiver._accept_packet(current)
    _expect(receiver.latest_sequence == 9, "newer input sequence is accepted")
    _expect(receiver.is_fresh(), "accepted packet refreshes heartbeat age")
    receiver.free()


func _test_leaderboard_sort_and_corruption() -> void:
    var manager = preload("res://scripts/persistence/save_manager.gd").new()
    manager.file_path = "user://test_leaderboard.json"
    manager.entries = []
    manager.add_result({"score": 100, "codename": "First"})
    manager.add_result({"score": 450, "codename": "Second"})
    _expect(int(manager.entries[0].get("score")) == 450, "leaderboard sorts highest score first")
    var corrupt := FileAccess.open(manager.file_path, FileAccess.WRITE)
    corrupt.store_string("{}")
    corrupt.close()
    manager.load_leaderboard()
    _expect(manager.entries.is_empty(), "corrupted leaderboard recovers to a clean list")
    manager.free()

func _expect(condition: bool, message: String) -> void:
    if condition:
        passed += 1
    else:
        failures.append(message)
