class_name AirNameEntry
extends RefCounted

const MAX_NAME_LENGTH := 12
const MAX_STROKES := 24
const MAX_POINTS := 640
const MIN_POINT_DISTANCE := 0.006
const MIN_CONFIDENCE := 0.42
const GRID_WIDTH := 18
const GRID_HEIGHT := 24

const GLYPHS := {
    "A": ["01110", "10001", "10001", "11111", "10001", "10001", "10001"],
    "B": ["11110", "10001", "10001", "11110", "10001", "10001", "11110"],
    "C": ["01111", "10000", "10000", "10000", "10000", "10000", "01111"],
    "D": ["11110", "10001", "10001", "10001", "10001", "10001", "11110"],
    "E": ["11111", "10000", "10000", "11110", "10000", "10000", "11111"],
    "F": ["11111", "10000", "10000", "11110", "10000", "10000", "10000"],
    "G": ["01111", "10000", "10000", "10111", "10001", "10001", "01111"],
    "H": ["10001", "10001", "10001", "11111", "10001", "10001", "10001"],
    "I": ["11111", "00100", "00100", "00100", "00100", "00100", "11111"],
    "J": ["00111", "00010", "00010", "00010", "10010", "10010", "01100"],
    "K": ["10001", "10010", "10100", "11000", "10100", "10010", "10001"],
    "L": ["10000", "10000", "10000", "10000", "10000", "10000", "11111"],
    "M": ["10001", "11011", "10101", "10101", "10001", "10001", "10001"],
    "N": ["10001", "11001", "10101", "10011", "10001", "10001", "10001"],
    "O": ["01110", "10001", "10001", "10001", "10001", "10001", "01110"],
    "P": ["11110", "10001", "10001", "11110", "10000", "10000", "10000"],
    "Q": ["01110", "10001", "10001", "10001", "10101", "10010", "01101"],
    "R": ["11110", "10001", "10001", "11110", "10100", "10010", "10001"],
    "S": ["01111", "10000", "10000", "01110", "00001", "00001", "11110"],
    "T": ["11111", "00100", "00100", "00100", "00100", "00100", "00100"],
    "U": ["10001", "10001", "10001", "10001", "10001", "10001", "01110"],
    "V": ["10001", "10001", "10001", "10001", "10001", "01010", "00100"],
    "W": ["10001", "10001", "10001", "10101", "10101", "11011", "10001"],
    "X": ["10001", "10001", "01010", "00100", "01010", "10001", "10001"],
    "Y": ["10001", "10001", "01010", "00100", "00100", "00100", "00100"],
    "Z": ["11111", "00001", "00010", "00100", "01000", "10000", "11111"],
}

var name := ""
var strokes: Array[PackedVector2Array] = []
var cursor := Vector2(0.5, 0.5)
var pen_down := false
var predicted_letter := ""
var confidence := 0.0
var _point_count := 0


func set_pen(point: Vector2, drawing: bool) -> void:
    cursor = Vector2(clampf(point.x, 0.0, 1.0), clampf(point.y, 0.0, 1.0))
    if not drawing:
        pen_down = false
        return
    if _point_count >= MAX_POINTS:
        pen_down = false
        return
    if not pen_down:
        if strokes.size() >= MAX_STROKES:
            pen_down = false
            return
        strokes.append(PackedVector2Array())
    pen_down = true
    var stroke: PackedVector2Array = strokes.back()
    if stroke.is_empty() or stroke[stroke.size() - 1].distance_to(cursor) >= MIN_POINT_DISTANCE:
        stroke.append(cursor)
        strokes[strokes.size() - 1] = stroke
        _point_count += 1
        if _point_count % 3 == 0:
            _refresh_prediction()


func finish_stroke() -> void:
    pen_down = false
    _refresh_prediction()


func has_ink() -> bool:
    return _point_count >= 3


func clear_glyph() -> void:
    strokes.clear()
    _point_count = 0
    pen_down = false
    predicted_letter = ""
    confidence = 0.0


func undo() -> void:
    if has_ink():
        clear_glyph()
    elif not name.is_empty():
        name = name.left(name.length() - 1)


func accept_prediction() -> bool:
    _refresh_prediction()
    if predicted_letter.is_empty() or confidence < MIN_CONFIDENCE or name.length() >= MAX_NAME_LENGTH:
        return false
    name += predicted_letter
    clear_glyph()
    return true


func append_typed(character: String) -> bool:
    if name.length() >= MAX_NAME_LENGTH:
        return false
    var upper := character.to_upper()
    if upper.length() != 1 or upper not in "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-":
        return false
    name += upper
    return true


func _refresh_prediction() -> void:
    var result := recognize(strokes)
    predicted_letter = str(result.get("letter", ""))
    confidence = float(result.get("confidence", 0.0))


static func recognize(source_strokes: Array[PackedVector2Array]) -> Dictionary:
    var user_points := _rasterize_strokes(source_strokes)
    if user_points.size() < 5:
        return {"letter": "", "confidence": 0.0}
    var best_letter := ""
    var best_distance := INF
    for letter in GLYPHS:
        var template_points := _template_points(str(letter), GLYPHS[letter])
        var distance := (_directed_distance(user_points, template_points) + _directed_distance(template_points, user_points)) * 0.5
        if distance < best_distance:
            best_distance = distance
            best_letter = letter
    var score := clampf(1.0 - best_distance * 3.15, 0.0, 1.0)
    return {"letter": best_letter, "confidence": score}


static func _rasterize_strokes(source_strokes: Array[PackedVector2Array]) -> Array[Vector2]:
    var minimum := Vector2(INF, INF)
    var maximum := Vector2(-INF, -INF)
    var raw_count := 0
    for stroke in source_strokes:
        for point in stroke:
            minimum = minimum.min(point)
            maximum = maximum.max(point)
            raw_count += 1
    var extent := maximum - minimum
    if raw_count < 3 or extent.x < 0.025 or extent.y < 0.025:
        return []
    var occupied := {}
    for stroke in source_strokes:
        if stroke.is_empty():
            continue
        for index in stroke.size():
            var point := (stroke[index] - minimum) / extent
            var previous := point if index == 0 else (stroke[index - 1] - minimum) / extent
            var steps := maxi(1, int(ceil(previous.distance_to(point) * 36.0)))
            for step in range(steps + 1):
                var sample := previous.lerp(point, float(step) / steps)
                var cell := Vector2i(
                    clampi(int(round(sample.x * (GRID_WIDTH - 1))), 0, GRID_WIDTH - 1),
                    clampi(int(round(sample.y * (GRID_HEIGHT - 1))), 0, GRID_HEIGHT - 1)
                )
                occupied[cell] = true
    var result: Array[Vector2] = []
    for cell in occupied:
        result.append(Vector2(float(cell.x) / (GRID_WIDTH - 1), float(cell.y) / (GRID_HEIGHT - 1)))
    return result


static func _template_points(letter: String, pattern: Array) -> Array[Vector2]:
    var result: Array[Vector2] = []
    if letter == "V":
        for step in range(13):
            var t := float(step) / 12.0
            result.append(Vector2(0.5 * t, t))
            result.append(Vector2(1.0 - 0.5 * t, t))
        return result
    for y in pattern.size():
        var row := str(pattern[y])
        for x in row.length():
            if row[x] == "1":
                result.append(Vector2(float(x) / 4.0, float(y) / 6.0))
    return result


static func _directed_distance(source: Array[Vector2], target: Array[Vector2]) -> float:
    var total := 0.0
    for point in source:
        var nearest := INF
        for candidate in target:
            nearest = minf(nearest, point.distance_to(candidate))
        total += nearest
    return total / maxf(1.0, float(source.size()))
