class_name SaveManager
extends Node

const MAX_ENTRIES := 50
var entries: Array = []
var file_path := "user://leaderboard.json"


func _ready() -> void:
    load_leaderboard()


func load_leaderboard() -> void:
    if not FileAccess.file_exists(file_path):
        entries = []
        return
    var file := FileAccess.open(file_path, FileAccess.READ)
    if file == null:
        entries = []
        return
    var parsed = JSON.parse_string(file.get_as_text())
    if parsed is Array:
        entries = parsed
        entries.sort_custom(func(a, b): return int(a.get("score", 0)) > int(b.get("score", 0)))
    else:
        var backup := file_path + ".corrupt-" + str(Time.get_unix_time_from_system())
        DirAccess.rename_absolute(ProjectSettings.globalize_path(file_path), ProjectSettings.globalize_path(backup))
        entries = []


func add_result(result: Dictionary) -> void:
    entries.append(result)
    entries.sort_custom(func(a, b): return int(a.get("score", 0)) > int(b.get("score", 0)))
    if entries.size() > MAX_ENTRIES:
        entries.resize(MAX_ENTRIES)
    _atomic_save()


func daily_high_score() -> int:
    if entries.is_empty():
        return 0
    return int(entries[0].get("score", 0))


func _atomic_save() -> void:
    var temporary := file_path + ".tmp"
    var file := FileAccess.open(temporary, FileAccess.WRITE)
    if file == null:
        push_warning("Leaderboard write failed")
        return
    file.store_string(JSON.stringify(entries, "  "))
    file.flush()
    file.close()
    var absolute := ProjectSettings.globalize_path(file_path)
    var temp_absolute := ProjectSettings.globalize_path(temporary)
    if FileAccess.file_exists(file_path):
        DirAccess.remove_absolute(absolute)
    DirAccess.rename_absolute(temp_absolute, absolute)