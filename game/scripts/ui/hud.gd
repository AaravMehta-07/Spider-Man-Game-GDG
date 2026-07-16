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
var tracking := "KEYBOARD READY"
var diagnostics_visible := false
var packet_rate := 0.0
var fps := 60.0
var flash := 0.0
var web_left := false
var web_right := false
var aim := Vector2(0.5, 0.5)


func _process(delta: float) -> void:
    flash = maxf(0.0, flash - delta * 2.2)
    queue_redraw()


func _draw() -> void:
    var viewport_size := size
    _draw_vignette(viewport_size)
    if state == &"ATTRACT":
        _draw_attract(viewport_size)
        return
    if state == &"RESULTS":
        _draw_results(viewport_size)
        return
    _draw_status(viewport_size)
    _draw_context(viewport_size)
    _draw_reticle(viewport_size)
    _draw_webs(viewport_size)
    if diagnostics_visible:
        _draw_diagnostics()
    if flash > 0.0:
        draw_rect(Rect2(Vector2.ZERO, viewport_size), Color(1.0, 0.05, 0.12, flash * 0.22))


func _draw_vignette(viewport_size: Vector2) -> void:
    draw_rect(Rect2(0, 0, viewport_size.x, 10), Color(0.9, 0.02, 0.12))
    draw_rect(Rect2(0, viewport_size.y - 10, viewport_size.x, 10), Color(0.02, 0.55, 0.95))
    draw_colored_polygon(PackedVector2Array([
        Vector2(0, 0), Vector2(420, 0), Vector2(290, 125), Vector2(0, 180)
    ]), Color(0.01, 0.018, 0.045, 0.94))
    draw_colored_polygon(PackedVector2Array([
        Vector2(viewport_size.x, viewport_size.y),
        Vector2(viewport_size.x - 450, viewport_size.y),
        Vector2(viewport_size.x - 320, viewport_size.y - 120),
        Vector2(viewport_size.x, viewport_size.y - 175)
    ]), Color(0.01, 0.018, 0.045, 0.94))


func _draw_attract(viewport_size: Vector2) -> void:
    draw_rect(Rect2(Vector2.ZERO, viewport_size), Color(0.002, 0.008, 0.025, 0.46))
    _text("WEB//PROTOCOL", Vector2(110, 220), 92, Color.WHITE)
    _text("SPIDER-SENSE", Vector2(116, 300), 42, Color(1.0, 0.08, 0.16))
    draw_line(Vector2(110, 335), Vector2(880, 335), Color(0.02, 0.65, 1.0), 5)
    _text("YOUR BODY IS THE CONTROLLER", Vector2(116, 405), 30, Color(0.72, 0.84, 1.0))
    _text("STEP INTO THE SCAN ZONE", Vector2(116, 468), 46, Color.WHITE)
    _panel(Rect2(112, 555, 480, 92), Color(0.82, 0.02, 0.12, 0.92))
    _text("BEGIN MISSION  [ENTER]", Vector2(148, 615), 28, Color.WHITE)
    _text("DODGE THE CITY   •   MASTER THE WEB   •   DEFEAT THE UNSEEN", Vector2(112, 790), 25, Color(0.55, 0.8, 1.0))
    _text("ONE PLAYER  •  90 SECONDS  •  NO CONTROLLER", Vector2(112, 855), 22, Color(0.72, 0.74, 0.8))
    _text("DAILY HIGH SCORE  24,850", Vector2(viewport_size.x - 470, 115), 23, Color(1.0, 0.82, 0.18))


func _draw_status(viewport_size: Vector2) -> void:
    _text("WEB//PROTOCOL", Vector2(42, 52), 25, Color.WHITE)
    _text(str(state).replace("_", " "), Vector2(42, 88), 18, Color(0.25, 0.72, 1.0))
    _bar(Rect2(42, 130, 280, 14), energy / 100.0, Color(1.0, 0.04, 0.12))
    _text("HERO ENERGY  %d" % int(energy), Vector2(42, 122), 17, Color.WHITE)
    _bar(Rect2(42, 184, 280, 12), web_pressure / 100.0, Color(0.05, 0.72, 1.0))
    _text("WEB PRESSURE  %d" % int(web_pressure), Vector2(42, 178), 16, Color(0.75, 0.9, 1.0))
    _text("%06d" % score, Vector2(viewport_size.x - 300, 65), 38, Color.WHITE)
    _text("SCORE  •  x%d COMBO" % combo, Vector2(viewport_size.x - 300, 101), 16, Color(0.55, 0.8, 1.0))
    _text("%02d" % int(maxf(0.0, 90.0 - elapsed)), Vector2(viewport_size.x * 0.5 - 35, 62), 34, Color.WHITE)
    if state in [&"BOSS_COMBAT", &"FINISHER"]:
        _bar(Rect2(viewport_size.x * 0.5 - 260, 110, 520, 15), boss_health / 100.0, Color(0.85, 0.02, 0.22))
        _text("THE VEIL", Vector2(viewport_size.x * 0.5 - 54, 103), 18, Color.WHITE)


func _draw_context(viewport_size: Vector2) -> void:
    var headline := prompt
    if headline.is_empty():
        headline = _default_prompt()
    _panel(Rect2(viewport_size.x * 0.5 - 330, viewport_size.y - 178, 660, 82), Color(0.005, 0.012, 0.035, 0.88))
    _text_center(headline, Vector2(viewport_size.x * 0.5, viewport_size.y - 127), 31, Color.WHITE)
    if state == &"FINISHER":
        _bar(Rect2(viewport_size.x * 0.5 - 250, viewport_size.y - 78, 500, 20), tension, Color(1.0, 0.08, 0.18))
        _text_center("WEB TENSION  %d%%" % int(tension * 100.0), Vector2(viewport_size.x * 0.5, viewport_size.y - 84), 17, Color.WHITE)


func _default_prompt() -> String:
    match state:
        &"CALIBRATION": return "LINKING HERO SYSTEMS"
        &"WEB_VERIFICATION": return "AIM WITH YOUR HAND  •  FIRE ONE WEB"
        &"CHASE": return "DODGE. WEB. PULL."
        &"BOSS_INTRO": return "UNKNOWN ENTITY LOCKED"
        &"BOSS_COMBAT": return "SPIDER-SENSE  •  COUNTER WINDOW"
        &"FINISHER": return "PULL  •  KEEP BOTH WEBS LOCKED"
    return ""


func _draw_reticle(viewport_size: Vector2) -> void:
    var point := Vector2(aim.x * viewport_size.x, aim.y * viewport_size.y)
    var color := Color(0.1, 0.8, 1.0) if web_pressure > 20.0 else Color(1.0, 0.15, 0.2)
    draw_circle(point, 24, Color(color, 0.12), false, 3)
    draw_line(point - Vector2(38, 0), point - Vector2(12, 0), color, 3)
    draw_line(point + Vector2(12, 0), point + Vector2(38, 0), color, 3)
    draw_line(point - Vector2(0, 38), point - Vector2(0, 12), color, 3)
    draw_line(point + Vector2(0, 12), point + Vector2(0, 38), color, 3)


func _draw_webs(viewport_size: Vector2) -> void:
    var target := Vector2(aim.x * viewport_size.x, aim.y * viewport_size.y)
    if web_left:
        draw_polyline(PackedVector2Array([Vector2(250, viewport_size.y), Vector2(450, viewport_size.y - 280), target]), Color(0.8, 0.95, 1.0), 5, true)
    if web_right:
        draw_polyline(PackedVector2Array([Vector2(viewport_size.x - 250, viewport_size.y), Vector2(viewport_size.x - 450, viewport_size.y - 280), target]), Color(0.8, 0.95, 1.0), 5, true)


func _draw_results(viewport_size: Vector2) -> void:
    draw_rect(Rect2(Vector2.ZERO, viewport_size), Color(0.002, 0.008, 0.025, 0.78))
    _text_center("MISSION COMPLETE", Vector2(viewport_size.x * 0.5, 190), 68, Color.WHITE)
    _text_center("THE NEON WEAVER", Vector2(viewport_size.x * 0.5, 255), 30, Color(1.0, 0.08, 0.16))
    _panel(Rect2(viewport_size.x * 0.5 - 410, 320, 820, 350), Color(0.015, 0.03, 0.075, 0.95))
    var rows := ["TOTAL SCORE          %06d" % score, "SPIDER-SENSE         91%", "WEB ACCURACY          84%", "RESCUES               2/2", "BOSS CONTROL          89%", "FINAL TENSION         %d%%" % int(tension * 100.0)]
    for index in rows.size():
        _text(rows[index], Vector2(viewport_size.x * 0.5 - 320, 385 + index * 47), 25, Color.WHITE)
    _text_center("SPIDER-SENSE ELITE", Vector2(viewport_size.x * 0.5, 735), 33, Color(0.1, 0.75, 1.0))
    _text_center("YOU MASTERED THE WEB.", Vector2(viewport_size.x * 0.5, 820), 26, Color.WHITE)
    _text_center("NOW BUILD THE TECHNOLOGY BEHIND IT.", Vector2(viewport_size.x * 0.5, 865), 23, Color(1.0, 0.15, 0.2))


func _draw_diagnostics() -> void:
    _panel(Rect2(30, 760, 330, 250), Color(0, 0, 0, 0.82))
    _text("DIAGNOSTICS", Vector2(50, 800), 20, Color(0.1, 0.8, 1.0))
    _text("FPS %.1f" % fps, Vector2(50, 835), 16, Color.WHITE)
    _text("VISION %.1f pkt/s" % packet_rate, Vector2(50, 865), 16, Color.WHITE)
    _text("STATE %s" % state, Vector2(50, 895), 16, Color.WHITE)
    _text("ELAPSED %.2f" % elapsed, Vector2(50, 925), 16, Color.WHITE)
    _text(tracking, Vector2(50, 955), 16, Color(0.4, 1.0, 0.6))


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