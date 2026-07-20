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
var vision_managed := false
var capture_mode := false
var failure_demo := false
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
var collision_strikes := 0
var mission_failed := false
var _capture_index := 0
var _attract_captured := false
var _capture_warmup := 0.0
var _result_saved := false
var _was_firing := false
var _tracking_loss_elapsed := 0.0
var _player_tracked := false
var _tracking_was_lost := false
var _hand_count := 0
var _camera_ready_dwell := 0.0
var _health_port := 42421
var _impact_label := ""
var _impact_label_time := 0.0
var _capture_real_started_ms := 0
var _fps_samples := PackedFloat32Array()
var _low_fps_elapsed := 0.0
var _shot_feedback_time := 0.0
var _web_trail_left_time := 0.0
var _web_trail_right_time := 0.0
var _vision_command_peer := PacketPeerUDP.new()

const PACKET_TIMEOUT_MS := 600
const MAX_COLLISION_STRIKES := 3
const READY_HOLD_SECONDS := 3.0
const CAPTURE_LEADERBOARD_PATH := "res://../artifacts/test_reports/capture_leaderboard.json"
const INSTRUCTION_HINTS := {
    &"billboard": "LEAN OR STEP LEFT  |  KEYBOARD: Q / A",
    &"drone": "AIM BOTH HANDS; INDEX + PINKY OUT, MIDDLE + RING FOLDED  |  MOUSE CLICK",
    &"vent": "JUMP UP WITH BOTH FEET  |  KEYBOARD: SPACE",
    &"barrier": "AIM + FIRE, CLOSE YOUR FIST, THEN PULL YOUR ARM BACK  |  HOLD MOUSE + P",
    &"scaffold": "CROUCH LOW  |  KEYBOARD: S",
    &"swing": "POINT AT THE ANCHOR, THEN USE THE CLASSIC WEB POSE  |  MOUSE CLICK",
    &"rescue": "AIM AT THE CIVILIAN, THEN USE THE CLASSIC WEB POSE  |  MOUSE CLICK",
    &"crane": "LEAN OR STEP RIGHT  |  KEYBOARD: E / D",
    &"shockwave": "RAISE BOTH FOREARMS TO FORM A SHIELD  |  KEYBOARD: F",
    &"collapse": "AIM BOTH HANDS, THEN FIRE BOTH WEBS  |  LEFT + RIGHT MOUSE",
    &"right_slash": "LEAN OR STEP LEFT  |  KEYBOARD: Q / A",
    &"overhead": "CROUCH LOW  |  KEYBOARD: S",
    &"energy": "RAISE BOTH FOREARMS TO FORM A SHIELD  |  KEYBOARD: F",
    &"counter": "KEEP THE RETICLE ON THE BOSS, THEN USE THE CLASSIC WEB POSE  |  MOUSE CLICK",
    &"debris": "FIRE, CLOSE YOUR FIST, PULL BACK, THEN RELEASE  |  HOLD MOUSE + P",
    &"ground_wave": "JUMP UP WITH BOTH FEET  |  KEYBOARD: SPACE",
}

const CAPTURES := [
    [2.0, "02_calibration.png"],
    [7.0, "03_web_verification.png"],
    [13.6, "04_chase_opening.png"],
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
    if capture_mode:
        _isolate_capture_leaderboard()
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


func _isolate_capture_leaderboard() -> void:
    var directory := ProjectSettings.globalize_path("res://../artifacts/test_reports")
    DirAccess.make_dir_recursive_absolute(directory)
    saves.file_path = CAPTURE_LEADERBOARD_PATH
    saves.entries = []


func _connect_systems() -> void:
    vision.stream_started.connect(_on_vision_stream_started)
    session.state_changed.connect(_on_state_changed)
    session.state_changed.connect(audio.on_state_changed)
    session.session_finished.connect(_on_session_finished)
    chase.challenge_started.connect(_on_challenge_started)
    chase.challenge_cleared.connect(_on_challenge_cleared)
    chase.challenge_missed.connect(_on_chase_missed)
    boss.attack_started.connect(_on_boss_attack)
    boss.counter_success.connect(_on_boss_counter)
    boss.player_hit.connect(_on_boss_hit)
    boss.boss_health_changed.connect(_on_boss_health_changed)
    boss.web_hit.connect(_on_boss_web_hit)
    boss.web_missed.connect(_on_boss_web_missed)
    boss.finisher_prompt.connect(_on_finisher_prompt)
    boss.contained.connect(_on_boss_contained)


func _process(delta: float) -> void:
    _read_input(delta)
    _start_capture_after_warmup(delta)
    _update_onboarding(delta)
    session.advance(delta)
    _update_gameplay(delta)
    _update_presentation(delta)
    _capture_due_frames()
    _impact_label_time = maxf(0.0, _impact_label_time - delta * session.time_scale)
    _shot_feedback_time = maxf(0.0, _shot_feedback_time - delta * session.time_scale)
    _web_trail_left_time = maxf(0.0, _web_trail_left_time - delta)
    _web_trail_right_time = maxf(0.0, _web_trail_right_time - delta)


func _unhandled_input(event: InputEvent) -> void:
    if not event is InputEventKey or not event.pressed or event.echo:
        return
    if not session.session_active and event.keycode in [KEY_ENTER, KEY_KP_ENTER]:
        if keyboard_only:
            _request_session_start(false)
        else:
            hud.toast = "HOLD BOTH OPEN PALMS UNTIL THE LOCK COMPLETES"
            hud.toast_time = 3.0
        return
    match event.keycode:
        KEY_F3:
            hud.diagnostics_visible = not hud.diagnostics_visible
        KEY_F4:
            keyboard_only = not keyboard_only
            hud.toast = "KEYBOARD MODE" if keyboard_only else "CAMERA MODE"
            _tracking_loss_elapsed = 0.0
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
            if hud.operator_visible:
                _request_session_start(false)
        KEY_C:
            if hud.operator_visible:
                _request_session_start(false)
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
                session.reset_to_attract("operator_home")
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
    vision_managed = "--vision-managed" in arguments
    capture_mode = "--capture-demo" in arguments
    failure_demo = capture_mode and "--failure-demo" in arguments
    boss_test = "--boss-test" in arguments
    skip_calibration = "--skip-calibration" in arguments
    for argument in arguments:
        if argument.begins_with("--health-port="):
            var parsed_port := int(argument.trim_prefix("--health-port="))
            if parsed_port >= 1024 and parsed_port <= 65535:
                _health_port = parsed_port
    if "--windowed" not in arguments:
        DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func _read_input(delta: float) -> void:
    var packet_timeout := 1500 if capture_mode else 350
    if not capture_mode:
        packet_timeout = PACKET_TIMEOUT_MS
    var fresh := vision.is_fresh(packet_timeout)
    var transient_actions := vision.consume_transient_actions()
    actions = _keyboard_actions()
    aim = _mouse_aim()
    if fresh and not keyboard_only:
        var data := vision.latest
        var tracked := bool(data.get("tracked", false))
        _hand_count = int(data.get("hand_count", 0))
        _player_tracked = tracked
        if tracked:
            actions.move = float(data.get("move", 0.0))
            for key in ["jump", "crouch", "shield"]:
                actions[key] = bool(actions[key]) or bool(data.get(key, false))
        actions.dodge_left = bool(actions.dodge_left) or bool(transient_actions.dodge_left)
        actions.dodge_right = bool(actions.dodge_right) or bool(transient_actions.dodge_right)
        var has_web_pulse := bool(transient_actions.web_left_trigger) or bool(transient_actions.web_right_trigger)
        if _hand_count > 0 or has_web_pulse:
            actions.web_left = bool(actions.web_left) or bool(data.get("web_left", false))
            actions.web_right = bool(actions.web_right) or bool(data.get("web_right", false))
            actions.web_left_trigger = bool(actions.web_left_trigger) or bool(transient_actions.web_left_trigger)
            actions.web_right_trigger = bool(actions.web_right_trigger) or bool(transient_actions.web_right_trigger)
            actions.fist_left = bool(data.get("fist_left", false))
            actions.fist_right = bool(data.get("fist_right", false))
            actions.palm_open_left = bool(data.get("palm_open_left", false))
            actions.palm_open_right = bool(data.get("palm_open_right", false))
            actions.gesture_left = str(data.get("gesture_left", "OPEN"))
            actions.gesture_right = str(data.get("gesture_right", "OPEN"))
            actions.aim_left_x = float(data.get("aim_left_x", data.get("aim_x", 0.5)))
            actions.aim_left_y = float(data.get("aim_left_y", data.get("aim_y", 0.5)))
            actions.aim_right_x = float(data.get("aim_right_x", data.get("aim_x", 0.5)))
            actions.aim_right_y = float(data.get("aim_right_y", data.get("aim_y", 0.5)))
            actions.pull = maxf(float(actions.pull), float(data.get("pull", 0.0)))
            actions.two_hand_pull = maxf(float(actions.two_hand_pull), float(data.get("two_hand_pull", 0.0)))
            aim = Vector2(float(data.get("aim_x", 0.5)), float(data.get("aim_y", 0.5)))
        _tracking_loss_elapsed = 0.0 if tracked else _tracking_loss_elapsed + delta
        hud.tracking = "VISION LINK  %.0f%%  |  HANDS %d/2" % [float(data.get("pose_confidence", 0.0)) * 100.0, _hand_count]
        if not tracked and session.session_active:
            hud.toast = "RETURN TO THE SCAN ZONE  |  KEYBOARD BACKUP ACTIVE"
    else:
        _player_tracked = keyboard_only
        _hand_count = 2 if keyboard_only else 0
        if not keyboard_only:
            _tracking_loss_elapsed += delta
            if session.session_active:
                hud.toast = "CAMERA SIGNAL LOST  |  KEYBOARD BACKUP ACTIVE"
        hud.tracking = "KEYBOARD / MOUSE" if keyboard_only else "CAMERA RECONNECTING  |  KEYBOARD BACKUP ACTIVE"
    if keyboard_only or capture_mode:
        _camera_ready_dwell = READY_HOLD_SECONDS
    elif fresh and _player_tracked and _hand_count >= 2:
        if bool(actions.get("palm_open_left", false)) and bool(actions.get("palm_open_right", false)):
            _camera_ready_dwell = minf(READY_HOLD_SECONDS, _camera_ready_dwell + delta)
        else:
            _camera_ready_dwell = maxf(0.0, _camera_ready_dwell - delta * 1.5)
    else:
        _camera_ready_dwell = 0.0
    move_value = float(actions.move)
    actions.aim_x = aim.x
    actions.aim_y = aim.y
    var tracking_is_lost := session.session_active and not keyboard_only and _tracking_loss_elapsed >= 0.5
    if tracking_is_lost != _tracking_was_lost:
        print("VISION LINK %s  |  %.2fs" % ["LOST" if tracking_is_lost else "RECOVERED", session.elapsed])
        _tracking_was_lost = tracking_is_lost


func _keyboard_actions() -> Dictionary:
    var keyboard_pull := 1.0 if Input.is_action_pressed("pull") else 0.0
    var left_web := Input.is_action_pressed("web_left")
    var right_web := Input.is_action_pressed("web_right")
    return {
        "move": Input.get_axis("move_left", "move_right"),
        "jump": Input.is_action_pressed("jump"),
        "crouch": Input.is_action_pressed("crouch"),
        "dodge_left": Input.is_action_pressed("dodge_left"),
        "dodge_right": Input.is_action_pressed("dodge_right"),
        "shield": Input.is_action_pressed("shield"),
        "web_left": left_web,
        "web_right": right_web,
        "web_left_trigger": Input.is_action_just_pressed("web_left"),
        "web_right_trigger": Input.is_action_just_pressed("web_right"),
        "fist_left": false,
        "fist_right": false,
        "palm_open_left": keyboard_only,
        "palm_open_right": keyboard_only,
        "aim_left_x": aim.x,
        "aim_left_y": aim.y,
        "aim_right_x": aim.x,
        "aim_right_y": aim.y,
        "gesture_left": "MOUSE" if left_web else "OPEN",
        "gesture_right": "MOUSE" if right_web else "OPEN",
        "pull": keyboard_pull,
        "two_hand_pull": keyboard_pull if left_web and right_web else 0.0,
    }


func _mouse_aim() -> Vector2:
    var value := get_viewport().get_mouse_position() / get_viewport().get_visible_rect().size
    value.x = clampf(value.x, 0.05, 0.95)
    value.y = clampf(value.y, 0.1, 0.9)
    return value


func _update_gameplay(delta: float) -> void:
    if not session.session_active:
        web_pressure = minf(100.0, web_pressure + delta * 24.0)
        return
    var firing := bool(actions.web_left) or bool(actions.web_right)
    var left_trigger := bool(actions.get("web_left_trigger", false))
    var right_trigger := bool(actions.get("web_right_trigger", false))
    var shot_count := int(left_trigger) + int(right_trigger)
    if shot_count > 0:
        _shot_feedback_time = 0.9
        if left_trigger:
            _web_trail_left_time = 0.65
        if right_trigger:
            _web_trail_right_time = 0.65
        audio.play_effect("web_fire")
        if session.state == SessionController.CHASE:
            chase.register_web_shot()
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
        var chase_actions := actions
        if failure_demo:
            chase_actions = actions.duplicate()
            for key in ["jump", "crouch", "dodge_left", "dodge_right", "shield", "web_left", "web_right", "web_left_trigger", "web_right_trigger"]:
                chase_actions[key] = false
            chase_actions.move = 0.0
            chase_actions.pull = 0.0
            chase_actions.two_hand_pull = 0.0
        chase.update(session.elapsed, chase_actions)
    elif session.state in [SessionController.BOSS_COMBAT, SessionController.FINISHER]:
        var counters_before := boss.successful_counters
        boss.update(session.elapsed, delta, actions)
        if session.state == SessionController.BOSS_COMBAT and shot_count > 0 and boss.successful_counters == counters_before:
            boss.register_web_shot(session.elapsed, aim, shot_count, assist_level)


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
    hud.web_left = bool(actions.get("web_left", false)) or _web_trail_left_time > 0.0
    hud.web_right = bool(actions.get("web_right", false)) or _web_trail_right_time > 0.0
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
    hud.camera_ready = keyboard_only or vision.is_fresh(PACKET_TIMEOUT_MS)
    hud.vision_receiver_ready = vision.listening
    hud.vision_receiver_error = vision.listen_error
    hud.player_tracked = keyboard_only or _player_tracked
    hud.hand_count = _hand_count
    hud.hands_ready = keyboard_only or capture_mode or _camera_ready_dwell >= READY_HOLD_SECONDS
    hud.ready_hold_seconds = _camera_ready_dwell
    hud.ready_hold_required = READY_HOLD_SECONDS
    hud.keyboard_mode = keyboard_only
    hud.vision_managed = vision_managed
    hud.tracking_lost = session.session_active and not keyboard_only and _tracking_loss_elapsed >= 0.5
    hud.tracking_loss_seconds = _tracking_loss_elapsed
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
    hud.spider_sense_score = _spider_sense_score()
    hud.boss_control_score = _boss_control_score()
    hud.target_locked = session.state == SessionController.BOSS_COMBAT and BossController.boss_target_locked(aim, assist_level)
    hud.gesture_left = str(actions.get("gesture_left", "OPEN"))
    hud.gesture_right = str(actions.get("gesture_right", "OPEN"))
    hud.collision_strikes = collision_strikes
    hud.max_collision_strikes = MAX_COLLISION_STRIKES
    hud.mission_failed = mission_failed
    if _shot_feedback_time > 0.0:
        hud.shot_feedback = "SHOT FIRED"
    elif session.state == SessionController.WEB_VERIFICATION and _hand_count > 0 and str(actions.get("gesture_left", "OPEN")) == "OPEN" and str(actions.get("gesture_right", "OPEN")) == "OPEN":
        hud.shot_feedback = "POSE NOT RECOGNIZED"
    else:
        hud.shot_feedback = ""
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
    hud.instruction_hint = str(INSTRUCTION_HINTS.get(kind, "FOLLOW THE ACTION PROMPT"))
    hud.danger_direction = direction
    city.play_set_piece(kind)
    audio.play_effect("spider_sense")


func _on_challenge_cleared(points: int, label: String) -> void:
    print("CHASE CLEAR  %s  |  %.2fs" % [label, session.elapsed])
    score += ChaseDirector.score_with_combo(points, combo)
    combo = mini(8, combo + 1)
    assist_level = maxf(0.0, assist_level - 0.025)
    _show_impact(label)
    audio.play_effect("web_attach")
    _clear_context_prompt()


func _on_boss_attack(kind: StringName, prompt: String, direction: StringName) -> void:
    hud.prompt = prompt
    hud.instruction_hint = str(INSTRUCTION_HINTS.get(kind, "FOLLOW THE ACTION PROMPT"))
    hud.danger_direction = direction
    city.play_set_piece(kind)
    hud.show_boss_attack(kind)
    audio.play_effect("spider_sense")


func _on_boss_counter(points: int, label: String) -> void:
    score += ChaseDirector.score_with_combo(points, combo)
    combo = mini(8, combo + 1)
    _show_impact(label)
    city.show_boss_hit(true)
    audio.play_effect("impact")
    _clear_context_prompt()


func _on_chase_missed(damage: float, counts_as_collision: bool) -> void:
    if counts_as_collision:
        collision_strikes = mini(MAX_COLLISION_STRIKES, collision_strikes + 1)
        print("OBSTACLE COLLISION  strike=%d/%d  |  %.2fs" % [collision_strikes, MAX_COLLISION_STRIKES, session.elapsed])
        if collision_limit_reached(collision_strikes) and not mission_failed:
            mission_failed = true
            combo = 1
            hud.toast = "MISSION FAILED  |  TOO MANY COLLISIONS"
            hud.toast_time = 4.0
    else:
        print("CHASE OBJECTIVE MISSED  |  %.2fs" % session.elapsed)
    _apply_damage(maxf(24.0, damage))


func _on_boss_hit(damage: float) -> void:
    _apply_damage(damage)


func _apply_damage(damage: float) -> void:
    energy -= damage
    combo = 1
    assist_level = minf(1.0, assist_level + 0.12)
    hud.flash = 0.9
    audio.play_effect("impact")
    _clear_context_prompt()
    if energy <= 0.0:
        energy = 25.0
        last_chance_used = true
        assist_level = minf(1.0, assist_level + 0.3)
        score = maxi(0, score - 1200)
        hud.toast = "LAST CHANCE MODE  |  HERO SYSTEMS RESTORED"


func _on_boss_web_hit(label: String) -> void:
    score += 180
    _show_impact(label)
    city.show_boss_hit(false)
    audio.play_effect("web_attach")


func _on_boss_web_missed() -> void:
    combo = 1
    hud.toast = "WEB MISSED  |  CENTER BOTH HANDS ON THE TARGET"
    hud.toast_time = 1.2


func _on_boss_health_changed(value: float) -> void:
    hud.boss_health = value


func _on_finisher_prompt(value: String) -> void:
    hud.prompt = value
    hud.instruction_hint = "CAMERA: FIRE BOTH WEBS, CLOSE FISTS + PULL  |  KEYBOARD: HOLD BOTH MOUSE BUTTONS + P"


func _on_boss_contained() -> void:
    score += 5000
    _show_impact("GREEN GOBLIN CONTAINED")


func _show_impact(label: String) -> void:
    _impact_label = label
    _impact_label_time = 1.1
    hud.flash = 0.45


func _clear_context_prompt() -> void:
    hud.prompt = ""
    hud.instruction_hint = _state_instruction(session.state)
    hud.danger_direction = &"center"


func _on_state_changed(_previous: StringName, current: StringName) -> void:
    print("SESSION STATE  %s -> %s  |  %.2fs" % [_previous, current, session.elapsed])
    hud.prompt = ""
    hud.instruction_hint = _state_instruction(current)
    hud.danger_direction = &"center"
    if current == SessionController.CHASE:
        hud.prompt = "GLIDER RAIDERS INBOUND  |  STOP GREEN GOBLIN"
    elif current == SessionController.BOSS_INTRO:
        hud.prompt = "HOSTILE LOCKED  |  GREEN GOBLIN"
        city.play_set_piece(&"boss_reveal")
    elif current == SessionController.FINISHER:
        hud.prompt = "BOTH HANDS FORWARD  |  FIRE BOTH WEBS"
    elif current == SessionController.RESULTS:
        if not boss.final_contained:
            boss.update(82.4, 5.0, {})
        _impact_label = ""
        _impact_label_time = 0.0
        hud.impact_label = ""
        hud.toast = ""
        hud.toast_time = 0.0
        _save_result_once()
    elif current == SessionController.ATTRACT:
        _reset_run()
        _reset_onboarding()


func _state_instruction(current: StringName) -> String:
    match current:
        SessionController.CALIBRATION:
            return "STAND CENTERED WITH YOUR FULL UPPER BODY AND BOTH HANDS VISIBLE"
        SessionController.WEB_VERIFICATION:
            return "AIM WITH BOTH HANDS  |  INDEX + PINKY OUT, MIDDLE + RING FOLDED"
        SessionController.CHASE:
            return "LEAN TO MOVE  |  FOLLOW EACH RED ACTION PROMPT"
        SessionController.BOSS_INTRO:
            return "STAY CENTERED AND GET READY TO DODGE, SHIELD, AND ATTACK"
        SessionController.BOSS_COMBAT:
            return "KEEP TARGET LOCK, FIRE WEBS, AND RESPOND TO EACH COUNTER"
        SessionController.FINISHER:
            return "BOTH HANDS FORWARD, FIRE BOTH WEBS, THEN PULL BOTH ARMS BACK"
    return ""


func _save_result_once() -> void:
    if _result_saved:
        return
    if mission_failed:
        _result_saved = true
        hud.leaderboard = saves.today_entries()
        hud.daily_rank = 0
        return
    score += int(boss.tension * 5000.0)
    saves.add_result({
        "score": score,
        "web_accuracy": chase.web_accuracy(),
        "spider_sense": _spider_sense_score(),
        "boss_control": _boss_control_score(),
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


func _boss_control_score() -> int:
    return mini(100, boss.successful_counters * 17)


func _start_capture_after_warmup(delta: float) -> void:
    if not capture_mode or session.session_active:
        return
    _capture_warmup += delta
    if not _attract_captured and _capture_warmup >= 0.75:
        hud.ready_hold_seconds = 1.7
        hud.hands_ready = false
        _save_capture("01_attract.png")
        _attract_captured = true
        return
    if _attract_captured and _capture_warmup >= 1.0:
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
    if failure_demo and file_name == "13_results.png":
        file_name = "13_failure_results.png"
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
    collision_strikes = 0
    mission_failed = false
    _result_saved = false
    _was_firing = false
    _tracking_loss_elapsed = 0.0
    _tracking_was_lost = false
    _camera_ready_dwell = 0.0
    _impact_label = ""
    _impact_label_time = 0.0
    _shot_feedback_time = 0.0
    _web_trail_left_time = 0.0
    _web_trail_right_time = 0.0
    chase.reset()
    boss.reset()
    city.reset_dynamic_objects()


func _start_session(skip: bool = false) -> void:
    _send_vision_command({"command": "sync_session"})
    session.start_session(skip)
    print("SESSION START  mode=%s tracked=%s" % ["keyboard" if keyboard_only else "camera", _player_tracked])


func _request_session_start(skip: bool = false) -> void:
    var fresh := vision.is_fresh(PACKET_TIMEOUT_MS)
    if not keyboard_only and not capture_mode and not camera_session_ready(
        fresh,
        _player_tracked,
        _hand_count,
        _camera_ready_dwell,
        bool(actions.get("palm_open_left", false)),
        bool(actions.get("palm_open_right", false))
    ):
        if not fresh:
            hud.toast = "CAMERA RECONNECTING  |  WAIT OR PRESS F4 FOR KEYBOARD" if vision_managed else "CAMERA OFFLINE  |  START WITH run.bat OR PRESS F4 FOR KEYBOARD"
        elif not _player_tracked:
            hud.toast = "STEP INTO FRAME  |  KEEP YOUR FULL UPPER BODY VISIBLE"
        else:
            hud.toast = "SHOW BOTH OPEN PALMS  |  HOLD FOR THREE SECONDS"
        hud.toast_time = 4.0
        print("SESSION START BLOCKED  fresh=%s tracked=%s managed=%s" % [fresh, _player_tracked, vision_managed])
        return
    _reset_run()
    _start_session(skip)


static func camera_session_ready(
    packet_fresh: bool,
    tracked: bool,
    hand_count: int = 2,
    ready_dwell: float = READY_HOLD_SECONDS,
    left_open: bool = true,
    right_open: bool = true
) -> bool:
    return packet_fresh and tracked and hand_count >= 2 and left_open and right_open and ready_dwell >= READY_HOLD_SECONDS


func _update_onboarding(_delta: float) -> void:
    if session.session_active or capture_mode or boss_test or skip_calibration:
        return
    if not keyboard_only and camera_session_ready(
        vision.is_fresh(PACKET_TIMEOUT_MS),
        _player_tracked,
        _hand_count,
        _camera_ready_dwell,
        bool(actions.get("palm_open_left", false)),
        bool(actions.get("palm_open_right", false))
    ):
        print("ONBOARDING  OPEN-PALM LOCK -> MISSION")
        _request_session_start(false)


func _reset_onboarding() -> void:
    _camera_ready_dwell = 0.0


static func collision_limit_reached(strikes: int, limit: int = MAX_COLLISION_STRIKES) -> bool:
    return strikes >= maxi(1, limit)

func _on_vision_stream_started() -> void:
    _send_vision_command({"command": "game_input_active"})

func _send_vision_command(command: Dictionary) -> void:
    var error := _vision_command_peer.connect_to_host("127.0.0.1", _health_port)
    if error == OK:
        _vision_command_peer.put_packet(JSON.stringify(command).to_utf8_buffer())

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
