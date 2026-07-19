extends SceneTree

var failures: Array[String] = []
var passed := 0


func _init() -> void:
    _test_clock_boundaries()
    _test_reset()
    _test_state_order()
    _test_large_delta_preserves_state_side_effects()
    _test_one_hundred_session_resets()
    _test_chase_actions()
    _test_perfect_chase_web_accuracy()
    _test_chase_schedule_has_no_overlap()
    _test_city_obstacles_and_scoring()
    _test_every_chase_kind_has_visual_geometry()
    _test_green_goblin_assets()
    _test_boss_counter()
    _test_boss_free_fire_and_target_lock()
    _test_finisher_always_completes()
    _test_udp_sequence_deduplication()
    _test_udp_live_bind_and_loopback_policy()
    _test_branding_layout_bounds()
    _test_camera_start_policy()
    _test_collision_failure_policy()
    _test_instruction_coverage()
    _test_leaderboard_sort_and_corruption()
    _test_capture_uses_isolated_leaderboard_path()
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


func _test_large_delta_preserves_state_side_effects() -> void:
    var controller = preload("res://scripts/core/session_controller.gd").new()
    var transitions: Array[StringName] = []
    controller.state_changed.connect(func(_previous, current): transitions.append(current))
    controller.start_session()
    controller.advance(90.0)
    var expected := [&"CALIBRATION", &"WEB_VERIFICATION", &"CHASE", &"BOSS_INTRO", &"BOSS_COMBAT", &"FINISHER", &"RESULTS", &"RESETTING", &"ATTRACT"]
    _expect(transitions == expected, "large frame delta preserves every timeline transition in order")
    _expect(not controller.session_active and controller.elapsed == 0.0, "large frame delta still completes and resets exactly once")
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


func _test_perfect_chase_web_accuracy() -> void:
    var director = preload("res://scripts/chase/chase_director.gd").new()
    var inputs := [
        [10.5, {"dodge_left": true}],
        [13.0, {"web_left": true}],
        [16.0, {"jump": true}],
        [20.0, {"web_left": true, "pull": 1.0}],
        [24.0, {"crouch": true}],
        [28.0, {"web_left": true}],
        [33.0, {"web_right": true}],
        [38.5, {"dodge_right": true}],
        [43.0, {"shield": true}],
        [48.0, {"web_left": true, "web_right": true}],
    ]
    for entry in inputs:
        var challenge_index: int = director.index
        var action := str(director.CHALLENGES[challenge_index]["action"])
        if action in ["web", "pull", "double_web"]:
            director.register_web_shot()
        director.update(float(entry[0]), entry[1])
    _expect(director.web_hits == 5 and director.web_shots == 5, "all web-based chase interactions share one accuracy model")
    _expect(director.web_accuracy() == 100, "perfect chase reports 100 percent web accuracy")
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


func _test_every_chase_kind_has_visual_geometry() -> void:
    var city = preload("res://scripts/environment/city_builder.gd").new()
    var kinds := [&"billboard", &"drone", &"vent", &"barrier", &"scaffold", &"swing", &"rescue", &"crane", &"shockwave", &"collapse"]
    for kind in kinds:
        city._spawn_piece(kind)
        var piece: Node3D = city._set_pieces.back()
        _expect(piece.get_child_count() > 0, "%s chase set piece has visible geometry" % kind)
        city.reset_dynamic_objects()
    city.free()

func _test_green_goblin_assets() -> void:
    _expect(FileAccess.file_exists("res://assets/models/green_goblin_2002.glb"), "Green Goblin source model is versioned")
    _expect(FileAccess.file_exists("res://assets/fonts/Oxanium.ttf"), "HUD font is bundled")
    _expect(FileAccess.file_exists("res://assets/branding/gdg/gdg_logo_horizontal.png"), "home branding is bundled")
    _expect(FileAccess.file_exists("res://assets/branding/gdg/gdg_logo.png"), "results branding is bundled")
    var scene: PackedScene = load("res://scenes/green_goblin_boss.tscn")
    _expect(scene != null, "Green Goblin boss scene loads")
    if scene != null:
        var visual := scene.instantiate()
        _expect(visual is GreenGoblinVisual, "boss scene uses the Green Goblin visual controller")
        _expect(visual.find_child("GreenGoblinModel", true, false) != null, "boss scene contains the supplied model")
        _expect(visual.find_child("LeftThruster", true, false) != null and visual.find_child("RightThruster", true, false) != null, "glider has visible thruster effects")
        visual.free()

func _test_boss_counter() -> void:
    var controller = preload("res://scripts/boss/boss_controller.gd").new()
    controller.update(58.8, 0.1, {"dodge_left": true, "move": -1.0})
    _expect(controller.index == 1, "boss defense advances on correct response")
    _expect(controller.health < 100.0, "boss is revealed and damaged after counter")
    _expect(controller.successful_counters == 1, "boss counter is recorded")
    controller.free()


func _test_boss_free_fire_and_target_lock() -> void:
    var controller = preload("res://scripts/boss/boss_controller.gd").new()
    _expect(controller.boss_target_locked(Vector2(0.5, 0.43)), "centered two-hand aim locks the boss")
    _expect(controller.boss_target_locked(Vector2(0.71, 0.68)), "visible boss bounds remain hittable")
    _expect(not controller.boss_target_locked(Vector2(0.05, 0.9)), "off-target aim does not lock the boss")
    var health_before: float = controller.health
    _expect(controller.register_web_shot(60.0, Vector2(0.5, 0.43), 1, 0.0), "locked web shot hits outside a counter window")
    _expect(controller.health < health_before and controller.normal_web_hits == 1, "normal boss web shot causes visible chip damage")
    var health_after_hit: float = controller.health
    _expect(not controller.register_web_shot(60.5, Vector2(0.05, 0.9), 1, 0.0), "off-target boss web shot misses")
    _expect(controller.health == health_after_hit, "missed boss web shot causes no damage")
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
    var first := JSON.stringify({"v": 1, "kind": "input", "data": {"session_id": "initial", "sequence": 8, "move": 0.25}}).to_utf8_buffer()
    var stale := JSON.stringify({"v": 1, "kind": "input", "data": {"session_id": "initial", "sequence": 7, "move": -1.0}}).to_utf8_buffer()
    var current := JSON.stringify({"v": 1, "kind": "input", "data": {"session_id": "initial", "sequence": 9, "move": 0.75}}).to_utf8_buffer()
    receiver._accept_packet(first)
    receiver._accept_packet(stale)
    _expect(receiver.latest_sequence == 8, "duplicate input sequence is rejected")
    _expect(is_equal_approx(float(receiver.latest.get("move")), 0.25), "stale payload cannot overwrite current input")
    receiver._accept_packet(current)
    _expect(receiver.latest_sequence == 9, "newer input sequence is accepted")
    _expect(receiver.is_fresh(), "accepted packet refreshes heartbeat age")
    var old_session := JSON.stringify({"v": 1, "kind": "input", "data": {"session_id": "old", "sequence": 100, "move": -0.5}}).to_utf8_buffer()
    var restarted_session := JSON.stringify({"v": 1, "kind": "input", "data": {"session_id": "new", "sequence": 1, "move": 0.5}}).to_utf8_buffer()
    receiver._accept_packet(old_session)
    receiver._accept_packet(restarted_session)
    _expect(receiver.latest_session_id == "new", "new vision process session is recognized")
    _expect(receiver.latest_sequence == 1, "sequence restarts safely with a new vision session")
    _expect(is_equal_approx(float(receiver.latest.get("move")), 0.5), "restarted vision input replaces the old session")
    var delayed_old := JSON.stringify({"v": 1, "kind": "input", "data": {"session_id": "old", "sequence": 101, "move": -1.0}}).to_utf8_buffer()
    receiver._accept_packet(delayed_old)
    _expect(receiver.latest_session_id == "new" and receiver.latest_sequence == 1, "retired session packets cannot reclaim input")
    var malformed_data := JSON.stringify({"v": 1, "kind": "input", "data": [1, 2, 3]}).to_utf8_buffer()
    receiver._accept_packet(malformed_data)
    _expect(receiver.latest_sequence == 1, "non-dictionary UDP data is rejected")
    var oversized := PackedByteArray()
    oversized.resize(9000)
    oversized.fill(0)
    receiver._accept_packet(oversized)
    _expect(receiver.latest_sequence == 1, "oversized UDP packets are rejected")
    receiver.free()


func _test_udp_live_bind_and_loopback_policy() -> void:
    var receiver = preload("res://scripts/networking/udp_vision_receiver.gd").new()
    var stream_started := [false]
    receiver.stream_started.connect(func(): stream_started[0] = true)
    _expect(receiver.start_listening(0) == OK, "vision receiver binds on Windows-compatible IPv4 socket")
    _expect(receiver.listening and receiver.peer.get_local_port() > 0, "vision receiver exposes a live local port")
    _expect(receiver._is_loopback("127.0.0.1"), "IPv4 loopback packets are allowed")
    _expect(receiver._is_loopback("::1"), "IPv6 loopback packets are allowed")
    _expect(not receiver._is_loopback("192.168.1.20"), "LAN packets are rejected by policy")
    var sender := PacketPeerUDP.new()
    var port: int = receiver.peer.get_local_port()
    _expect(sender.connect_to_host("127.0.0.1", port) == OK, "test sender connects to receiver")
    var packet := JSON.stringify({"v": 1, "kind": "input", "data": {"session_id": "live", "sequence": 1, "tracked": true}}).to_utf8_buffer()
    sender.put_packet(packet)
    OS.delay_msec(20)
    receiver._process(0.02)
    _expect(receiver.latest_sequence == 1 and receiver.is_fresh(), "raw localhost UDP reaches gameplay receiver")
    _expect(stream_started[0], "first localhost packet emits stream acknowledgment")
    sender.close()
    receiver.peer.close()
    receiver.free()


func _test_branding_layout_bounds() -> void:
    var hud_script = preload("res://scripts/ui/hud.gd")
    var attract_rect: Rect2 = hud_script.attract_brand_rect()
    var results_rect: Rect2 = hud_script.results_brand_rect(Vector2(1920, 1080))
    _expect(attract_rect.end.y + 18.0 <= hud_script.ATTRACT_TITLE_TOP, "home banner leaves a title safety gap")
    _expect(results_rect.end.y + 30.0 <= hud_script.RESULTS_TITLE_TOP, "results banner leaves a title safety gap")
    _expect(attract_rect.end.x < 700.0, "home banner stays inside the left content column")
    _expect(is_equal_approx(results_rect.get_center().x, 960.0), "results banner remains centered")


func _test_camera_start_policy() -> void:
    var main_script = preload("res://scripts/core/main.gd")
    _expect(not main_script.camera_session_ready(false, false), "camera session rejects missing service and player")
    _expect(not main_script.camera_session_ready(true, false), "camera session rejects untracked player")
    _expect(not main_script.camera_session_ready(false, true), "camera session rejects stale packets")
    _expect(main_script.camera_session_ready(true, true), "camera session starts only with fresh tracked input")
    _expect(not main_script.camera_session_ready(true, true, 1, 1.0), "camera session requires both hands")
    _expect(not main_script.camera_session_ready(true, true, 2, 0.1), "camera session rejects one-frame hand detection")
    _expect(not main_script.camera_session_ready(true, true, 2, 3.0, false, true), "camera session requires the left palm open")
    _expect(not main_script.camera_session_ready(true, true, 2, 2.99, true, true), "camera session requires the full three-second lock")


func _test_collision_failure_policy() -> void:
    var main_script = preload("res://scripts/core/main.gd")
    _expect(not main_script.collision_limit_reached(2), "two obstacle collisions do not fail the run")
    _expect(main_script.collision_limit_reached(3), "three obstacle collisions fail the run")
    _expect(main_script.collision_limit_reached(1, 1), "collision limit remains configurable and deterministic")


func _test_instruction_coverage() -> void:
    var main_script = preload("res://scripts/core/main.gd")
    var expected := [
        &"billboard", &"drone", &"vent", &"barrier", &"scaffold", &"swing", &"rescue",
        &"crane", &"shockwave", &"collapse", &"right_slash", &"overhead", &"energy",
        &"counter", &"debris", &"ground_wave",
    ]
    for kind in expected:
        _expect(main_script.INSTRUCTION_HINTS.has(kind), "instruction exists for %s" % kind)
        _expect(str(main_script.INSTRUCTION_HINTS[kind]).length() > 20, "instruction is actionable for %s" % kind)
    _expect("MOUSE + P" in str(main_script.INSTRUCTION_HINTS[&"barrier"]), "barrier keyboard hint includes web attachment plus pull")
    _expect("MOUSE + P" in str(main_script.INSTRUCTION_HINTS[&"debris"]), "debris keyboard hint includes web attachment plus pull")
    for kind in [&"drone", &"swing", &"rescue", &"counter"]:
        var hint := str(main_script.INSTRUCTION_HINTS[kind])
        _expect("PINCH" not in hint and "CLENCH A FIST" not in hint, "fire instruction only teaches the accepted web pose for %s" % kind)


func _test_leaderboard_sort_and_corruption() -> void:
    var manager = preload("res://scripts/persistence/save_manager.gd").new()
    manager.file_path = "res://../artifacts/test_reports/test_leaderboard.json"
    manager.entries = []
    manager.add_result({"score": 100})
    manager.add_result({"score": 450})
    _expect(int(manager.entries[0].get("score")) == 450, "leaderboard sorts highest score first")
    var corrupt := FileAccess.open(manager.file_path, FileAccess.WRITE)
    _expect(corrupt != null, "test leaderboard file opens")
    if corrupt != null:
        corrupt.store_string("[1]")
        corrupt.close()
    manager.load_leaderboard()
    _expect(manager.entries.is_empty(), "corrupted leaderboard recovers to a clean list")
    manager.free()


func _test_capture_uses_isolated_leaderboard_path() -> void:
    var main_script = preload("res://scripts/core/main.gd")
    _expect(main_script.CAPTURE_LEADERBOARD_PATH.begins_with("res://../artifacts/test_reports/"), "capture runs do not write the participant leaderboard")
    var source := FileAccess.get_file_as_string("res://scripts/core/main.gd")
    _expect('for _attempt in range(3)' not in source, "session synchronization is not applied three times")

func _expect(condition: bool, message: String) -> void:
    if condition:
        passed += 1
    else:
        failures.append(message)
