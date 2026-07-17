class_name GameHud
extends Control

var state: StringName = &"ATTRACT"
var elapsed := 0.0
var score := 0
var combo := 1
var energy := 100.0
var web_pressure := 100.0
var boss_health := 100.0
var tension := 0.0
var prompt := ""
var instruction_hint := ""
var tracking := "KEYBOARD READY"
var camera_ready := false
var player_tracked := false
var hand_count := 0
var hands_ready := false
var keyboard_mode := false
var vision_managed := false
var tracking_lost := false
var tracking_loss_seconds := 0.0
var diagnostics_visible := false
var operator_visible := false
var operator_page := 0
var quit_confirmation := false
var clear_confirmation := false
var packet_rate := 0.0
var fps := 60.0
var camera_fps := 0.0
var pose_fps := 0.0
var hand_fps := 0.0
var packet_age_ms := -1.0
var pose_confidence := 0.0
var hand_confidence := 0.0
var body_action := "IDLE"
var hand_action := "OPEN"
var active_particles := 0
var pool_usage := 0
var memory_mb := 0.0
var quality_mode := "HIGH"
var flash := 0.0
var web_left := false
var web_right := false
var aim := Vector2(0.5, 0.5)
var danger_direction: StringName = &"center"
var impact_label := ""
var toast := ""
var toast_time := 0.0
var assist_level := 0.2
var rescues := 0
var perfect_dodges := 0
var web_accuracy := 0
var spider_sense_score := 0
var boss_control_score := 0
var target_locked := false
var gesture_left := "OPEN"
var gesture_right := "OPEN"
var collision_strikes := 0
var max_collision_strikes := 3
var mission_failed := false
var shot_feedback := ""
var onboarding_mode: StringName = &"READY"
var ready_hold_seconds := 0.0
var ready_hold_required := 3.0
var participant_name := ""
var air_strokes: Array[PackedVector2Array] = []
var air_cursor := Vector2(0.5, 0.5)
var air_pen_down := false
var air_prediction := ""
var air_confidence := 0.0
var name_confirm_hold := 0.0
var name_confirm_required := 1.5
var rescue_goal := 1
var high_score := 0
var leaderboard: Array = []
var daily_rank := 0
var attract_background: Texture2D = preload("res://assets/generated/attract_city.png")
var hero_emblem: Texture2D = preload("res://assets/branding/hero_emblem.png")
var recruitment_qr: Texture2D = preload("res://assets/branding/recruitment_qr.png")
var recruitment_qr_ready := FileAccess.file_exists("res://assets/branding/recruitment_qr.ready")


func _process(delta: float) -> void:
    flash = maxf(0.0, flash - delta * 2.2)
    if not toast.is_empty() and toast_time <= 0.0:
        toast_time = 2.0
    toast_time = maxf(0.0, toast_time - delta)
    if toast_time <= 0.0:
        toast = ""
    queue_redraw()


func _draw() -> void:
    var viewport_size := size
    if state == &"ATTRACT":
        if onboarding_mode == &"NAME_ENTRY":
            _draw_name_entry(viewport_size)
        else:
            _draw_attract(viewport_size)
    elif state == &"RESULTS":
        _draw_results(viewport_size)
    else:
        _draw_vignette(viewport_size)
        _draw_status(viewport_size)
        _draw_context(viewport_size)
        _draw_reticle(viewport_size)
        _draw_webs(viewport_size)
        _draw_danger(viewport_size)
        if tracking_lost:
            _draw_reconnect(viewport_size)
    if not impact_label.is_empty():
        _draw_impact(viewport_size)
    if not toast.is_empty():
        _draw_toast(viewport_size)
    if diagnostics_visible:
        _draw_diagnostics()
    if operator_visible:
        _draw_operator(viewport_size)
    if quit_confirmation:
        _draw_quit_confirmation(viewport_size)
    if clear_confirmation:
        _draw_clear_confirmation(viewport_size)
    if flash > 0.0:
        draw_rect(Rect2(Vector2.ZERO, viewport_size), Color(1.0, 0.05, 0.12, flash * 0.22))


func _draw_vignette(viewport_size: Vector2) -> void:
    draw_rect(Rect2(0, 0, viewport_size.x, 9), Color(0.92, 0.02, 0.12))
    draw_rect(Rect2(0, viewport_size.y - 9, viewport_size.x, 9), Color(0.02, 0.62, 0.96))
    draw_colored_polygon(PackedVector2Array([
        Vector2(0, 0), Vector2(420, 0), Vector2(290, 125), Vector2(0, 180)
    ]), Color(0.005, 0.012, 0.035, 0.95))
    draw_colored_polygon(PackedVector2Array([
        Vector2(viewport_size.x, viewport_size.y),
        Vector2(viewport_size.x - 450, viewport_size.y),
        Vector2(viewport_size.x - 320, viewport_size.y - 120),
        Vector2(viewport_size.x, viewport_size.y - 175)
    ]), Color(0.005, 0.012, 0.035, 0.95))


func _draw_attract(viewport_size: Vector2) -> void:
    draw_texture_rect(attract_background, Rect2(Vector2.ZERO, viewport_size), false)
    draw_rect(Rect2(Vector2.ZERO, viewport_size), Color(0.002, 0.008, 0.025, 0.30))
    draw_colored_polygon(PackedVector2Array([
        Vector2(0, 0), Vector2(viewport_size.x * 0.59, 0),
        Vector2(viewport_size.x * 0.48, viewport_size.y), Vector2(0, viewport_size.y)
    ]), Color(0.002, 0.006, 0.02, 0.76))
    _text("WEB//PROTOCOL", Vector2(105, 220), 82, Color.WHITE)
    _text("SPIDER-SENSE", Vector2(111, 292), 39, Color(1.0, 0.08, 0.16))
    draw_line(Vector2(108, 325), Vector2(780, 325), Color(0.02, 0.72, 1.0), 5)
    _text("YOUR BODY IS THE CONTROLLER", Vector2(111, 392), 28, Color(0.72, 0.86, 1.0))
    _text("STEP INTO THE SCAN ZONE", Vector2(111, 454), 43, Color.WHITE)
    var can_start := keyboard_mode or (camera_ready and player_tracked and hands_ready)
    var start_color := Color(0.82, 0.02, 0.12, 0.92) if can_start else Color(0.04, 0.16, 0.28, 0.94)
    _panel(Rect2(108, 535, 560, 88), start_color)
    if keyboard_mode:
        _text("ENTER IDENTITY  [ENTER]", Vector2(142, 593), 26, Color.WHITE)
    elif can_start:
        _text("IDENTITY LOCK ACQUIRED", Vector2(142, 593), 25, Color.WHITE)
    elif camera_ready and player_tracked:
        _text("OPEN PALMS  %.1f / %.1f SEC" % [ready_hold_seconds, ready_hold_required], Vector2(142, 593), 23, Color.WHITE)
    elif camera_ready:
        _text("STEP INTO FRAME TO BEGIN", Vector2(142, 593), 25, Color.WHITE)
    else:
        _text("CAMERA SERVICE OFFLINE", Vector2(142, 593), 25, Color.WHITE)
    _text("F4  CAMERA / KEYBOARD MODE", Vector2(108, 660), 19, Color(0.72, 0.86, 1.0))
    _text("DODGE THE CITY  |  MASTER THE WEB", Vector2(108, 760), 24, Color(0.6, 0.86, 1.0))
    _text("DEFEAT WHAT YOU CANNOT SEE", Vector2(108, 803), 24, Color.WHITE)
    _text("ONE PLAYER  |  90 SECONDS  |  NO CONTROLLER", Vector2(108, 865), 20, Color(0.72, 0.76, 0.84))
    _text("LOCAL CAMERA PROCESSING  |  NO VIDEO SAVED", Vector2(108, 905), 17, Color(0.42, 0.7, 0.84))
    if not keyboard_mode and camera_ready and player_tracked:
        _bar(Rect2(108, 627, 560, 10), ready_hold_seconds / maxf(0.1, ready_hold_required), Color(0.1, 0.86, 1.0))
    draw_texture_rect(hero_emblem, Rect2(viewport_size.x - 315, 155, 210, 210), false)
    _panel(Rect2(viewport_size.x - 365, 55, 310, 78), Color(0.01, 0.02, 0.05, 0.86))
    _text("DAILY HIGH  %06d" % high_score, Vector2(viewport_size.x - 335, 103), 21, Color(1.0, 0.82, 0.18))
    _draw_attract_camera(viewport_size)
    _draw_quick_controls(viewport_size)


func _draw_attract_camera(viewport_size: Vector2) -> void:
    var rect := Rect2(viewport_size.x - 590, 395, 520, 178)
    _panel(rect, Color(0.005, 0.016, 0.045, 0.94))
    _text("INPUT STATUS", rect.position + Vector2(28, 38), 18, Color(0.2, 0.78, 1.0))
    var label := "KEYBOARD READY" if keyboard_mode else "CAMERA READY" if camera_ready else "CAMERA OFFLINE"
    var status_color := Color(0.25, 1.0, 0.55) if keyboard_mode or (camera_ready and player_tracked and hands_ready) else Color(1.0, 0.72, 0.18) if camera_ready else Color(1.0, 0.2, 0.28)
    _text(label, rect.position + Vector2(28, 78), 25, status_color)
    if keyboard_mode:
        _text("A/D MOVE  |  MOUSE AIM + FIRE", rect.position + Vector2(28, 116), 17, Color.WHITE)
        _text("SPACE JUMP  |  S CROUCH  |  F SHIELD", rect.position + Vector2(28, 146), 16, Color(0.72, 0.86, 1.0))
    elif camera_ready and player_tracked and hands_ready:
        _text("PLAYER TRACKED  |  OPEN-PALM LOCK COMPLETE", rect.position + Vector2(28, 116), 16, Color.WHITE)
        _text("OPENING AIR-WRITING BOARD", rect.position + Vector2(28, 146), 16, Color(0.72, 0.86, 1.0))
    elif camera_ready and player_tracked:
        _text("BODY READY  |  HANDS %d/2" % hand_count, rect.position + Vector2(28, 116), 17, Color.WHITE)
        _text("HOLD BOTH OPEN PALMS FOR THREE SECONDS", rect.position + Vector2(28, 146), 15, Color(0.72, 0.86, 1.0))
    elif camera_ready:
        _text("STAND CENTERED, FACING THE CAMERA", rect.position + Vector2(28, 116), 17, Color.WHITE)
        _text("KEEP YOUR UPPER BODY + HANDS VISIBLE", rect.position + Vector2(28, 146), 16, Color(0.72, 0.86, 1.0))
    else:
        var offline_help := "CAMERA SERVICE RECONNECTING" if vision_managed else "START THE GAME USING run.bat"
        _text(offline_help, rect.position + Vector2(28, 116), 18, Color.WHITE)
        _text("OR PRESS F4 FOR KEYBOARD MODE", rect.position + Vector2(28, 146), 16, Color(0.72, 0.86, 1.0))


func _draw_quick_controls(viewport_size: Vector2) -> void:
    var rect := Rect2(viewport_size.x - 690, 610, 620, 405)
    _panel(rect, Color(0.005, 0.016, 0.045, 0.94))
    _text("HOW TO PLAY", rect.position + Vector2(30, 42), 24, Color.WHITE)
    _control_row(rect, 88, "AIM", "CENTER BOTH HANDS ON THE TARGET", "MOVE MOUSE")
    _control_row(rect, 145, "FIRE / ATTACK", "WEB POSE / PINCH / FIST", "MOUSE CLICK")
    _control_row(rect, 202, "PULL", "FIRE, CLOSE FIST + PULL BACK", "MOUSE + P")
    _control_row(rect, 259, "DODGE / MOVE", "LEAN OR STEP LEFT / RIGHT", "A / D")
    _control_row(rect, 316, "JUMP / CROUCH", "JUMP UP / CROUCH LOW", "SPACE / S")
    _control_row(rect, 373, "SHIELD", "RAISE BOTH FOREARMS", "F")


func _draw_name_entry(viewport_size: Vector2) -> void:
    draw_texture_rect(attract_background, Rect2(Vector2.ZERO, viewport_size), false)
    draw_rect(Rect2(Vector2.ZERO, viewport_size), Color(0.002, 0.008, 0.025, 0.83))
    _text_center("AIR-WRITE YOUR NAME", Vector2(viewport_size.x * 0.5, 82), 48, Color.WHITE)
    _text_center("ONE UPPERCASE BLOCK LETTER AT A TIME", Vector2(viewport_size.x * 0.5, 124), 19, Color(0.25, 0.78, 1.0))
    var board := Rect2(viewport_size.x * 0.5 - 390, 175, 780, 610)
    _panel(board, Color(0.006, 0.018, 0.05, 0.97))
    draw_rect(board.grow(-22), Color(0.01, 0.035, 0.075, 0.72), true)
    for x in range(1, 6):
        var grid_x := board.position.x + board.size.x * float(x) / 6.0
        draw_line(Vector2(grid_x, board.position.y + 22), Vector2(grid_x, board.end.y - 22), Color(0.1, 0.35, 0.5, 0.18), 1.0)
    for y in range(1, 5):
        var grid_y := board.position.y + board.size.y * float(y) / 5.0
        draw_line(Vector2(board.position.x + 22, grid_y), Vector2(board.end.x - 22, grid_y), Color(0.1, 0.35, 0.5, 0.18), 1.0)
    for stroke in air_strokes:
        for index in range(1, stroke.size()):
            var from := board.position + stroke[index - 1] * board.size
            var to := board.position + stroke[index] * board.size
            draw_line(from, to, Color(0.12, 0.86, 1.0), 10.0, true)
            draw_circle(to, 5.0, Color(0.72, 0.96, 1.0))
    var cursor_position := board.position + air_cursor * board.size
    draw_circle(cursor_position, 17.0, Color(1.0, 0.12, 0.2) if air_pen_down else Color(0.1, 0.78, 1.0), false, 4.0)
    draw_circle(cursor_position, 4.0, Color.WHITE)
    _panel(Rect2(85, 175, 430, 610), Color(0.005, 0.016, 0.045, 0.96))
    _text("YOUR NAME", Vector2(120, 230), 20, Color(0.25, 0.78, 1.0))
    _text(participant_name if not participant_name.is_empty() else "_", Vector2(120, 305), 43, Color.WHITE)
    _text("PREDICTED LETTER", Vector2(120, 390), 17, Color(0.72, 0.86, 1.0))
    _text(air_prediction if not air_prediction.is_empty() else "?", Vector2(120, 510), 112, Color(1.0, 0.18, 0.25))
    _text("MATCH  %d%%" % int(air_confidence * 100.0), Vector2(120, 570), 18, Color(0.25, 0.78, 1.0))
    _text("FIST     DRAW", Vector2(120, 645), 18, Color.WHITE)
    _text("OPEN     LIFT PEN", Vector2(120, 682), 18, Color.WHITE)
    _text("PINCH    ACCEPT LETTER", Vector2(120, 719), 18, Color.WHITE)
    _panel(Rect2(viewport_size.x - 515, 175, 430, 610), Color(0.005, 0.016, 0.045, 0.96))
    _text("FINISH", Vector2(viewport_size.x - 475, 230), 20, Color(0.25, 0.78, 1.0))
    if keyboard_mode:
        _text("TYPE YOUR NAME", Vector2(viewport_size.x - 475, 305), 23, Color.WHITE)
        _text("PRESS ENTER", Vector2(viewport_size.x - 475, 350), 23, Color.WHITE)
        _text("BACKSPACE TO UNDO", Vector2(viewport_size.x - 475, 430), 17, Color(0.72, 0.86, 1.0))
    else:
        _text("BOTH FISTS", Vector2(viewport_size.x - 475, 305), 22, Color.WHITE)
        _text("HOLD TO CLEAR / UNDO", Vector2(viewport_size.x - 475, 342), 17, Color(0.72, 0.86, 1.0))
        _text("BOTH PALMS OPEN", Vector2(viewport_size.x - 475, 430), 22, Color.WHITE)
        _text("HOLD TO START MISSION", Vector2(viewport_size.x - 475, 467), 17, Color(0.72, 0.86, 1.0))
        _bar(Rect2(viewport_size.x - 475, 500, 350, 12), name_confirm_hold / maxf(0.1, name_confirm_required), Color(0.1, 0.86, 1.0))
    _text("NO CAMERA IMAGE OR BIOMETRICS ARE SAVED", Vector2(viewport_size.x - 475, 720), 14, Color(0.48, 0.72, 0.84))


func _control_row(rect: Rect2, y: float, action: String, camera: String, fallback: String) -> void:
    _text(action, rect.position + Vector2(30, y), 15, Color(1.0, 0.2, 0.28))
    _text(camera, rect.position + Vector2(190, y), 15, Color.WHITE)
    _text(fallback, rect.position + Vector2(510, y), 14, Color(0.2, 0.78, 1.0))


func _draw_status(viewport_size: Vector2) -> void:
    _text("WEB//PROTOCOL", Vector2(42, 52), 25, Color.WHITE)
    _text(str(state).replace("_", " "), Vector2(42, 88), 18, Color(0.25, 0.72, 1.0))
    _bar(Rect2(42, 130, 280, 14), energy / 100.0, Color(1.0, 0.04, 0.12))
    _text("HERO ENERGY  %d" % int(energy), Vector2(42, 122), 17, Color.WHITE)
    _bar(Rect2(42, 184, 280, 12), web_pressure / 100.0, Color(0.05, 0.72, 1.0))
    _text("WEB PRESSURE  %d" % int(web_pressure), Vector2(42, 178), 16, Color(0.75, 0.9, 1.0))
    _text(tracking, Vector2(42, 222), 15, Color(0.35, 1.0, 0.62) if not tracking_lost else Color(1.0, 0.72, 0.18))
    _text("COLLISIONS  %d/%d" % [collision_strikes, max_collision_strikes], Vector2(42, 249), 15, Color(1.0, 0.25, 0.28) if collision_strikes > 0 else Color(0.68, 0.8, 0.92))
    _text("%06d" % score, Vector2(viewport_size.x - 300, 65), 38, Color.WHITE)
    _text("SCORE  |  x%d COMBO" % combo, Vector2(viewport_size.x - 300, 101), 16, Color(0.55, 0.8, 1.0))
    _text("%02d" % int(maxf(0.0, 90.0 - elapsed)), Vector2(viewport_size.x * 0.5 - 35, 62), 34, Color.WHITE)
    if state in [&"BOSS_COMBAT", &"FINISHER"]:
        _bar(Rect2(viewport_size.x * 0.5 - 260, 110, 520, 15), boss_health / 100.0, Color(0.85, 0.02, 0.22))
        _text_center("THE VOID REGENT", Vector2(viewport_size.x * 0.5, 103), 18, Color.WHITE)


func _draw_context(viewport_size: Vector2) -> void:
    var headline := prompt if not prompt.is_empty() else _default_prompt()
    _panel(Rect2(viewport_size.x * 0.5 - 550, viewport_size.y - 210, 1100, 118), Color(0.005, 0.012, 0.035, 0.92))
    _text_center(headline, Vector2(viewport_size.x * 0.5, viewport_size.y - 165), 25, Color.WHITE)
    var hint := instruction_hint if not instruction_hint.is_empty() else _default_instruction()
    _text_center(hint, Vector2(viewport_size.x * 0.5, viewport_size.y - 126), 17, Color(0.4, 0.85, 1.0))
    if state not in [&"ATTRACT", &"RESULTS"]:
        var feedback := "  |  %s" % shot_feedback if not shot_feedback.is_empty() else ""
        _text_center("BODY: %s  |  LEFT: %s  |  RIGHT: %s%s" % [body_action, gesture_left, gesture_right, feedback], Vector2(viewport_size.x * 0.5, viewport_size.y - 99), 14, Color(0.65, 1.0, 0.72))
    if state == &"FINISHER":
        _bar(Rect2(viewport_size.x * 0.5 - 250, viewport_size.y - 78, 500, 20), tension, Color(1.0, 0.08, 0.18))
        _text_center("WEB TENSION  %d%%" % int(tension * 100.0), Vector2(viewport_size.x * 0.5, viewport_size.y - 84), 17, Color.WHITE)


func _default_prompt() -> String:
    match state:
        &"CALIBRATION": return "LINKING HERO SYSTEMS"
        &"WEB_VERIFICATION": return "AIM WITH BOTH HANDS  |  FIRE ONE WEB"
        &"CHASE": return "DODGE. WEB. PULL."
        &"BOSS_INTRO": return "UNKNOWN ENTITY LOCKED"
        &"BOSS_COMBAT": return "AIM. FIRE. COUNTER."
        &"FINISHER": return "PULL  |  KEEP BOTH WEBS LOCKED"
    return ""


func _default_instruction() -> String:
    match state:
        &"CALIBRATION": return "STAND CENTERED WITH YOUR UPPER BODY AND BOTH HANDS VISIBLE"
        &"WEB_VERIFICATION": return "CLASSIC WEB POSE, PINCH, OR CLENCH A FIST TO FIRE"
        &"CHASE": return "LEAN TO MOVE  |  FOLLOW EACH ACTION PROMPT"
        &"BOSS_COMBAT": return "CENTER BOTH HANDS FOR TARGET LOCK, THEN FIRE"
        &"FINISHER": return "FIRE BOTH WEBS, THEN PULL BOTH ARMS BACK"
    return ""


func _draw_reconnect(viewport_size: Vector2) -> void:
    var rect := Rect2(viewport_size.x * 0.5 - 330, 250, 660, 190)
    _panel(rect, Color(0.01, 0.02, 0.055, 0.97))
    _text_center("CAMERA SIGNAL LOST", Vector2(viewport_size.x * 0.5, 305), 30, Color(1.0, 0.22, 0.28))
    _text_center("RETURN TO THE SCAN ZONE  |  MISSION CLOCK CONTINUES", Vector2(viewport_size.x * 0.5, 349), 17, Color.WHITE)
    _text_center("KEYBOARD BACKUP: A/D MOVE  |  SPACE JUMP  |  MOUSE FIRE", Vector2(viewport_size.x * 0.5, 384), 16, Color(0.4, 0.85, 1.0))
    _text_center("RECONNECTING  %.1fs" % tracking_loss_seconds, Vector2(viewport_size.x * 0.5, 417), 15, Color(1.0, 0.72, 0.18))


func _draw_reticle(viewport_size: Vector2) -> void:
    var point := Vector2(aim.x * viewport_size.x, aim.y * viewport_size.y)
    var color := Color(0.2, 1.0, 0.48) if target_locked else (Color(0.1, 0.8, 1.0) if web_pressure > 20.0 else Color(1.0, 0.15, 0.2))
    draw_circle(point, 24, Color(color, 0.12), false, 3)
    draw_line(point - Vector2(38, 0), point - Vector2(12, 0), color, 3)
    draw_line(point + Vector2(12, 0), point + Vector2(38, 0), color, 3)
    draw_line(point - Vector2(0, 38), point - Vector2(0, 12), color, 3)
    draw_line(point + Vector2(0, 12), point + Vector2(0, 38), color, 3)
    if target_locked:
        draw_arc(point, 34.0, 0.0, TAU, 32, color, 3.0)
        _text_center("TARGET LOCK", point + Vector2(0, 58), 14, color)


func _draw_webs(viewport_size: Vector2) -> void:
    var target := Vector2(aim.x * viewport_size.x, aim.y * viewport_size.y)
    if web_left:
        _web_line(PackedVector2Array([Vector2(250, viewport_size.y), Vector2(450, viewport_size.y - 280), target]))
    if web_right:
        _web_line(PackedVector2Array([Vector2(viewport_size.x - 250, viewport_size.y), Vector2(viewport_size.x - 450, viewport_size.y - 280), target]))


func _web_line(points: PackedVector2Array) -> void:
    if points.size() < 3:
        return
    var core := PackedVector2Array()
    var left_strand := PackedVector2Array()
    var right_strand := PackedVector2Array()
    var start := points[0]
    var control := points[1]
    var finish := points[2]
    var phase := Time.get_ticks_msec() * 0.018
    for index in range(23):
        var t := float(index) / 22.0
        var inverse := 1.0 - t
        var point := start * inverse * inverse + control * 2.0 * inverse * t + finish * t * t
        var tangent := (control - start) * 2.0 * inverse + (finish - control) * 2.0 * t
        var normal := Vector2(-tangent.y, tangent.x).normalized()
        var vibration := sin(t * 58.0 + phase) * (5.0 * (1.0 - t))
        var width := 7.0 + sin(t * PI) * 5.0
        core.append(point + normal * vibration)
        left_strand.append(point + normal * (width + vibration))
        right_strand.append(point - normal * (width - vibration))
    draw_polyline(core, Color(0.18, 0.55, 0.82, 0.28), 15, true)
    draw_polyline(left_strand, Color(0.7, 0.9, 1.0, 0.62), 2.0, true)
    draw_polyline(right_strand, Color(0.7, 0.9, 1.0, 0.62), 2.0, true)
    draw_polyline(core, Color(0.96, 0.99, 1.0), 4.0, true)
    for index in range(2, core.size() - 2, 3):
        draw_line(left_strand[index], right_strand[index + 1], Color(0.86, 0.97, 1.0, 0.72), 1.5, true)
        draw_line(right_strand[index], left_strand[index + 1], Color(0.86, 0.97, 1.0, 0.6), 1.2, true)
    draw_circle(finish, 12.0, Color(0.86, 0.98, 1.0, 0.35), false, 2.5)
    for angle in range(0, 360, 45):
        var direction := Vector2.RIGHT.rotated(deg_to_rad(angle))
        draw_line(finish + direction * 8.0, finish + direction * 22.0, Color(0.9, 0.98, 1.0, 0.72), 1.5, true)


func _draw_danger(viewport_size: Vector2) -> void:
    if danger_direction == &"center":
        return
    var on_left := danger_direction == &"left"
    var x := 35.0 if on_left else viewport_size.x - 35.0
    var direction := 1.0 if on_left else -1.0
    var pulse := 0.65 + sin(Time.get_ticks_msec() * 0.012) * 0.25
    for index in range(3):
        var inset := float(index) * 22.0
        draw_arc(Vector2(x + direction * inset, viewport_size.y * 0.5), 115.0 + inset, -1.1 if on_left else 2.04, 1.1 if on_left else 4.24, 24, Color(1.0, 0.05, 0.14, pulse - index * 0.15), 8)


func _draw_impact(viewport_size: Vector2) -> void:
    draw_colored_polygon(PackedVector2Array([
        Vector2(viewport_size.x * 0.5 - 290, viewport_size.y * 0.31),
        Vector2(viewport_size.x * 0.5 + 315, viewport_size.y * 0.28),
        Vector2(viewport_size.x * 0.5 + 265, viewport_size.y * 0.43),
        Vector2(viewport_size.x * 0.5 - 320, viewport_size.y * 0.45)
    ]), Color(0.86, 0.02, 0.14, 0.93))
    _text_center(impact_label, Vector2(viewport_size.x * 0.5, viewport_size.y * 0.39), 44, Color.WHITE)


func _draw_toast(viewport_size: Vector2) -> void:
    if state == &"ATTRACT":
        _panel(Rect2(viewport_size.x * 0.5 - 460, 25, 920, 58), Color(0.005, 0.012, 0.035, 0.95))
        _text_center(toast, Vector2(viewport_size.x * 0.5, 63), 16, Color.WHITE)
    else:
        _panel(Rect2(viewport_size.x * 0.5 - 350, 150, 700, 58), Color(0.005, 0.012, 0.035, 0.92))
        _text_center(toast, Vector2(viewport_size.x * 0.5, 188), 18, Color.WHITE)


func _draw_results(viewport_size: Vector2) -> void:
    draw_texture_rect(attract_background, Rect2(Vector2.ZERO, viewport_size), false)
    draw_rect(Rect2(Vector2.ZERO, viewport_size), Color(0.002, 0.008, 0.025, 0.78))
    _text_center("MISSION FAILED" if mission_failed else "MISSION COMPLETE", Vector2(viewport_size.x * 0.5, 175), 64, Color(1.0, 0.12, 0.18) if mission_failed else Color.WHITE)
    _text_center(participant_name if not participant_name.is_empty() else "THE NEON WEAVER", Vector2(viewport_size.x * 0.5, 235), 29, Color(1.0, 0.08, 0.16))
    _panel(Rect2(viewport_size.x * 0.5 - 410, 292, 820, 365), Color(0.015, 0.03, 0.075, 0.96))
    var rows := [
        "TOTAL SCORE          %06d" % score,
        "SPIDER-SENSE         %d%%" % spider_sense_score,
        "WEB ACCURACY         %d%%" % web_accuracy,
        "RESCUES              %d/%d" % [rescues, rescue_goal],
        "PERFECT DODGES       %d" % perfect_dodges,
        "BOSS CONTROL         %d%%" % boss_control_score,
        "FINAL TENSION        %d%%" % int(tension * 100.0),
        "COLLISION STRIKES    %d/%d" % [collision_strikes, max_collision_strikes],
    ]
    for index in rows.size():
        _text(rows[index], Vector2(viewport_size.x * 0.5 - 320, 350 + index * 42), 23, Color.WHITE)
    _text_center("RUN DISQUALIFIED" if mission_failed else _rank_label(), Vector2(viewport_size.x * 0.5, 720), 31, Color(1.0, 0.16, 0.2) if mission_failed else Color(0.1, 0.75, 1.0))
    _text_center("TOO MANY COLLISIONS. TRY AGAIN." if mission_failed else "YOU MASTERED THE WEB.", Vector2(viewport_size.x * 0.5, 805), 25, Color.WHITE)
    _text_center("NOW BUILD THE TECHNOLOGY BEHIND IT.", Vector2(viewport_size.x * 0.5, 850), 22, Color(1.0, 0.15, 0.2))
    _panel(Rect2(70, 310, 400, 330), Color(0.01, 0.02, 0.055, 0.94))
    _text("TOP FIVE TODAY", Vector2(105, 355), 21, Color(0.1, 0.75, 1.0))
    for index in mini(5, leaderboard.size()):
        var entry: Dictionary = leaderboard[index]
        var name := str(entry.get("codename", "Anonymous Hero"))
        _text("%d  %s" % [index + 1, name.left(18)], Vector2(105, 405 + index * 40), 17, Color.WHITE)
        _text("%06d" % int(entry.get("score", 0)), Vector2(360, 405 + index * 40), 17, Color(1.0, 0.82, 0.18))
    var rank_text := "NO RANK - RUN FAILED" if mission_failed else "YOUR RANK  #%d" % daily_rank
    _text("PLAYERS TODAY  %d  |  %s" % [leaderboard.size(), rank_text], Vector2(105, 615), 15, Color(0.68, 0.8, 0.92))
    _panel(Rect2(viewport_size.x - 390, 310, 270, 330), Color(1.0, 1.0, 1.0, 0.96))
    draw_texture_rect(recruitment_qr, Rect2(viewport_size.x - 370, 330, 230, 230), false)
    var qr_label := "SCAN TO BUILD THE FUTURE" if recruitment_qr_ready else "EVENT QR NOT CONFIGURED"
    _text_center(qr_label, Vector2(viewport_size.x - 255, 605), 15, Color(0.02, 0.04, 0.1))
    _text_center("DAILY HIGH  %06d" % high_score, Vector2(viewport_size.x * 0.5, 912), 18, Color(1.0, 0.82, 0.18))


func _rank_label() -> String:
    if score >= 26000: return "ULTIMATE WEB WARRIOR"
    if score >= 19000: return "SPIDER-SENSE ELITE"
    if score >= 13000: return "WEB SPECIALIST"
    if score >= 7000: return "CITY SWINGER"
    return "ROOFTOP ROOKIE"

func _draw_diagnostics() -> void:
    var rect := Rect2(25, 545, 910, 500)
    _panel(rect, Color(0, 0, 0, 0.90))
    _text("DIAGNOSTICS", Vector2(50, 585), 21, Color(0.1, 0.8, 1.0))
    _text("RENDER", Vector2(50, 625), 16, Color(1.0, 0.2, 0.28))
    _text("FPS %.1f  |  FRAME %.2f ms" % [fps, 1000.0 / maxf(1.0, fps)], Vector2(50, 655), 16, Color.WHITE)
    _text("QUALITY %s  |  MEMORY %.0f MB" % [quality_mode, memory_mb], Vector2(50, 685), 16, Color.WHITE)
    _text("PARTICLES %d  |  POOL %d" % [active_particles, pool_usage], Vector2(50, 715), 16, Color.WHITE)
    _text("VISION", Vector2(50, 755), 16, Color(1.0, 0.2, 0.28))
    _text("CAM %.1f  |  POSE %.1f  |  HAND %.1f" % [camera_fps, pose_fps, hand_fps], Vector2(50, 785), 16, Color.WHITE)
    _text("PACKETS %.1f/s  |  AGE %.0f ms" % [packet_rate, packet_age_ms], Vector2(50, 815), 16, Color.WHITE)
    _text("POSE %.0f%%  |  HAND %.0f%%" % [pose_confidence * 100.0, hand_confidence * 100.0], Vector2(50, 845), 16, Color.WHITE)
    _text("GAMEPLAY", Vector2(500, 625), 16, Color(0.1, 0.8, 1.0))
    _text("STATE %s  |  %.2fs" % [state, elapsed], Vector2(500, 655), 16, Color.WHITE)
    _text("BODY %s" % body_action, Vector2(500, 685), 16, Color.WHITE)
    _text("HANDS %s" % hand_action, Vector2(500, 715), 16, Color.WHITE)
    _text("AIM %.2f, %.2f" % [aim.x, aim.y], Vector2(500, 745), 16, Color.WHITE)
    _text("ZONE %s" % ("LEFT" if aim.x < 0.4 else "RIGHT" if aim.x > 0.6 else "CENTER"), Vector2(500, 775), 16, Color.WHITE)
    _text("ENERGY %.0f  |  WEB %.0f" % [energy, web_pressure], Vector2(500, 805), 16, Color.WHITE)
    _text("BOSS %.0f  |  ASSIST %.0f%%" % [boss_health, assist_level * 100.0], Vector2(500, 835), 16, Color.WHITE)
    _text(tracking, Vector2(500, 875), 16, Color(0.4, 1.0, 0.6))

func _draw_operator(viewport_size: Vector2) -> void:
    draw_rect(Rect2(Vector2.ZERO, viewport_size), Color(0, 0, 0, 0.72))
    var rect := Rect2(viewport_size.x * 0.5 - 440, 55, 880, 960)
    _panel(rect, Color(0.008, 0.016, 0.045, 0.985))
    _text("OPERATOR CONTROL", rect.position + Vector2(42, 58), 34, Color.WHITE)
    _text("PAGE %d / 2  |  TAB NEXT" % (operator_page + 1), rect.position + Vector2(570, 55), 17, Color(0.2, 0.78, 1.0))
    if operator_page == 0:
        _text("CAMERA / DISPLAY / AUDIO", rect.position + Vector2(42, 108), 18, Color(1.0, 0.18, 0.24))
        _operator_row(rect, 155, "Camera selector", "PREVIOUS / NEXT", "F5 / F6")
        _operator_row(rect, 205, "Refresh cameras", "RESCAN + RESTART", "F7")
        _operator_row(rect, 255, "Restart camera", "SAFE RECONNECT", "F7")
        _operator_row(rect, 305, "Mirror camera", "TOGGLE", "F8")
        _operator_row(rect, 355, "Input mode", "KEYBOARD / CAMERA", "F4")
        _operator_row(rect, 405, "Fullscreen", "TOGGLE", "F11")
        _operator_row(rect, 455, "Resolution", "1920 x 1080", "FIXED")
        _operator_row(rect, 505, "VSync", "TOGGLE", "F9")
        _operator_row(rect, 555, "Graphics quality", "HIGH / AUTO", "FPS SAFE")
        _operator_row(rect, 605, "VFX quality", "HIGH / AUTO", "FPS SAFE")
        _operator_row(rect, 655, "Master volume", "MUTE / UNMUTE", "M")
        _operator_row(rect, 705, "Music volume", "-10 dB", "CONFIG")
        _operator_row(rect, 755, "Effects volume", "-4 dB", "CONFIG")
        _operator_row(rect, 805, "Show skeleton", "PRIVACY SAFE / OFF", "CONFIG")
        _operator_row(rect, 855, "Diagnostics", "VISIBLE" if diagnostics_visible else "HIDDEN", "F3")
    else:
        _text("INPUT TUNING / SESSION", rect.position + Vector2(42, 108), 18, Color(0.2, 0.78, 1.0))
        _operator_row(rect, 155, "Lean sensitivity", "0.075", "YAML")
        _operator_row(rect, 205, "Jump sensitivity", "0.100", "YAML")
        _operator_row(rect, 255, "Crouch sensitivity", "0.120", "YAML")
        _operator_row(rect, 305, "Dodge sensitivity", "0.850", "YAML")
        _operator_row(rect, 355, "Web trigger", "POSE + PINCH + RELEASE", "AUTO")
        _operator_row(rect, 405, "Web threshold", "80 ms", "YAML")
        _operator_row(rect, 455, "Aim smoothing", "32%", "YAML")
        _operator_row(rect, 505, "Web endurance assist", "%d%% ADAPTIVE" % int(assist_level * 100.0), "AUTO")
        _operator_row(rect, 555, "Pull sensitivity", "0.160", "YAML")
        _operator_row(rect, 605, "Boss completion", "TIMED ASSIST", "AUTO")
        _operator_row(rect, 655, "Reset session", "START CALIBRATION", "R")
        _operator_row(rect, 705, "Recalibrate", "CLEAR PROFILE", "C")
        _operator_row(rect, 755, "Skip to boss", "OPERATOR ONLY", "B")
        _operator_row(rect, 805, "Return to attract", "RESET ALL SESSION STATE", "HOME")
        _operator_row(rect, 855, "Clear leaderboard", "CONFIRMATION REQUIRED", "DELETE")
    _text("QUIT  CTRL+SHIFT+Q  |  ESC CLOSE", rect.position + Vector2(42, 925), 17, Color(0.78, 0.84, 0.94))

func _operator_row(rect: Rect2, y: float, label: String, value: String, key: String) -> void:
    draw_line(rect.position + Vector2(42, y + 15), rect.position + Vector2(rect.size.x - 42, y + 15), Color(0.12, 0.16, 0.24), 1)
    _text(label, rect.position + Vector2(42, y), 18, Color.WHITE)
    _text(value, rect.position + Vector2(300, y), 18, Color(0.65, 0.85, 1.0))
    _text(key, rect.position + Vector2(620, y), 16, Color(1.0, 0.24, 0.3))


func _draw_clear_confirmation(viewport_size: Vector2) -> void:
    draw_rect(Rect2(Vector2.ZERO, viewport_size), Color(0, 0, 0, 0.84))
    _panel(Rect2(viewport_size.x * 0.5 - 330, viewport_size.y * 0.5 - 125, 660, 250), Color(0.01, 0.02, 0.05, 0.99))
    _text_center("CLEAR LOCAL LEADERBOARD?", Vector2(viewport_size.x * 0.5, viewport_size.y * 0.5 - 48), 29, Color.WHITE)
    _text_center("THIS CANNOT BE UNDONE", Vector2(viewport_size.x * 0.5, viewport_size.y * 0.5 - 2), 18, Color(1.0, 0.2, 0.26))
    _text_center("Y  CONFIRM    |    ESC  CANCEL", Vector2(viewport_size.x * 0.5, viewport_size.y * 0.5 + 62), 20, Color.WHITE)

func _draw_quit_confirmation(viewport_size: Vector2) -> void:
    draw_rect(Rect2(Vector2.ZERO, viewport_size), Color(0, 0, 0, 0.82))
    _panel(Rect2(viewport_size.x * 0.5 - 300, viewport_size.y * 0.5 - 120, 600, 240), Color(0.01, 0.02, 0.05, 0.98))
    _text_center("QUIT WEB//PROTOCOL?", Vector2(viewport_size.x * 0.5, viewport_size.y * 0.5 - 45), 31, Color.WHITE)
    _text_center("Y  CONFIRM    |    ESC  CANCEL", Vector2(viewport_size.x * 0.5, viewport_size.y * 0.5 + 35), 21, Color(1.0, 0.22, 0.28))


func _bar(rect: Rect2, value: float, color: Color) -> void:
    draw_rect(rect, Color(0.08, 0.1, 0.16, 0.9))
    draw_rect(Rect2(rect.position, Vector2(rect.size.x * clampf(value, 0.0, 1.0), rect.size.y)), color)


func _panel(rect: Rect2, color: Color) -> void:
    draw_rect(rect, color)
    draw_line(rect.position, rect.position + Vector2(rect.size.x, 0), Color(0.12, 0.68, 1.0), 3)


func _text(value: String, position: Vector2, font_size: int, color: Color) -> void:
    draw_string(ThemeDB.fallback_font, position, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _text_center(value: String, position: Vector2, font_size: int, color: Color) -> void:
    var width := ThemeDB.fallback_font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
    _text(value, position - Vector2(width * 0.5, 0), font_size, color)
