class_name GameHud
extends Control

const ATTRACT_TITLE_TOP := 158.0
const RESULTS_TITLE_TOP := 150.0

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
var vision_receiver_ready := true
var vision_receiver_error := 0
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
var ready_hold_seconds := 0.0
var ready_hold_required := 3.0
var rescue_goal := 1
var high_score := 0
var leaderboard: Array = []
var daily_rank := 0
var attract_background: Texture2D = preload("res://assets/generated/attract_city.png")
var hero_emblem: Texture2D = preload("res://assets/branding/hero_emblem.png")
var recruitment_qr: Texture2D = preload("res://assets/branding/recruitment_qr.png")
var recruitment_qr_ready := FileAccess.file_exists("res://assets/branding/recruitment_qr.ready")
var hud_font: Font = preload("res://assets/fonts/Oxanium.ttf")
var gdg_logo_horizontal: Texture2D = preload("res://assets/branding/gdg/gdg_logo_horizontal.png")
var gdg_logo_stacked: Texture2D = preload("res://assets/branding/gdg/gdg_logo.png")


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
    draw_rect(Rect2(0, 0, viewport_size.x, 5), Color(0.12, 0.82, 1.0, 0.88))
    draw_rect(Rect2(0, viewport_size.y - 5, viewport_size.x, 5), Color(0.48, 0.96, 0.28, 0.82))
    draw_colored_polygon(PackedVector2Array([
        Vector2(0, 0), Vector2(430, 0), Vector2(315, 195), Vector2(0, 220)
    ]), Color(0.004, 0.012, 0.03, 0.88))
    draw_colored_polygon(PackedVector2Array([
        Vector2(viewport_size.x, viewport_size.y),
        Vector2(viewport_size.x - 450, viewport_size.y),
        Vector2(viewport_size.x - 320, viewport_size.y - 120),
        Vector2(viewport_size.x, viewport_size.y - 175)
    ]), Color(0.005, 0.012, 0.035, 0.92))

static func attract_brand_rect() -> Rect2:
    return Rect2(82, 28, 520, 112)


static func results_brand_rect(viewport_size: Vector2) -> Rect2:
    return Rect2(viewport_size.x * 0.5 - 210, 20, 420, 88)


func _draw_brand_banner(rect: Rect2) -> void:
    draw_rect(rect, Color(0.96, 0.98, 1.0, 0.96))
    draw_rect(rect, Color(0.18, 0.82, 1.0, 0.92), false, 2.0)
    var target := rect.grow(-12.0)
    var source_size := gdg_logo_horizontal.get_size()
    var image_scale := minf(target.size.x / source_size.x, target.size.y / source_size.y)
    var image_size := source_size * image_scale
    var image_rect := Rect2(target.position + (target.size - image_size) * 0.5, image_size)
    draw_texture_rect(gdg_logo_horizontal, image_rect, false)

func _draw_attract(viewport_size: Vector2) -> void:
    draw_texture_rect(attract_background, Rect2(Vector2.ZERO, viewport_size), false)
    draw_rect(Rect2(Vector2.ZERO, viewport_size), Color(0.002, 0.008, 0.025, 0.30))
    draw_colored_polygon(PackedVector2Array([
        Vector2(0, 0), Vector2(viewport_size.x * 0.59, 0),
        Vector2(viewport_size.x * 0.48, viewport_size.y), Vector2(0, viewport_size.y)
    ]), Color(0.002, 0.006, 0.02, 0.76))
    _draw_brand_banner(attract_brand_rect())

    _text("WEB//PROTOCOL", Vector2(105, 240), 82, Color.WHITE)
    _text("SPIDER-SENSE", Vector2(111, 312), 39, Color(1.0, 0.08, 0.16))
    draw_line(Vector2(108, 345), Vector2(780, 345), Color(0.02, 0.72, 1.0), 5)
    _text("YOUR BODY IS THE CONTROLLER", Vector2(111, 392), 28, Color(0.72, 0.86, 1.0))
    _text("STEP INTO THE SCAN ZONE", Vector2(111, 454), 43, Color.WHITE)
    var can_start := keyboard_mode or (camera_ready and player_tracked and hands_ready)
    var start_color := Color(0.03, 0.42, 0.58, 0.96) if can_start else Color(0.025, 0.10, 0.18, 0.96)
    _panel(Rect2(108, 535, 560, 88), start_color)
    if keyboard_mode:
        _text("START MISSION  [ENTER]", Vector2(142, 593), 26, Color.WHITE)
    elif can_start:
        _text("MISSION LOCK ACQUIRED", Vector2(142, 593), 25, Color.WHITE)
    elif camera_ready and player_tracked:
        _text("OPEN PALMS  %.1f / %.1f SEC" % [ready_hold_seconds, ready_hold_required], Vector2(142, 593), 23, Color.WHITE)
    elif camera_ready:
        _text("STEP INTO FRAME TO BEGIN", Vector2(142, 593), 25, Color.WHITE)
    elif not vision_receiver_ready:
        _text("INPUT LINK ERROR", Vector2(142, 593), 25, Color.WHITE)
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
    var label := "KEYBOARD READY" if keyboard_mode else "INPUT LINK ERROR" if not vision_receiver_ready else "CAMERA READY" if camera_ready else "CAMERA OFFLINE"
    var status_color := Color(0.25, 1.0, 0.55) if keyboard_mode or (camera_ready and player_tracked and hands_ready) else Color(1.0, 0.72, 0.18) if camera_ready else Color(1.0, 0.2, 0.28)
    _text(label, rect.position + Vector2(28, 78), 25, status_color)
    if keyboard_mode:
        _text("A/D MOVE  |  MOUSE AIM + FIRE", rect.position + Vector2(28, 116), 17, Color.WHITE)
        _text("SPACE JUMP  |  S CROUCH  |  F SHIELD", rect.position + Vector2(28, 146), 16, Color(0.72, 0.86, 1.0))
    elif camera_ready and player_tracked and hands_ready:
        _text("PLAYER TRACKED  |  OPEN-PALM LOCK COMPLETE", rect.position + Vector2(28, 116), 16, Color.WHITE)
        _text("STARTING MISSION", rect.position + Vector2(28, 146), 16, Color(0.72, 0.86, 1.0))
    elif camera_ready and player_tracked:
        _text("BODY READY  |  HANDS %d/2" % hand_count, rect.position + Vector2(28, 116), 17, Color.WHITE)
        _text("HOLD BOTH OPEN PALMS FOR THREE SECONDS", rect.position + Vector2(28, 146), 15, Color(0.72, 0.86, 1.0))
    elif camera_ready:
        _text("STAND CENTERED, FACING THE CAMERA", rect.position + Vector2(28, 116), 17, Color.WHITE)
        _text("KEEP YOUR UPPER BODY + HANDS VISIBLE", rect.position + Vector2(28, 146), 16, Color(0.72, 0.86, 1.0))
    elif not vision_receiver_ready:
        _text("GAME INPUT RECEIVER UNAVAILABLE", rect.position + Vector2(28, 116), 17, Color.WHITE)
        _text("RESTART WITH python main.py  |  ERROR %d" % vision_receiver_error, rect.position + Vector2(28, 146), 15, Color(0.72, 0.86, 1.0))
    else:
        var offline_help := "CAMERA SERVICE RECONNECTING" if vision_managed else "START THE GAME USING run.bat"
        _text(offline_help, rect.position + Vector2(28, 116), 18, Color.WHITE)
        _text("OR PRESS F4 FOR KEYBOARD MODE", rect.position + Vector2(28, 146), 16, Color(0.72, 0.86, 1.0))


func _draw_quick_controls(viewport_size: Vector2) -> void:
    var rect := Rect2(viewport_size.x - 690, 610, 620, 405)
    _panel(rect, Color(0.005, 0.016, 0.045, 0.94))
    _text("HOW TO PLAY", rect.position + Vector2(30, 42), 24, Color.WHITE)
    _control_row(rect, 88, "AIM", "CENTER BOTH HANDS ON THE TARGET", "MOVE MOUSE")
    _control_row(rect, 145, "FIRE / ATTACK", "INDEX + PINKY OUT; MIDDLE + RING IN", "MOUSE CLICK")
    _control_row(rect, 202, "PULL", "FIRE, CLOSE FIST + PULL BACK", "MOUSE + P")
    _control_row(rect, 259, "DODGE / MOVE", "LEAN OR STEP LEFT / RIGHT", "A / D")
    _control_row(rect, 316, "JUMP / CROUCH", "JUMP UP / CROUCH LOW", "SPACE / S")
    _control_row(rect, 373, "SHIELD", "RAISE BOTH FOREARMS", "F")


func _control_row(rect: Rect2, y: float, action: String, camera: String, fallback: String) -> void:
    _text(action, rect.position + Vector2(30, y), 15, Color(0.48, 0.96, 0.28))
    _text(camera, rect.position + Vector2(190, y), 15, Color.WHITE)
    _text(fallback, rect.position + Vector2(510, y), 14, Color(0.2, 0.78, 1.0))


func _draw_status(viewport_size: Vector2) -> void:
    var player_rect := Rect2(28, 24, 370, 174)
    _panel(player_rect, Color(0.004, 0.018, 0.038, 0.94))
    _text("SPIDER-MAN", player_rect.position + Vector2(20, 32), 19, Color(0.74, 0.92, 1.0))
    _text("HEALTH  %03d" % int(energy), player_rect.position + Vector2(20, 61), 15, Color.WHITE)
    _bar(Rect2(player_rect.position + Vector2(20, 72), Vector2(330, 17)), energy / 100.0, Color(0.34, 0.94, 0.42))
    _text("WEB  %03d" % int(web_pressure), player_rect.position + Vector2(20, 112), 14, Color(0.68, 0.9, 1.0))
    _bar(Rect2(player_rect.position + Vector2(20, 122), Vector2(330, 12)), web_pressure / 100.0, Color(0.12, 0.72, 1.0))
    _text(tracking, player_rect.position + Vector2(20, 158), 13, Color(0.38, 1.0, 0.62) if not tracking_lost else Color(1.0, 0.72, 0.18))
    _text("HITS %d/%d" % [collision_strikes, max_collision_strikes], player_rect.position + Vector2(258, 158), 13, Color(1.0, 0.72, 0.18) if collision_strikes > 0 else Color(0.68, 0.8, 0.92))

    _text_center("%02d" % int(maxf(0.0, 90.0 - elapsed)), Vector2(viewport_size.x * 0.5, 64), 38, Color.WHITE)
    _text_center(str(state).replace("_", " "), Vector2(viewport_size.x * 0.5, 96), 15, Color(0.34, 0.84, 1.0))
    _text_center("SCORE %06d  //  x%d" % [score, combo], Vector2(viewport_size.x * 0.5, 130), 17, Color(0.76, 0.9, 1.0))

    var boss_rect := Rect2(viewport_size.x - 568, 24, 540, 174)
    var boss_live := state in [&"BOSS_INTRO", &"BOSS_COMBAT", &"FINISHER"]
    _panel(boss_rect, Color(0.008, 0.018, 0.035, 0.95))
    _text("GREEN GOBLIN", boss_rect.position + Vector2(20, 34), 20, Color(0.66, 1.0, 0.34) if boss_live else Color(0.58, 0.67, 0.72))
    _text("BOSS HEALTH  %03d" % int(boss_health), boss_rect.position + Vector2(20, 68), 15, Color.WHITE if boss_live else Color(0.58, 0.67, 0.72))
    _bar(Rect2(boss_rect.position + Vector2(20, 80), Vector2(500, 20)), boss_health / 100.0, Color(0.55, 0.9, 0.2) if boss_live else Color(0.23, 0.3, 0.34))
    _text("AIRBORNE THREAT" if boss_live else "SIGNAL LOCKED // INCOMING", boss_rect.position + Vector2(20, 130), 14, Color(0.72, 0.5, 1.0) if boss_live else Color(0.48, 0.58, 0.64))
    _text("TENSION %03d" % int(tension * 100.0), boss_rect.position + Vector2(392, 158), 13, Color(0.74, 0.9, 1.0))

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
        _bar(Rect2(viewport_size.x * 0.5 - 250, viewport_size.y - 78, 500, 20), tension, Color(0.58, 0.9, 0.24))
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
        &"WEB_VERIFICATION": return "INDEX + PINKY OUT; FOLD MIDDLE + RING TO FIRE"
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
    var color := Color(0.2, 1.0, 0.48) if target_locked else (Color(0.1, 0.8, 1.0) if web_pressure > 20.0 else Color(0.48, 0.96, 0.28))
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
    ]), Color(0.006, 0.025, 0.05, 0.94))
    draw_line(Vector2(viewport_size.x * 0.5 - 290, viewport_size.y * 0.31), Vector2(viewport_size.x * 0.5 + 315, viewport_size.y * 0.28), Color(0.2, 0.86, 1.0), 4.0)
    draw_line(Vector2(viewport_size.x * 0.5 - 320, viewport_size.y * 0.45), Vector2(viewport_size.x * 0.5 + 265, viewport_size.y * 0.43), Color(0.48, 0.96, 0.28), 3.0)
    _text_center(impact_label, Vector2(viewport_size.x * 0.5, viewport_size.y * 0.39), 44, Color.WHITE)


func _draw_toast(viewport_size: Vector2) -> void:
    if state == &"ATTRACT":
        _panel(Rect2(viewport_size.x * 0.5 - 460, 25, 920, 58), Color(0.005, 0.012, 0.035, 0.95))
        _text_center(toast, Vector2(viewport_size.x * 0.5, 63), 16, Color.WHITE)
    else:
        _panel(Rect2(viewport_size.x * 0.5 - 350, 212, 700, 58), Color(0.005, 0.012, 0.035, 0.92))
        _text_center(toast, Vector2(viewport_size.x * 0.5, 250), 18, Color.WHITE)


func _draw_results(viewport_size: Vector2) -> void:
    draw_texture_rect(attract_background, Rect2(Vector2.ZERO, viewport_size), false)
    draw_rect(Rect2(Vector2.ZERO, viewport_size), Color(0.002, 0.008, 0.025, 0.78))
    _draw_brand_banner(results_brand_rect(viewport_size))

    _text_center("MISSION FAILED" if mission_failed else "MISSION COMPLETE", Vector2(viewport_size.x * 0.5, 215), 58, Color(1.0, 0.32, 0.24) if mission_failed else Color.WHITE)
    _panel(Rect2(viewport_size.x * 0.5 - 410, 270, 820, 365), Color(0.015, 0.03, 0.075, 0.96))
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
        _text(rows[index], Vector2(viewport_size.x * 0.5 - 320, 328 + index * 42), 23, Color.WHITE)
    _text_center("RUN DISQUALIFIED" if mission_failed else _rank_label(), Vector2(viewport_size.x * 0.5, 700), 31, Color(1.0, 0.52, 0.22) if mission_failed else Color(0.2, 0.88, 1.0))
    _text_center("TOO MANY COLLISIONS. TRY AGAIN." if mission_failed else "YOU MASTERED THE WEB.", Vector2(viewport_size.x * 0.5, 805), 25, Color.WHITE)
    _text_center("NOW BUILD THE TECHNOLOGY BEHIND IT.", Vector2(viewport_size.x * 0.5, 850), 22, Color(0.48, 0.96, 0.28))
    _panel(Rect2(70, 310, 400, 330), Color(0.01, 0.02, 0.055, 0.94))
    _text("TOP FIVE TODAY", Vector2(105, 355), 21, Color(0.1, 0.75, 1.0))
    for index in mini(5, leaderboard.size()):
        var entry: Dictionary = leaderboard[index]
        _text("RUN %d" % (index + 1), Vector2(105, 405 + index * 40), 17, Color.WHITE)
        _text("%06d" % int(entry.get("score", 0)), Vector2(360, 405 + index * 40), 17, Color(1.0, 0.82, 0.18))
    var rank_text := "NO RANK - RUN FAILED" if mission_failed else "YOUR RANK  #%d" % daily_rank
    _text("PLAYERS TODAY  %d  |  %s" % [leaderboard.size(), rank_text], Vector2(105, 615), 15, Color(0.68, 0.8, 0.92))
    _panel(Rect2(viewport_size.x - 390, 310, 270, 330), Color(1.0, 1.0, 1.0, 0.96))
    var recruitment_rect := Rect2(viewport_size.x - 370, 330, 230, 230)
    if recruitment_qr_ready:
        draw_texture_rect(recruitment_qr, recruitment_rect, false)
    else:
        var logo_size := gdg_logo_stacked.get_size()
        var logo_scale := minf(recruitment_rect.size.x / logo_size.x, recruitment_rect.size.y / logo_size.y)
        var contained_size := logo_size * logo_scale
        draw_texture_rect(
            gdg_logo_stacked,
            Rect2(recruitment_rect.position + (recruitment_rect.size - contained_size) * 0.5, contained_size),
            false
        )
    var qr_label := "SCAN TO BUILD THE FUTURE" if recruitment_qr_ready else "GDG ON CAMPUS"
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
        _operator_row(rect, 355, "Web trigger", "CLASSIC WEB POSE + RELEASE", "AUTO")
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
    draw_rect(rect, Color(0.018, 0.035, 0.055, 0.96))
    draw_rect(rect, Color(0.22, 0.38, 0.48, 0.72), false, 1.0)
    var inset := Rect2(rect.position + Vector2(2, 2), rect.size - Vector2(4, 4))
    var fill_width := inset.size.x * clampf(value, 0.0, 1.0)
    if fill_width > 0.0:
        var fill := Rect2(inset.position, Vector2(fill_width, inset.size.y))
        draw_rect(fill, color)
        draw_line(fill.position + Vector2(0, 1), fill.position + Vector2(fill.size.x, 1), color.lightened(0.35), 1.0)
    for marker in range(1, 5):
        var x := rect.position.x + rect.size.x * float(marker) / 5.0
        draw_line(Vector2(x, rect.position.y + 2), Vector2(x, rect.end.y - 2), Color(0.01, 0.02, 0.03, 0.34), 1.0)


func _panel(rect: Rect2, color: Color) -> void:
    draw_rect(rect, color)
    draw_rect(rect, Color(0.12, 0.42, 0.55, 0.72), false, 1.0)
    draw_line(rect.position, rect.position + Vector2(72, 0), Color(0.18, 0.82, 1.0), 3.0)
    draw_line(rect.end - Vector2(72, 0), rect.end, Color(0.48, 0.96, 0.28), 2.0)


func _text(value: String, position: Vector2, font_size: int, color: Color) -> void:
    var luminance := color.r * 0.21 + color.g * 0.72 + color.b * 0.07
    if luminance > 0.3:
        var glow := Color(color.r, color.g, color.b, 0.18)
        if font_size >= 18:
            draw_string(hud_font, position + Vector2(-1, 0), value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, glow)
            draw_string(hud_font, position + Vector2(1, 0), value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, glow)
            draw_string(hud_font, position + Vector2(0, -1), value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, glow)
        draw_string(hud_font, position + Vector2(2, 2), value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0, 0, 0, 0.78))
    draw_string(hud_font, position, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _text_center(value: String, position: Vector2, font_size: int, color: Color) -> void:
    var width := hud_font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
    _text(value, position - Vector2(width * 0.5, 0), font_size, color)
