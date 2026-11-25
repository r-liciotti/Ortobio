class_name DataLoader
extends RefCounted
## Loads data-driven JSON configs for crops and balance parameters.

const BALANCE_PATH := "res://data/balance_config.json"
const CROPS_PATH := "res://data/crops.json"


static func load_json(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("DataLoader: cannot open %s" % path)
		return null
	var text := file.get_as_text()
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null:
		push_error("DataLoader: invalid JSON in %s" % path)
	return parsed


static func load_balance_config() -> Dictionary:
	var data: Variant = load_json(BALANCE_PATH)
	return data if data is Dictionary else {}


static func load_crops() -> Dictionary:
	var data: Variant = load_json(CROPS_PATH)
	var by_id: Dictionary = {}
	if data is Dictionary and data.has("crops") and data["crops"] is Array:
		for crop in data["crops"]:
			if crop is Dictionary and crop.has("id"):
				by_id[str(crop["id"])] = crop
	return by_id
