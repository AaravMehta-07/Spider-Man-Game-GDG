extends Node

@onready var session: SessionController = $SessionController
@onready var vision: UdpVisionReceiver = $UdpVisionReceiver
@onready var city: CityBuilder = $WorldRoot/City
@onready var camera_rig: Node3D = $WorldRoot/CameraRig
@onready var hud: GameHud = $HUD
@onready var audio: AudioManager = $Audio
@onready var saves: SaveManager = $SaveManager

var keyboard_only := false
var capture_mode := false
var boss_test := false
var skip_calibration := false
var score := 0
var combo := 1
var energy := 100.0
var web_pressure := 100.0
var boss_health := 100.0
var tension := 0.0
var move_value := 0.0
var aim := Vector2(0.5, 0.5)
var web_left := false
var web_right := false
var _capture_index := 0
var _attract_captured := false
var _capture_warmup := 0.0
var _event_timer := 0.0
var _result_saved := false

const CAPTURES := [
    [2.0, "02_calibration.png"],
    [7.0, "03_web_verification.png"],
    [11.5, "04_chase_opening.png"],
    [24.5, "05_web_pull.png"],
    [31.0, "06_swing.png"],
    [38.5, "07_rescue.png"],
    [48.0, "08_spider_sense.png"],
    [56.0, "09_boss_reveal.png"],
    [63.0, "10_counter_window.png"],
    [72.5, "11_debris_sling.png"],
    [80.5, "12_finisher.png"],
    [85.0, "13_results.png"],
]


func _ready() -> void:
    _parse_arguments()
    session.state_changed.connect(_on_state_changed)
    session.state_changed.connect(audio.on_state_changed)
    session.session_finished.connect(_on_session_finished)
    hud.state = session.state
    Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
    if capture_mode:
        session.time_scale = 8.0
    if boss_test:
        session.start_session(true)
        session.elapsed = 55.0
    elif skip_calibration:
        session.start_session(true)


func _process(delta: float) -> void:
    if capture_mode and not _attract_captured:
        _capture_warmup += delta
        if _capture_warmup >= 0.5:
            _save_capture("01_attract.png")
            _attract_captured = true
            session.start_session(false)
    if not session.session_active and Input.is_action_just_pressed("ui_accept"):
        _reset_run()
        session.start_session(false)
    if Input.is_key_pressed(KEY_F3) and not hud.diagnostics_visible:
        hud.diagnostics_visible = true
    if Input.is_key_pressed(KEY_F4):
        keyboard_only = true
    _read_input()
    session.advance(delta)
    _update_gameplay(delta)
    _update_presentation(delta)
    _capture_due_frames()


func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed:
        if event.keycode == KEY_F3:
            hud.diagnostics_visible = not hud.diagnostics_visible
        elif event.keycode == KEY_F11:
            var mode := DisplayServer.window_get_mode()
            DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if mode == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)
        elif event.keycode == KEY_R:
            _reset_run()
            session.start_session(false)
        elif event.keycode == KEY_B and event.ctrl_pressed:
            session.start_session(true)
            session.elapsed = 55.0
        elif event.keycode == KEY_M:
            AudioServer.set_bus_mute(0, not AudioServer.is_bus_mute(0))


func _parse_arguments() -> void:
    var arguments := OS.get_cmdline_user_args()
    keyboard_only = "--keyboard-only" in arguments
    capture_mode = "--capture-demo" in arguments
    boss_test = "--boss-test" in arguments
    skip_calibration = "--skip-calibration" in arguments
    if "--windowed" not in arguments:
        DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func _read_input() -> void:
    var use_vision := vision.is_fresh() and not keyboard_only
    if use_vision:
        var data := vision.latest
        move_value = float(data.get("move", 0.0))
        aim = Vector2(float(data.get("aim_x", 0.5)), float(data.get("aim_y", 0.5)))
        web_left = bool(data.get("web_left", false))
        web_right = bool(data.get("web_right", false))
        tension = maxf(tension, float(data.get("two_hand_pull", 0.0)))
        hud.tracking = "VISION LINK  %.0f%%" % (float(data.get("pose_confidence", 0.0)) * 100.0)
    else:
        move_value = Input.get_axis("move_left", "move_right")
        aim = get_viewport().get_mouse_position() / get_viewport().get_visible_rect().size
        aim.x = clampf(aim.x, 0.05, 0.95)
        aim.y = clampf(aim.y, 0.1, 0.9)
        web_left = Input.is_action_pressed("web_left")
        web_right = Input.is_action_pressed("web_right")
        if Input.is_action_pressed("pull") and session.state == SessionController.FINISHER:
            tension = minf(1.0, tension + get_process_delta_time() * 0.45)
        hud.tracking = "KEYBOARD / MOUSE"


func _update_gameplay(delta: float) -> void:
    if not session.session_active:
        web_pressure = minf(100.0, web_pressure + delta * 24.0)
        return
    var firing := web_left or web_right
    if firing and web_pressure > 0.0:
        web_pressure = maxf(0.0, web_pressure - delta * 20.0)
        score += int(delta * 420.0 * combo)
        if session.state == SessionController.BOSS_COMBAT:
            boss_health = maxf(8.0, boss_health - delta * 7.0)
    else:
        web_pressure = minf(100.0, web_pressure + delta * 14.0)
    _event_timer += delta
    if _event_timer >= 3.4 and session.state in [SessionController.CHASE, SessionController.BOSS_COMBAT]:
        _event_timer = 0.0
        var succeeded := absf(move_value) > 0.35 or Input.is_action_pressed("jump") or Input.is_action_pressed("crouch")
        if succeeded:
            score += 650 * combo
            combo = mini(8, combo + 1)
            hud.flash = 0.42
        else:
            energy -= 9.0 if session.state == SessionController.CHASE else 16.0
            combo = 1
            hud.flash = 0.75
            if energy <= 0.0:
                energy = 25.0
                hud.prompt = "LAST CHANCE MODE  •  HERO SYSTEMS RESTORED"
    if session.state == SessionController.FINISHER:
        boss_health = maxf(0.0, 8.0 * (1.0 - tension))
        if session.elapsed > 82.3:
            tension = maxf(tension, 1.0)


func _update_presentation(delta: float) -> void:
    city.set_mission_state(session.state)
    var target_x := move_value * 3.2
    var target_y := 5.2
    if Input.is_action_pressed("jump"):
        target_y += 1.2
    if Input.is_action_pressed("crouch"):
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
    hud.boss_health = boss_health
    hud.tension = tension
    hud.web_left = web_left
    hud.web_right = web_right
    hud.aim = aim
    hud.packet_rate = vision.packet_rate
    hud.fps = Engine.get_frames_per_second()


func _on_state_changed(_previous: StringName, current: StringName) -> void:
    hud.prompt = ""
    if current == SessionController.CHASE:
        hud.prompt = "THE VEIL IS ESCAPING  •  STOP IT BEFORE THE CITY CORE"
    elif current == SessionController.BOSS_INTRO:
        hud.prompt = "UNKNOWN ENTITY LOCKED  •  THE VEIL"
    elif current == SessionController.FINISHER:
        hud.prompt = "BOTH HANDS FORWARD  •  FIRE BOTH WEBS"
        web_left = true
        web_right = true
    elif current == SessionController.RESULTS:
        hud.prompt = ""
        score += int(tension * 5000.0)
        if not _result_saved:
            saves.add_result({"nickname": "", "codename": "The Neon Weaver", "score": score, "web_accuracy": 84, "spider_sense": 91, "boss_control": 89, "final_tension": int(tension * 100.0), "timestamp": Time.get_datetime_string_from_system()})
            _result_saved = true


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
    if image == null:
        return
    image.save_png(directory.path_join(file_name))


func _reset_run() -> void:
    score = 0
    combo = 1
    energy = 100.0
    web_pressure = 100.0
    boss_health = 100.0
    tension = 0.0
    _event_timer = 0.0
    _result_saved = false


func _on_session_finished() -> void:
    if capture_mode:
        get_tree().quit(0)