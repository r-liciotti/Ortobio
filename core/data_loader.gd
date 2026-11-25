class_name DataLoader
extends RefCounted
## Loads data-driven JSON configs for crops, items, and balance parameters.

const BALANCE_PATH := "res://data/balance_config.json"
const CROPS_PATH := "res://data/crops.json"
const ITEMS_PATH := "res://data/items.json"


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


static func _load_by_id(path: String, list_key: String) -> Dictionary:
	var data: Variant = load_json(path)
	var by_id: Dictionary = {}
	if data is Dictionary and data.has(list_key):
		var raw_list: Variant = data[list_key]
		if raw_list is Array:
			for entry: Variant in raw_list:
				if entry is Dictionary:
					var entry_dict: Dictionary = entry
					if entry_dict.has("id"):
						by_id[str(entry_dict["id"])] = entry_dict
	return by_id


static func load_crops() -> Dictionary:
	return _load_by_id(CROPS_PATH, "crops")


static func load_items() -> Dictionary:
	return _load_by_id(ITEMS_PATH, "items")
