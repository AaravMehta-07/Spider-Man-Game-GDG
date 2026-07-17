class_name SaveManager
extends Node

const MAX_ENTRIES := 50
var entries: Array = []
var file_path := "user://leaderboard.json"


func _ready() -> void:
    load_leaderboard()


func load_leaderboard() -> void:
    _restore_backup_if_needed()
    if not FileAccess.file_exists(file_path):
        entries = []
        return
    var file := FileAccess.open(file_path, FileAccess.READ)
    if file == null:
        entries = []
        return
    var parsed = JSON.parse_string(file.get_as_text())
    file.close()
    if parsed is Array:
        entries = []
        var rejected := false
        for candidate in parsed:
            if candidate is Dictionary and _valid_entry(candidate):
                entries.append(_normalized_entry(candidate))
            else:
                rejected = true
        entries.sort_custom(func(a, b): return int(a.get("score", 0)) > int(b.get("score", 0)))
        if entries.size() > MAX_ENTRIES:
            entries.resize(MAX_ENTRIES)
        if rejected:
            _quarantine_current()
            _atomic_save()
    else:
        _quarantine_current()
        entries = []


func add_result(result: Dictionary) -> void:
    if not _valid_entry(result):
        push_warning("Rejected invalid leaderboard result")
        return
    entries.append(_normalized_entry(result))
    entries.sort_custom(func(a, b): return int(a.get("score", 0)) > int(b.get("score", 0)))
    if entries.size() > MAX_ENTRIES:
        entries.resize(MAX_ENTRIES)
    _atomic_save()


func clear_leaderboard() -> void:
    entries = []
    _atomic_save()


func today_entries() -> Array:
    var today := Time.get_date_string_from_system()
    return entries.filter(func(entry): return str(entry.get("timestamp", "")).begins_with(today))

func daily_high_score() -> int:
    var today := today_entries()
    if today.is_empty():
        return 0
    return int(today[0].get("score", 0))


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
    var backup_absolute := ProjectSettings.globalize_path(file_path + ".bak")
    if FileAccess.file_exists(file_path + ".bak"):
        DirAccess.remove_absolute(backup_absolute)
    if FileAccess.file_exists(file_path):
        var backup_error := DirAccess.rename_absolute(absolute, backup_absolute)
        if backup_error != OK:
            push_warning("Leaderboard backup failed: %s" % error_string(backup_error))
            DirAccess.remove_absolute(temp_absolute)
            return
    var commit_error := DirAccess.rename_absolute(temp_absolute, absolute)
    if commit_error != OK:
        push_warning("Leaderboard commit failed: %s" % error_string(commit_error))
        if FileAccess.file_exists(file_path + ".bak"):
            DirAccess.rename_absolute(backup_absolute, absolute)
        return
    if FileAccess.file_exists(file_path + ".bak"):
        DirAccess.remove_absolute(backup_absolute)


func _valid_entry(candidate: Dictionary) -> bool:
    var score_value = candidate.get("score")
    if (not score_value is int and not score_value is float) or score_value is bool:
        return false
    var timestamp_value = candidate.get("timestamp", "")
    return timestamp_value is String


func _normalized_entry(candidate: Dictionary) -> Dictionary:
    return {
        "nickname": str(candidate.get("nickname", "")).left(32),
        "codename": str(candidate.get("codename", "Anonymous Hero")).left(48),
        "score": maxi(0, int(candidate.get("score", 0))),
        "web_accuracy": clampi(int(candidate.get("web_accuracy", 0)), 0, 100),
        "spider_sense": clampi(int(candidate.get("spider_sense", 0)), 0, 100),
        "boss_control": clampi(int(candidate.get("boss_control", 0)), 0, 100),
        "final_tension": clampi(int(candidate.get("final_tension", 0)), 0, 100),
        "rescues": maxi(0, int(candidate.get("rescues", 0))),
        "timestamp": str(candidate.get("timestamp", "")),
    }


func _quarantine_current() -> void:
    if not FileAccess.file_exists(file_path):
        return
    var backup := file_path + ".corrupt-" + str(Time.get_unix_time_from_system())
    var error := DirAccess.rename_absolute(
        ProjectSettings.globalize_path(file_path),
        ProjectSettings.globalize_path(backup)
    )
    if error != OK:
        push_warning("Leaderboard quarantine failed: %s" % error_string(error))


func _restore_backup_if_needed() -> void:
    var backup := file_path + ".bak"
    if FileAccess.file_exists(file_path) or not FileAccess.file_exists(backup):
        return
    var error := DirAccess.rename_absolute(
        ProjectSettings.globalize_path(backup),
        ProjectSettings.globalize_path(file_path)
    )
    if error != OK:
        push_warning("Leaderboard recovery failed: %s" % error_string(error))
