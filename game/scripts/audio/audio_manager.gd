class_name AudioManager
extends Node

var music := AudioStreamPlayer.new()
var effects := AudioStreamPlayer.new()
var _current_music := ""


func _ready() -> void:
    add_child(music)
    add_child(effects)
    music.volume_db = -10.0
    effects.volume_db = -4.0
    play_music("attract")


func play_music(track: String) -> void:
    if track == _current_music:
        return
    _current_music = track
    var stream = load("res://assets/audio/generated/music_%s.wav" % track)
    if stream:
        music.stream = stream
        music.play()


func play_effect(effect: String) -> void:
    var stream = load("res://assets/audio/generated/%s.wav" % effect)
    if stream:
        effects.stream = stream
        effects.play()


func on_state_changed(_previous: StringName, current: StringName) -> void:
    if current == &"ATTRACT":
        play_music("attract")
    elif current == &"CHASE":
        play_music("chase")
        play_effect("ui_confirm")
    elif current in [&"BOSS_INTRO", &"BOSS_COMBAT"]:
        play_music("boss")
        play_effect("spider_sense")
    elif current == &"FINISHER":
        play_effect("finisher")
    elif current == &"RESULTS":
        play_music("results")