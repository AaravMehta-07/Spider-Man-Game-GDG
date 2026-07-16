class_name SessionController
extends Node

signal state_changed(previous: StringName, current: StringName)
signal session_finished

const ATTRACT := &"ATTRACT"
const CALIBRATION := &"CALIBRATION"
const WEB_VERIFICATION := &"WEB_VERIFICATION"
const CHASE := &"CHASE"
const BOSS_INTRO := &"BOSS_INTRO"
const BOSS_COMBAT := &"BOSS_COMBAT"
const FINISHER := &"FINISHER"
const RESULTS := &"RESULTS"
const RESETTING := &"RESETTING"

var state: StringName = ATTRACT
var elapsed := 0.0
var session_active := false
var time_scale := 1.0


func start_session(skip_calibration: bool = false) -> void:
    elapsed = 9.5 if skip_calibration else 0.0
    session_active = true
    _transition(CHASE if skip_calibration else CALIBRATION)


func reset_to_attract() -> void:
    elapsed = 0.0
    session_active = false
    _transition(ATTRACT)


func advance(delta: float) -> void:
    if not session_active:
        return
    elapsed = minf(90.0, elapsed + delta * time_scale)
    var target := state_for_time(elapsed)
    if target != state:
        _transition(target)
    if elapsed >= 90.0:
        session_finished.emit()
        reset_to_attract()


func state_for_time(time: float) -> StringName:
    if time < 5.5:
        return CALIBRATION
    if time < 9.5:
        return WEB_VERIFICATION
    if time < 55.0:
        return CHASE
    if time < 58.0:
        return BOSS_INTRO
    if time < 78.0:
        return BOSS_COMBAT
    if time < 83.0:
        return FINISHER
    if time < 90.0:
        return RESULTS
    return RESETTING


func _transition(next_state: StringName) -> void:
    var previous := state
    state = next_state
    state_changed.emit(previous, state)