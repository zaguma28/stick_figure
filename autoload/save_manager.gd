extends Node

const SAVE_PATH := "user://stick_souls_save_v1.json"
const BACKUP_PATH := "user://stick_souls_save_v1.bak.json"
const SAVE_VERSION := 1

signal save_loaded(data: Dictionary)
signal save_written(path: String)

var data: Dictionary = {}

func _ready() -> void:
	load_save()

func load_save() -> void:
	var loaded := _read_json_file(SAVE_PATH)
	if loaded.is_empty():
		loaded = _read_json_file(BACKUP_PATH)
	if loaded.is_empty():
		data = _default_data()
		save()
	else:
		data = _merge_with_defaults(loaded, _default_data())
	emit_signal("save_loaded", data.duplicate(true))

func save() -> void:
	if data.is_empty():
		data = _default_data()
	var stats: Dictionary = _section("stats")
	stats["last_updated"] = Time.get_datetime_string_from_system()
	data["stats"] = stats

	var json_text := JSON.stringify(data, "\t")
	var tmp_path := "%s.tmp" % SAVE_PATH
	var write_file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if write_file == null:
		push_warning("SaveManager: failed to write temp file %s" % tmp_path)
		return
	write_file.store_string(json_text)
	write_file.close()

	if FileAccess.file_exists(SAVE_PATH):
		_copy_file_text(SAVE_PATH, BACKUP_PATH)
		DirAccess.remove_absolute(SAVE_PATH)
	var rename_err := DirAccess.rename_absolute(tmp_path, SAVE_PATH)
	if rename_err != OK:
		push_warning("SaveManager: failed to finalize save (%d)" % rename_err)
		return
	emit_signal("save_written", SAVE_PATH)

func get_progress(key: String, default_value: Variant = null) -> Variant:
	return _section("meta").get(key, default_value)

func set_progress(key: String, value: Variant, autosave: bool = true) -> void:
	var meta: Dictionary = _section("meta")
	meta[key] = value
	data["meta"] = meta
	if autosave:
		save()

func increment_progress(key: String, amount: int = 1, autosave: bool = true) -> int:
	var current := int(get_progress(key, 0))
	current += amount
	set_progress(key, current, autosave)
	return current

func remember_reward(reward_id: String, autosave: bool = true) -> void:
	if reward_id == "":
		return
	var meta: Dictionary = _section("meta")
	var discovered: Array = meta.get("discovered_rewards", [])
	if not discovered.has(reward_id):
		discovered.append(reward_id)
	meta["discovered_rewards"] = discovered
	data["meta"] = meta
	if autosave:
		save()

func get_discovered_rewards() -> Array:
	var meta: Dictionary = _section("meta")
	return meta.get("discovered_rewards", []).duplicate()

func get_setting(key: String, default_value: Variant = null) -> Variant:
	return _section("settings").get(key, default_value)

func set_setting(key: String, value: Variant, autosave: bool = true) -> void:
	var settings: Dictionary = _section("settings")
	settings[key] = value
	data["settings"] = settings
	if autosave:
		save()

func get_input_bindings() -> Dictionary:
	var settings: Dictionary = _section("settings")
	return settings.get("input_bindings", {}).duplicate(true)

func set_input_bindings(bindings: Dictionary, autosave: bool = true) -> void:
	var settings: Dictionary = _section("settings")
	settings["input_bindings"] = bindings.duplicate(true)
	data["settings"] = settings
	if autosave:
		save()

func record_last_run(summary: Dictionary, autosave: bool = true) -> void:
	var stats: Dictionary = _section("stats")
	stats["last_run"] = summary.duplicate(true)
	stats["last_updated"] = Time.get_datetime_string_from_system()
	data["stats"] = stats
	if autosave:
		save()

func _default_data() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"meta": {
			"run_count": 0,
			"clear_count": 0,
			"best_floor": 1,
			"boss_reach_count": 0,
			"boss_fail_streak": 0,
			"discovered_rewards": []
		},
		"settings": {
			"touch_controls_enabled": true,
			"input_bindings": {},
			"bgm_volume_db": 0.0,
			"sfx_volume_db": 0.0
		},
		"stats": {
			"last_run": {},
			"last_updated": ""
		}
	}

func _merge_with_defaults(source: Dictionary, defaults: Dictionary) -> Dictionary:
	var merged := defaults.duplicate(true)
	for key in source.keys():
		if not merged.has(key):
			merged[key] = source[key]
			continue
		if source[key] is Dictionary and merged[key] is Dictionary:
			merged[key] = _merge_with_defaults(source[key], merged[key])
		else:
			merged[key] = source[key]
	return merged

func _section(section_name: String) -> Dictionary:
	if not data.has(section_name) or not (data[section_name] is Dictionary):
		data[section_name] = {}
	return data[section_name]

func _read_json_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	if text.strip_edges() == "":
		return {}
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	return {}

func _copy_file_text(from_path: String, to_path: String) -> void:
	if not FileAccess.file_exists(from_path):
		return
	var src := FileAccess.open(from_path, FileAccess.READ)
	if src == null:
		return
	var content := src.get_as_text()
	src.close()
	var dst := FileAccess.open(to_path, FileAccess.WRITE)
	if dst == null:
		return
	dst.store_string(content)
	dst.close()
