extends Node
## Autoload SceneManager: screen routing and centralized smart-pause modal counter.

signal screen_changed(screen_id: String)

const SCENES := {
	"field": "res://scenes/FieldScreen.tscn",
}

var current_screen: String = "field"
var modal_pause_count: int = 0


func is_clock_running() -> bool:
	return (current_screen == "field" or current_screen == "farm") and modal_pause_count <= 0


func push_modal_pause() -> void:
	modal_pause_count += 1


func pop_modal_pause() -> void:
	modal_pause_count = maxi(0, modal_pause_count - 1)


func reset_modal_pauses() -> void:
	modal_pause_count = 0


func go_to(screen_id: String) -> bool:
	if not SCENES.has(screen_id):
		push_warning("SceneManager: unknown screen_id '%s'" % screen_id)
		return false
	var scene_path: String = str(SCENES[screen_id])
	if not ResourceLoader.exists(scene_path):
		push_warning("SceneManager: missing scene '%s'" % scene_path)
		return false
	var tree: SceneTree = get_tree()
	if tree == null:
		return false
	reset_modal_pauses()
	var err: Error = tree.change_scene_to_file(scene_path)
	if err != OK:
		push_error("SceneManager: failed to switch to %s (err=%d)" % [scene_path, err])
		return false
	current_screen = screen_id
	screen_changed.emit(screen_id)
	return true
