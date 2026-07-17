class_name ChaseDirector
extends Node

signal challenge_started(kind: StringName, prompt: String, direction: StringName)
signal challenge_cleared(points: int, label: String)
signal challenge_missed(damage: float)
signal set_piece(kind: StringName)

const CHALLENGES := [
    {"time": 10.5, "duration": 2.0, "kind": &"billboard", "action": &"dodge_left", "prompt": "BILLBOARD RIGHT  |  DODGE LEFT", "points": 900},
    {"time": 13.0, "duration": 2.2, "kind": &"drone", "action": &"web", "prompt": "GLIDER RAIDER  |  FIRE WEB", "points": 750},
    {"time": 16.0, "duration": 2.2, "kind": &"vent", "action": &"jump", "prompt": "ROOFTOP VENT  |  JUMP", "points": 850},
    {"time": 20.0, "duration": 2.5, "kind": &"barrier", "action": &"pull", "prompt": "WEB THE BARRIER  |  PULL", "points": 1200},
    {"time": 24.0, "duration": 2.4, "kind": &"scaffold", "action": &"crouch", "prompt": "LOW SCAFFOLD  |  CROUCH", "points": 900},
    {"time": 28.0, "duration": 2.8, "kind": &"swing", "action": &"web", "prompt": "SWING ANCHOR  |  FIRE WEB", "points": 1400},
    {"time": 33.0, "duration": 3.0, "kind": &"rescue", "action": &"web", "prompt": "CIVILIAN FALLING  |  RESCUE", "points": 1800},
    {"time": 38.5, "duration": 2.4, "kind": &"crane", "action": &"dodge_right", "prompt": "CRANE CABLE LEFT  |  DODGE RIGHT", "points": 1000},
    {"time": 43.0, "duration": 2.8, "kind": &"shockwave", "action": &"shield", "prompt": "INVISIBLE SHOCKWAVE  |  WEB SHIELD", "points": 1300},
    {"time": 48.0, "duration": 3.2, "kind": &"collapse", "action": &"double_web", "prompt": "ROUTE COLLAPSE  |  BOTH WEBS", "points": 1700},
]

var index := 0
var active: Dictionary = {}
var resolved := false
var perfect_dodges := 0
var rescues := 0
var web_hits := 0
var web_shots := 0


static func score_with_combo(points: int, combo_value: int) -> int:
    var safe_combo := clampi(combo_value, 1, 8)
    return int(round(points * (1.0 + float(safe_combo - 1) * 0.18)))


func reset() -> void:
    index = 0
    active = {}
    resolved = false
    perfect_dodges = 0
    rescues = 0
    web_hits = 0
    web_shots = 0


func update(elapsed: float, actions: Dictionary) -> void:
    if index >= CHALLENGES.size():
        return
    var challenge: Dictionary = CHALLENGES[index]
    if active.is_empty() and elapsed >= float(challenge["time"]):
        active = challenge
        resolved = false
        challenge_started.emit(
            challenge["kind"],
            str(challenge["prompt"]),
            _direction_for(challenge["action"])
        )
        set_piece.emit(challenge["kind"])
    if active.is_empty() or resolved:
        return
    if _matches(str(active["action"]), actions):
        resolved = true
        var label := _success_label(str(active["kind"]))
        if str(active["action"]).begins_with("dodge"):
            perfect_dodges += 1
        if active["kind"] == &"rescue":
            rescues += 1
        if str(active["action"]) in ["web", "pull", "double_web"]:
            web_hits += 1
        challenge_cleared.emit(int(active["points"]), label)
        index += 1
        active = {}
        return
    var deadline := float(active["time"]) + float(active["duration"])
    if elapsed >= deadline:
        challenge_missed.emit(10.0 if active["kind"] != &"collapse" else 14.0)
        index += 1
        active = {}


func register_web_shot() -> void:
    web_shots += 1


func web_accuracy() -> int:
    if web_shots <= 0:
        return 0
    return mini(100, int(round(float(web_hits) / float(web_shots) * 100.0)))


func _matches(action: String, input: Dictionary) -> bool:
    match action:
        "dodge_left":
            return bool(input.get("dodge_left", false)) or float(input.get("move", 0.0)) < -0.72
        "dodge_right":
            return bool(input.get("dodge_right", false)) or float(input.get("move", 0.0)) > 0.72
        "jump":
            return bool(input.get("jump", false))
        "crouch":
            return bool(input.get("crouch", false))
        "shield":
            return bool(input.get("shield", false))
        "web":
            return bool(input.get("web_left", false)) or bool(input.get("web_right", false))
        "pull":
            return (bool(input.get("web_left", false)) or bool(input.get("web_right", false))) and float(input.get("pull", 0.0)) > 0.2
        "double_web":
            return bool(input.get("web_left", false)) and bool(input.get("web_right", false))
    return false


func _direction_for(action: StringName) -> StringName:
    if action == &"dodge_left":
        return &"right"
    if action == &"dodge_right":
        return &"left"
    return &"center"


func _success_label(kind: String) -> String:
    match kind:
        "rescue": return "RESCUE SECURED"
        "swing": return "SWING LOCKED"
        "barrier": return "WEB PULL"
        "shockwave": return "SHIELD LOCKED"
        "collapse": return "ROUTE STABILIZED"
    return "PERFECT"


