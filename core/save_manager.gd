extends Node
## Autoload SaveManager: atomic JSON serialization for GameState.

const SAVE_PATH := "user://savegame.json"
const SCHEMA_VERSION := 1


func _resolve_state(state: Node) -> Node:
	if state != null:
		return state
	if is_inside_tree():
		return get_node_or_null("/root/GameState")
	return null


func save_game(state: Node = null, path: String = SAVE_PATH) -> bool:
	var target: Node = _resolve_state(state)
	if target == null or not target.has_method("to_dict"):
		push_error("SaveManager: missing or invalid GameState for save_game")
		return false

	var raw_state: Variant = target.call("to_dict")
	if not (raw_state is Dictionary):
		push_error("SaveManager: GameState.to_dict() did not return a Dictionary")
		return false

	var payload: Dictionary = (raw_state as Dictionary).duplicate(true)
	payload["schema_version"] = SCHEMA_VERSION
	var json_text: String = JSON.stringify(payload, "\t")

	var abs_path: String = ProjectSettings.globalize_path(path)
	var parent_dir: String = abs_path.get_base_dir()
	if not parent_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(parent_dir)

	var tmp_path: String = path + ".tmp"
	var tmp_file: FileAccess = FileAccess.open(tmp_path, FileAccess.WRITE)
	if tmp_file != null:
		tmp_file.store_string(json_text)
		tmp_file.flush()
		tmp_file.close()
		var abs_tmp: String = ProjectSettings.globalize_path(tmp_path)
		var err: Error = DirAccess.rename_absolute(abs_tmp, abs_path)
		if err == OK:
			return true
		# Clean up temp file before direct write fallback
		if FileAccess.file_exists(tmp_path):
			DirAccess.remove_absolute(abs_tmp)

	var direct_file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if direct_file == null:
		push_error("SaveManager: cannot write save file at %s" % path)
		return false
	direct_file.store_string(json_text)
	direct_file.flush()
	direct_file.close()
	return true


func load_game(state: Node = null, path: String = SAVE_PATH) -> bool:
	var target: Node = _resolve_state(state)
	if target == null or not target.has_method("from_dict"):
		push_error("SaveManager: missing or invalid GameState for load_game")
		return false
	if not FileAccess.file_exists(path):
		return false

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("SaveManager: cannot open save file at %s" % path)
		return false
	var text: String = file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_error("SaveManager: invalid JSON in %s" % path)
		return false

	var data: Dictionary = parsed
	if not data.has("schema_version") or int(data["schema_version"]) != SCHEMA_VERSION:
		push_error("SaveManager: unsupported schema_version in %s" % path)
		return false

	target.call("from_dict", data)
	return true


func has_save(path: String = SAVE_PATH) -> bool:
	return FileAccess.file_exists(path)


func delete_save(path: String = SAVE_PATH) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var tmp_path: String = path + ".tmp"
	if FileAccess.file_exists(tmp_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp_path))
