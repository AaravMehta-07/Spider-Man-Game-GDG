extends Node

@onready var session: SessionController = $SessionController
@onready var vision: UdpVisionReceiver = $UdpVisionReceiver
@onready var chase: ChaseDirector = $ChaseDirector
@onready var boss: BossController = $BossController
@onready var city: CityBuilder = $WorldRoot/City
@onready var camera_rig: Node3D = $WorldRoot/CameraRig
@onready var hud: GameHud = $HUD
@onready var audio: AudioManager = $Audio
@onready var saves: SaveManager = $SaveManager

var keyboard_only := false
var capture_mode := false
var boss_test := false
var skip_calibration := false
var operator_camera_id := 0
var operator_mirror := true
var score := 0
var combo := 1
var energy := 100.0
var web_pressure := 100.0
var move_value := 0.0
var aim := Vector2(0.5, 0.5)
var actions: Dictionary = {}
var assist_level := 0.2
var last_chance_used := false
var _capture_index := 0
var _attract_captured := false
var _capture_warmup := 0.0
var _result_saved := false
var _was_firing := false
var _tracking_loss_elapsed := 0.0
var _impact_label := ""
var _impact_label_time := 0.0
var _capture_real_started_ms := 0
var _fps_samples := PackedFloat32Array()
var _low_fps_elapsed := 0.0

const CAPTURES := [
    [2.0, "02_calibration.png"],
    [7.0, "03_web_verification.png"],
    [11.5, "04_chase_opening.png"],
    [21.0, "05_web_pull.png"],
    [29.0, "06_swing.png"],
    [34.0, "07_rescue.png"],
    [44.5, "08_spider_sense.png"],
    [56.0, "09_boss_reveal.png"],
    [63.0, "10_counter_window.png"],
    [72.5, "11_debris_sling.png"],
    [80.5, "12_finisher.png"],
    [85.0, "13_results.png"],
]


func _ready() -> void:
    _parse_arguments()
    _connect_systems()
    hud.state = session.state
    hud.high_score = saves.daily_high_score()
    hud.leaderboard = saves.today_entries()
    Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
    if capture_mode:
        session.time_scale = 8.0
        _capture_real_started_ms = Time.get_ticks_msec()
    if boss_test:
        _reset_run()
        _start_session(true)
        session.elapsed = 55.0
    elif skip_calibration:
        _reset_run()
        _start_session(true)


func _connect_systems() -> void:
    session.state_changed.connect(_on_state_changed)
    session.state_changed.connect(audio.on_state_changed)
    session.session_finished.connect(_on_session_finished)
    chase.challenge_started.connect(_on_challenge_started)
    chase.challenge_cleared.connect(_on_challenge_cleared)
    chase.challenge_missed.connect(_on_player_hit)
    boss.attack_started.connect(_on_boss_attack)
    boss.counter_success.connect(_on_boss_counter)
    boss.player_hit.connect(_on_player_hit)
    boss.boss_health_changed.connect(_on_boss_health_changed)
    boss.finisher_prompt.connect(_on_finisher_prompt)
    boss.contained.connect(_on_boss_contained)


func _process(delta: float) -> void:
    _start_capture_after_warmup(delta)
    if not session.session_active and Input.is_action_just_pressed("ui_accept"):
        _reset_run()
        _start_session(false)
    _read_input(delta)
    session.advance(delta)
    _update_gameplay(delta)
    _update_presentation(delta)
    _capture_due_frames()
    _impact_label_time = maxf(0.0, _impact_label_time - delta)


func _unhandled_input(event: InputEvent) -> void:
    if not event is InputEventKey or not event.pressed or event.echo:
        return
    match event.keycode:
        KEY_F3:
            hud.diagnostics_visible = not hud.diagnostics_visible
        KEY_F4:
            keyboard_only = not keyboard_only
            hud.toast = "KEYBOARD MODE" if keyboard_only else "CAMERA MODE"
        KEY_F5:
            if hud.operator_visible:
                operator_camera_id = maxi(0, operator_camera_id - 1)
                _send_vision_command({"command": "set_camera", "camera_id": operator_camera_id})
                hud.toast = "CAMERA %d SELECTED" % operator_camera_id
        KEY_F6:
            if hud.operator_visible:
                operator_camera_id = mini(15, operator_camera_id + 1)
                _send_vision_command({"command": "set_camera", "camera_id": operator_camera_id})
                hud.toast = "CAMERA %d SELECTED" % operator_camera_id
        KEY_F7:
            if hud.operator_visible:
                _send_vision_command({"command": "restart_camera"})
                hud.toast = "CAMERA RESTART REQUESTED"
        KEY_F8:
            if hud.operator_visible:
                operator_mirror = not operator_mirror
                _send_vision_command({"command": "set_mirror", "enabled": operator_mirror})
                hud.toast = "CAMERA MIRROR %s" % ("ON" if operator_mirror else "OFF")
        KEY_F9:
            if hud.operator_visible:
                var next_vsync := DisplayServer.VSYNC_DISABLED if DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED else DisplayServer.VSYNC_ENABLED
                DisplayServer.window_set_vsync_mode(next_vsync)
                hud.toast = "VSYNC %s" % ("OFF" if next_vsync == DisplayServer.VSYNC_DISABLED else "ON")
        KEY_F11:
            _toggle_fullscreen()
        KEY_M:
            AudioServer.set_bus_mute(0, not AudioServer.is_bus_mute(0))
        KEY_R:
            _reset_run()
            _start_session(false)
        KEY_C:
            _reset_run()
            _start_session(false)
        KEY_B:
            if hud.operator_visible:
                _reset_run()
                _start_session(true)
                session.elapsed = 55.0
        KEY_O:
            if event.ctrl_pressed:
                hud.operator_visible = not hud.operator_visible
        KEY_Q:
            if event.ctrl_pressed and event.shift_pressed:
                hud.quit_confirmation = not hud.quit_confirmation
        KEY_TAB:
            if hud.operator_visible:
                hud.operator_page = 1 - hud.operator_page
        KEY_HOME:
            if hud.operator_visible:
                session.reset_to_attract()
                _reset_run()
                hud.operator_visible = false
        KEY_DELETE:
            if hud.operator_visible:
                hud.clear_confirmation = true
        KEY_Y:
            if hud.clear_confirmation:
                saves.clear_leaderboard()
                hud.high_score = 0
                hud.clear_confirmation = false
                hud.toast = "LEADERBOARD CLEARED"
            elif hud.quit_confirmation:
                get_tree().quit(0)
        KEY_ESCAPE:
            hud.operator_visible = false
            hud.quit_confirmation = false
            hud.clear_confirmation = false


func _parse_arguments() -> void:
    var arguments := OS.get_cmdline_user_args()
    keyboard_only = "--keyboard-only" in arguments
    capture_mode = "--capture-demo" in arguments
    boss_test = "--boss-test" in arguments
    skip_calibration = "--skip-calibration" in arguments
    if "--windowed" not in arguments:
        DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func _read_input(delta: float) -> void:
    var packet_timeout := 1500 if capture_mode else 350
    var use_vision := vision.is_fresh(packet_timeout) and not keyboard_only
    actions = {
        "move": 0.0,
        "jump": false,
        "crouch": false,
        "dodge_left": false,
        "dodge_right": false,
        "shield": false,
        "web_left": false,
        "web_right": false,
        "pull": 0.0,
        "two_hand_pull": 0.0,
    }
    if use_vision:
        var data := vision.latest
        actions.move = float(data.get("move", 0.0))
        actions.jump = bool(data.get("jump", false))
        actions.crouch = bool(data.get("crouch", false))
        actions.dodge_left = bool(data.get("dodge_left", false))
        actions.dodge_right = bool(data.get("dodge_right", false))
        actions.shield = bool(data.get("shield", false))
        actions.web_left = bool(data.get("web_left", false))
        actions.web_right = bool(data.get("web_right", false))
        actions.pull = float(data.get("pull", 0.0))
        actions.two_hand_pull = float(data.get("two_hand_pull", 0.0))
        aim = Vector2(float(data.get("aim_x", 0.5)), float(data.get("aim_y", 0.5)))
        var tracked := bool(data.get("tracked", false))
        _tracking_loss_elapsed = 0.0 if tracked else _tracking_loss_elapsed + delta
        hud.tracking = "VISION LINK  %.0f%%" % (float(data.get("pose_confidence", 0.0)) * 100.0)
        if not tracked and session.session_active:
            hud.toast = "RETURN TO THE SCAN ZONE"
    else:
        if not keyboard_only:
            _tracking_loss_elapsed += delta
            if session.session_active:
                hud.toast = "CAMERA SIGNAL LOST  |  RECONNECTING..."
        actions.move = Input.get_axis("move_left", "move_right")
        actions.jump = Input.is_action_pressed("jump")
        actions.crouch = Input.is_action_pressed("crouch")
        actions.dodge_left = Input.is_action_pressed("dodge_left")
        actions.dodge_right = Input.is_action_pressed("dodge_right")
        actions.shield = Input.is_action_pressed("shield")
        actions.web_left = Input.is_action_pressed("web_left")
        actions.web_right = Input.is_action_pressed("web_right")
        actions.pull = 1.0 if Input.is_action_pressed("pull") else 0.0
        actions.two_hand_pull = actions.pull if actions.web_left and actions.web_right else 0.0
        aim = get_viewport().get_mouse_position() / get_viewport().get_visible_rect().size
        aim.x = clampf(aim.x, 0.05, 0.95)
        aim.y = clampf(aim.y, 0.1, 0.9)
        hud.tracking = "KEYBOARD / MOUSE"
    if _tracking_loss_elapsed >= 6.0 and session.session_active and not keyboard_only:
        session.reset_to_attract()
        _reset_run()
    move_value = float(actions.move)


func _update_gameplay(delta: float) -> void:
    if not session.session_active:
        web_pressure = minf(100.0, web_pressure + delta * 24.0)
        return
    var firing := bool(actions.web_left) or bool(actions.web_right)
    if firing and not _was_firing:
        chase.register_web_shot()
        audio.play_effect("web_fire")
    _was_firing = firing
    if firing and web_pressure > 0.0:
        web_pressure = maxf(0.0, web_pressure - delta * (15.0 - assist_level * 4.0))
    else:
        web_pressure = minf(100.0, web_pressure + delta * 16.0)
    if web_pressure <= 0.0:
        actions.web_left = false
        actions.web_right = false
        hud.toast = "WEB PRESSURE RECHARGING"
    if session.state == SessionController.CHASE:
        chase.update(session.elapsed, actions)
    elif session.state in [SessionController.BOSS_COMBAT, SessionController.FINISHER]:
        boss.update(session.elapsed, delta, actions)


func _update_presentation(delta: float) -> void:
    city.set_mission_state(session.state)
    city.set_player_lane(move_value)
    city.set_boss_energy(boss.health, boss.tension)
    var target_x := move_value * 3.2
    var target_y := 5.2
    if bool(actions.get("jump", false)):
        target_y += 1.2
    if bool(actions.get("crouch", false)):
        target_y -= 1.1
    camera_rig.position.x = lerpf(camera_rig.position.x, target_x, delta * 7.0)
    camera_rig.position.y = lerpf(camera_rig.position.y, target_y, delta * 8.0)
    camera_rig.rotation.z = lerpf(camera_rig.rotation.z, -move_value * 0.07, delta * 6.0)
    hud.state = session.state
    hud.elapsed = session.elapsed
    hud.score = score
    hud.combo = combo
    hud.energy = energy
    hud.web_pressure = web_pressure
    hud.boss_health = boss.health
    hud.tension = boss.tension
    hud.web_left = bool(actions.get("web_left", false))
    hud.web_right = bool(actions.get("web_right", false))
    hud.aim = aim
    hud.packet_rate = vision.packet_rate
    hud.fps = Engine.get_frames_per_second()
    var telemetry: Dictionary = vision.latest
    hud.camera_fps = float(telemetry.get("camera_fps", 0.0))
    hud.pose_fps = float(telemetry.get("pose_fps", 0.0))
    hud.hand_fps = float(telemetry.get("hand_fps", 0.0))
    hud.pose_confidence = float(telemetry.get("pose_confidence", 0.0))
    hud.hand_confidence = float(telemetry.get("hand_confidence", 0.0))
    hud.packet_age_ms = float(Time.get_ticks_msec() - vision.last_packet_ms) if vision.last_packet_ms >= 0 else -1.0
    hud.body_action = _body_action_label()
    hud.hand_action = _hand_action_label()
    hud.active_particles = city.get_active_particles()
    hud.pool_usage = city.get_pool_usage()
    hud.memory_mb = Performance.get_monitor(Performance.MEMORY_STATIC) / (1024.0 * 1024.0)
    _low_fps_elapsed = _low_fps_elapsed + delta if hud.fps < 45.0 else maxf(0.0, _low_fps_elapsed - delta * 2.0)
    if _low_fps_elapsed >= 3.0 and not city.low_quality:
        city.set_low_quality(true)
        hud.toast = "PERFORMANCE MODE  |  VFX REDUCED"
    hud.quality_mode = "PERFORMANCE" if city.low_quality else "HIGH"
    hud.impact_label = _impact_label if _impact_label_time > 0.0 else ""
    hud.assist_level = assist_level
    hud.rescues = chase.rescues
    hud.perfect_dodges = chase.perfect_dodges
    hud.web_accuracy = chase.web_accuracy()
    if capture_mode and _fps_samples.size() < 2400:
        _fps_samples.append(minf(240.0, 1.0 / maxf(delta, 0.0001)))


func _body_action_label() -> String:
    for key in ["jump", "crouch", "dodge_left", "dodge_right", "shield"]:
        if bool(actions.get(key, false)):
            return key.to_upper()
    var horizontal := float(actions.get("move", 0.0))
    if absf(horizontal) > 0.12:
        return "MOVE LEFT" if horizontal < 0.0 else "MOVE RIGHT"
    return "IDLE"


func _hand_action_label() -> String:
    if float(actions.get("two_hand_pull", 0.0)) > 0.1:
        return "DOUBLE WEB PULL"
    if float(actions.get("pull", 0.0)) > 0.1:
        return "PULL"
    if bool(actions.get("web_left", false)) and bool(actions.get("web_right", false)):
        return "DOUBLE WEB"
    if bool(actions.get("web_left", false)):
        return "LEFT WEB"
    if bool(actions.get("web_right", false)):
        return "RIGHT WEB"
    return "OPEN"

func _on_challenge_started(kind: StringName, prompt: String, direction: StringName) -> void:
    hud.prompt = prompt
    hud.danger_direction = direction
    city.play_set_piece(kind)
    audio.play_effect("spider_sense")


func _on_challenge_cleared(points: int, label: String) -> void:
    score += ChaseDirector.score_with_combo(points, combo)
    combo = mini(8, combo + 1)
    assist_level = maxf(0.0, assist_level - 0.025)
    _show_impact(label)
    audio.play_effect("web_attach")


func _on_boss_attack(kind: StringName, prompt: String, direction: StringName) -> void:
    hud.prompt = prompt
    hud.danger_direction = direction
    city.play_set_piece(kind)
    audio.play_effect("spider_sense")


func _on_boss_counter(points: int, label: String) -> void:
    score += ChaseDirector.score_with_combo(points, combo)
    combo = mini(8, combo + 1)
    _show_impact(label)
    audio.play_effect("impact")


func _on_player_hit(damage: float) -> void:
    energy -= damage
    combo = 1
    assist_level = minf(1.0, assist_level + 0.12)
    hud.flash = 0.9
    audio.play_effect("impact")
    if energy <= 0.0:
        energy = 25.0
        last_chance_used = true
        assist_level = minf(1.0, assist_level + 0.3)
        score = maxi(0, score - 1200)
        hud.toast = "LAST CHANCE MODE  |  HERO SYSTEMS RESTORED"


func _on_boss_health_changed(value: float) -> void:
    hud.boss_health = value


func _on_finisher_prompt(value: String) -> void:
    hud.prompt = value


func _on_boss_contained() -> void:
    score += 5000
    _show_impact("THE VEIL CONTAINED")


func _show_impact(label: String) -> void:
    _impact_label = label
    _impact_label_time = 1.1
    hud.flash = 0.45


func _on_state_changed(_previous: StringName, current: StringName) -> void:
    hud.prompt = ""
    hud.danger_direction = &"center"
    if current == SessionController.CHASE:
        hud.prompt = "THE VEIL IS ESCAPING  |  STOP IT BEFORE THE CITY CORE"
    elif current == SessionController.BOSS_INTRO:
        hud.prompt = "UNKNOWN ENTITY LOCKED  |  THE VEIL"
        city.play_set_piece(&"boss_reveal")
    elif current == SessionController.FINISHER:
        hud.prompt = "BOTH HANDS FORWARD  |  FIRE BOTH WEBS"
    elif current == SessionController.RESULTS:
        _impact_label = ""
        _impact_label_time = 0.0
        hud.impact_label = ""
        hud.toast = ""
        hud.toast_time = 0.0
        _save_result_once()


func _save_result_once() -> void:
    if _result_saved:
        return
    score += int(boss.tension * 5000.0)
    saves.add_result({
        "nickname": "",
        "codename": "The Neon Weaver",
        "score": score,
        "web_accuracy": chase.web_accuracy(),
        "spider_sense": _spider_sense_score(),
        "boss_control": mini(100, boss.successful_counters * 17),
        "final_tension": int(boss.tension * 100.0),
        "rescues": chase.rescues,
        "timestamp": Time.get_datetime_string_from_system(),
    })
    _result_saved = true
    hud.high_score = maxi(hud.high_score, score)
    hud.leaderboard = saves.today_entries()
    hud.daily_rank = hud.leaderboard.find_custom(func(entry): return int(entry.get("score", 0)) == score) + 1


func _spider_sense_score() -> int:
    var total := chase.perfect_dodges + boss.successful_counters
    return mini(100, 55 + total * 7)


func _start_capture_after_warmup(delta: float) -> void:
    if not capture_mode or _attract_captured:
        return
    _capture_warmup += delta
    if _capture_warmup >= 0.75:
        _save_capture("01_attract.png")
        _attract_captured = true
        _reset_run()
        _start_session(false)


func _capture_due_frames() -> void:
    if not capture_mode or not session.session_active or _capture_index >= CAPTURES.size():
        return
    var entry: Array = CAPTURES[_capture_index]
    if session.elapsed >= float(entry[0]):
        _save_capture(str(entry[1]))
        _capture_index += 1


func _save_capture(file_name: String) -> void:
    var directory := ProjectSettings.globalize_path("res://../artifacts/screenshots")
    DirAccess.make_dir_recursive_absolute(directory)
    var image := get_viewport().get_texture().get_image()
    if image != null:
        image.save_png(directory.path_join(file_name))


func _reset_run() -> void:
    score = 0
    combo = 1
    energy = 100.0
    web_pressure = 100.0
    assist_level = 0.2
    last_chance_used = false
    _result_saved = false
    _was_firing = false
    _tracking_loss_elapsed = 0.0
    _impact_label = ""
    _impact_label_time = 0.0
    chase.reset()
    boss.reset()
    city.reset_dynamic_objects()


func _start_session(skip: bool = false) -> void:
    _send_vision_command({"command": "sync_session"})
    session.start_session(skip)

func _send_vision_command(command: Dictionary) -> void:
    var peer := PacketPeerUDP.new()
    var error := peer.connect_to_host("127.0.0.1", 42421)
    if error == OK:
        peer.put_packet(JSON.stringify(command).to_utf8_buffer())

func _toggle_fullscreen() -> void:
    var mode := DisplayServer.window_get_mode()
    var next := DisplayServer.WINDOW_MODE_WINDOWED
    if mode != DisplayServer.WINDOW_MODE_FULLSCREEN:
        next = DisplayServer.WINDOW_MODE_FULLSCREEN
    DisplayServer.window_set_mode(next)


func _on_session_finished() -> void:
    if capture_mode:
        _write_capture_report()
        get_tree().quit(0)


func _write_capture_report() -> void:
    var directory := ProjectSettings.globalize_path("res://../artifacts/test_reports")
    DirAccess.make_dir_recursive_absolute(directory)
    var average_fps := 0.0
    var minimum_fps := 0.0
    var raw_minimum_fps := 0.0
    if not _fps_samples.is_empty():
        var sorted_samples := Array(_fps_samples)
        sorted_samples.sort()
        raw_minimum_fps = float(sorted_samples[0])
        minimum_fps = float(sorted_samples[int(floor((sorted_samples.size() - 1) * 0.05))])
        for sample in _fps_samples:
            average_fps += sample
        average_fps /= _fps_samples.size()
    var report := {
        "effective_session_seconds": session.elapsed,
        "real_capture_seconds": (Time.get_ticks_msec() - _capture_real_started_ms) / 1000.0,
        "average_fps": average_fps,
        "minimum_fps": minimum_fps,
        "raw_minimum_fps": raw_minimum_fps,
        "minimum_definition": "5th percentile; raw minimum includes screenshot stalls",
        "sample_count": _fps_samples.size(),
        "screenshot_count": CAPTURES.size() + 1,
        "returned_to_attract": true,
    }
    var file := FileAccess.open(directory.path_join("capture_timing.json"), FileAccess.WRITE)
    if file:
        file.store_string(JSON.stringify(report, "  "))
