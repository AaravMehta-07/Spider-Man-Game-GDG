class_name AudioManager
extends Node

var music_players := [AudioStreamPlayer.new(), AudioStreamPlayer.new()]
var effects := AudioStreamPlayer.new()
var spatial_effects := AudioStreamPlayer3D.new()
var _active_music := 0
var _current_music := ""


func _ready() -> void:
    _ensure_bus("Music")
    _ensure_bus("Effects")
    for player in music_players:
        add_child(player)
        player.bus = "Music"
        player.volume_db = -40.0
    add_child(effects)
    add_child(spatial_effects)
    effects.bus = "Effects"
    spatial_effects.bus = "Effects"
    spatial_effects.position = Vector3(0, 4, -12)
    spatial_effects.max_distance = 45.0
    AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), -10.0)
    AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Effects"), -4.0)
    play_music("attract")


func _ensure_bus(bus_name: String) -> void:
    if AudioServer.get_bus_index(bus_name) >= 0:
        return
    AudioServer.add_bus()
    AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)


func play_music(track: String) -> void:
    if track == _current_music:
        return
    var stream = load("res://assets/audio/generated/music_%s.wav" % track)
    if not stream:
        push_warning("Missing music: %s" % track)
        return
    _current_music = track
    var previous: AudioStreamPlayer = music_players[_active_music]
    _active_music = 1 - _active_music
    var incoming: AudioStreamPlayer = music_players[_active_music]
    incoming.stream = stream
    incoming.volume_db = -40.0
    incoming.play()
    var fade := create_tween().set_parallel(true)
    fade.tween_property(previous, "volume_db", -40.0, 0.55)
    fade.tween_property(incoming, "volume_db", 0.0, 0.55)
    fade.chain().tween_callback(previous.stop)


func play_effect(effect: String) -> void:
    var stream = load("res://assets/audio/generated/%s.wav" % effect)
    if not stream:
        push_warning("Missing audio effect: %s" % effect)
        return
    if effect in ["impact", "spider_sense", "finisher", "boss_distortion", "debris_throw"]:
        spatial_effects.stream = stream
        spatial_effects.play()
    else:
        effects.stream = stream
        effects.play()


func on_state_changed(_previous: StringName, current: StringName) -> void:
    if current == &"ATTRACT":
        play_music("attract")
    elif current == &"CALIBRATION":
        play_effect("calibration_pulse")
    elif current == &"WEB_VERIFICATION":
        play_effect("web_verification")
    elif current == &"CHASE":
        play_music("chase")
        play_effect("calibration_success")
    elif current == &"BOSS_INTRO":
        play_music("boss")
        play_effect("reveal_sting")
    elif current == &"BOSS_COMBAT":
        play_music("boss")
    elif current == &"FINISHER":
        play_music("finisher")
        play_effect("double_web_charge")
    elif current == &"RESULTS":
        play_music("results")
        play_effect("result_reveal")
