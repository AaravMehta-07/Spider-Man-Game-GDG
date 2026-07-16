class_name BossController
extends Node

signal attack_started(kind: StringName, prompt: String, direction: StringName)
signal counter_success(points: int, label: String)
signal player_hit(damage: float)
signal boss_health_changed(value: float)
signal finisher_prompt(value: String)
signal contained

const ATTACKS := [
    {"time": 58.8, "duration": 2.2, "kind": &"right_slash", "action": &"dodge_left", "prompt": "SPIDER-SENSE RIGHT  |  DODGE LEFT"},
    {"time": 62.0, "duration": 2.3, "kind": &"overhead", "action": &"crouch", "prompt": "OVERHEAD STRIKE  |  CROUCH"},
    {"time": 65.2, "duration": 2.5, "kind": &"energy", "action": &"shield", "prompt": "ENERGY BLAST  |  WEB SHIELD"},
    {"time": 68.8, "duration": 2.8, "kind": &"counter", "action": &"web", "prompt": "COUNTER WINDOW  |  FIRE"},
    {"time": 72.2, "duration": 3.2, "kind": &"debris", "action": &"sling", "prompt": "CATCH DEBRIS  |  CLOSE, PULL, RELEASE"},
    {"time": 76.0, "duration": 1.8, "kind": &"ground_wave", "action": &"jump", "prompt": "GROUND WAVE  |  JUMP"},
]

var index := 0
var active: Dictionary = {}
var health := 100.0
var successful_counters := 0
var tension := 0.0
var final_contained := false
var _assist_elapsed := 0.0


func reset() -> void:
    index = 0
    active = {}
    health = 100.0
    successful_counters = 0
    tension = 0.0
    final_contained = false
    _assist_elapsed = 0.0
    boss_health_changed.emit(health)


func update(elapsed: float, delta: float, actions: Dictionary) -> void:
    if elapsed < 58.0:
        return
    if elapsed < 78.0:
        _update_combat(elapsed, actions)
    else:
        _update_finisher(elapsed, delta, actions)


func _update_combat(elapsed: float, actions: Dictionary) -> void:
    if index >= ATTACKS.size():
        return
    var attack: Dictionary = ATTACKS[index]
    if active.is_empty() and elapsed >= float(attack["time"]):
        active = attack
        attack_started.emit(
            attack["kind"],
            str(attack["prompt"]),
            _direction_for(str(attack["action"]))
        )
    if active.is_empty():
        return
    if _matches(str(active["action"]), actions):
        var damage := 18.0 if active["kind"] == &"debris" else 12.0
        health = maxf(8.0, health - damage)
        successful_counters += 1
        boss_health_changed.emit(health)
        counter_success.emit(1600 if active["kind"] != &"debris" else 2600, _label(str(active["kind"])))
        index += 1
        active = {}
        return
    if elapsed >= float(active["time"]) + float(active["duration"]):
        player_hit.emit(17.0)
        index += 1
        active = {}


func _update_finisher(elapsed: float, delta: float, actions: Dictionary) -> void:
    if final_contained:
        return
    var both_webs := bool(actions.get("web_left", false)) and bool(actions.get("web_right", false))
    var physical_pull := float(actions.get("two_hand_pull", 0.0))
    if both_webs:
        tension += delta * (0.16 + physical_pull * 0.72)
    else:
        tension = maxf(0.0, tension - delta * 0.08)
    if elapsed >= 80.0:
        _assist_elapsed += delta
        tension = maxf(tension, minf(1.0, _assist_elapsed * 0.28))
    tension = clampf(tension, 0.0, 1.0)
    health = 8.0 * (1.0 - tension)
    boss_health_changed.emit(health)
    if elapsed < 78.8:
        finisher_prompt.emit("BOTH HANDS FORWARD")
    elif not both_webs:
        finisher_prompt.emit("FIRE BOTH WEBS")
    elif tension < 0.42:
        finisher_prompt.emit("PULL")
    elif tension < 0.78:
        finisher_prompt.emit("MORE TENSION")
    elif tension < 1.0:
        finisher_prompt.emit("FINAL PULL")
    if tension >= 1.0 or elapsed >= 82.4:
        tension = 1.0
        health = 0.0
        final_contained = true
        boss_health_changed.emit(health)
        finisher_prompt.emit("THE VEIL CONTAINED")
        contained.emit()


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
        "sling":
            var webbed := bool(input.get("web_left", false)) or bool(input.get("web_right", false))
            return webbed and float(input.get("pull", 0.0)) > 0.25
    return false


func _direction_for(action: String) -> StringName:
    if action == "dodge_left":
        return &"right"
    if action == "dodge_right":
        return &"left"
    return &"center"


func _label(kind: String) -> String:
    if kind == "debris":
        return "PERFECT SLING"
    if kind == "counter":
        return "COUNTER HIT"
    return "BOSS REVEALED"