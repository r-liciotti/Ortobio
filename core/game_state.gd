extends Node
## Autoload GameState: central persistent state for time/weather, fields, inventory, and progression.

signal state_changed
signal day_advanced(summary: Dictionary)

var balance_config: Dictionary = {}
var crops_db: Dictionary = {}
var items_db: Dictionary = {}

var time_weather: TimeWeatherManager
var fields: Dictionary = {}
var active_field_id: String = "field_1"
var inventory: InventoryManager

var coins: int = 150
var energy: int = 100
var max_energy: int = 100

var village_level: int = 1
var farmer_xp: int = 0
var farmer_level: int = 1
var skill_points: int = 0
var selected_hotbar_index: int = 0


func _ready() -> void:
	_ensure_data_loaded()
	var save_mgr: Node = _get_save_manager()
	if save_mgr != null and bool(save_mgr.call("has_save")):
		if bool(save_mgr.call("load_game", self)):
			return
	new_game()


func _ensure_data_loaded() -> void:
	if balance_config.is_empty():
		balance_config = DataLoader.load_balance_config()
	if crops_db.is_empty():
		crops_db = DataLoader.load_crops()
	if items_db.is_empty():
		items_db = DataLoader.load_items()


func _get_save_manager() -> Node:
	if is_inside_tree():
		return get_node_or_null("/root/SaveManager")
	return null


func new_game() -> void:
	_ensure_data_loaded()
	var energy_cfg: Dictionary = balance_config.get("energy", {})
	var econ_cfg: Dictionary = balance_config.get("economy", {})
	max_energy = maxi(1, int(energy_cfg.get("max_energy", 100)))
	energy = max_energy
	coins = int(econ_cfg.get("starting_coins", 150))

	village_level = 1
	farmer_xp = 0
	farmer_level = 1
	skill_points = 0
	selected_hotbar_index = 0
	active_field_id = "field_1"

	time_weather = TimeWeatherManager.new(balance_config)
	fields.clear()
	var field_1 := GridSimulation.new(balance_config, crops_db)
	sync_state_to_field(field_1)
	fields["field_1"] = field_1

	inventory = InventoryManager.new(items_db)
	inventory.setup_starter_inventory()
	state_changed.emit()


func get_active_field() -> GridSimulation:
	if fields.has(active_field_id):
		var active_raw: Variant = fields[active_field_id]
		if active_raw is GridSimulation:
			return active_raw
	for key: Variant in fields.keys():
		var raw_field: Variant = fields[key]
		if raw_field is GridSimulation:
			active_field_id = str(key)
			return raw_field
	return null


func sync_field_resources_to_state(field: GridSimulation) -> void:
	if field == null:
		return
	energy = clampi(field.energy, 0, max_energy)
	coins = field.coins
	for key: Variant in fields.keys():
		var raw_other: Variant = fields[key]
		if raw_other is GridSimulation and raw_other != field:
			sync_state_to_field(raw_other)
	state_changed.emit()


func sync_state_to_field(field: GridSimulation) -> void:
	if field == null:
		return
	field.max_energy = max_energy
	field.energy = clampi(energy, 0, max_energy)
	field.coins = coins


func advance_day(auto_save: bool = true) -> Dictionary:
	_ensure_data_loaded()
	if time_weather == null:
		time_weather = TimeWeatherManager.new(balance_config)
	if inventory == null:
		inventory = InventoryManager.new(items_db)

	var weather: Dictionary = time_weather.advance_day()
	energy = max_energy

	var total_grown: int = 0
	var total_ready: int = 0
	var total_stressed: int = 0
	var total_withered: int = 0
	var field_summaries: Dictionary = {}

	for key: Variant in fields.keys():
		var raw_field: Variant = fields[key]
		if raw_field is GridSimulation:
			var field: GridSimulation = raw_field
			sync_state_to_field(field)
			var f_sum: Dictionary = field.simulate_day_step(weather)
			field_summaries[str(key)] = f_sum
			total_grown += int(f_sum.get("crops_grown", 0))
			total_ready += int(f_sum.get("crops_ready", 0))
			total_stressed += int(f_sum.get("crops_stressed", 0))
			total_withered += int(f_sum.get("crops_withered", 0))

	var freshness: Dictionary = inventory.tick_freshness()

	var summary: Dictionary = {
		"weather": weather,
		"crops_grown": total_grown,
		"crops_ready": total_ready,
		"crops_stressed": total_stressed,
		"crops_withered": total_withered,
		"expired_count": int(freshness.get("expired_count", 0)),
		"expired_items": freshness.get("expired_items", []),
		"field_summaries": field_summaries,
	}

	if auto_save:
		var save_mgr: Node = _get_save_manager()
		if save_mgr != null:
			save_mgr.call("save_game", self)

	day_advanced.emit(summary)
	state_changed.emit()
	return summary


func to_dict() -> Dictionary:
	var fields_data: Dictionary = {}
	for key: Variant in fields.keys():
		var raw_field: Variant = fields[key]
		if raw_field is GridSimulation:
			var field: GridSimulation = raw_field
			fields_data[str(key)] = field.to_dict()

	return {
		"active_field_id": active_field_id,
		"coins": coins,
		"energy": energy,
		"max_energy": max_energy,
		"village_level": village_level,
		"farmer_xp": farmer_xp,
		"farmer_level": farmer_level,
		"skill_points": skill_points,
		"selected_hotbar_index": selected_hotbar_index,
		"time_weather": time_weather.to_dict() if time_weather != null else {},
		"inventory": inventory.to_dict() if inventory != null else {},
		"fields": fields_data,
	}


func from_dict(data: Dictionary) -> void:
	_ensure_data_loaded()
	var energy_cfg: Dictionary = balance_config.get("energy", {})
	var econ_cfg: Dictionary = balance_config.get("economy", {})
	var default_max_e: int = int(energy_cfg.get("max_energy", 100))
	var default_coins: int = int(econ_cfg.get("starting_coins", 150))

	max_energy = maxi(1, int(data.get("max_energy", default_max_e)))
	energy = clampi(int(data.get("energy", max_energy)), 0, max_energy)
	coins = int(data.get("coins", default_coins))
	village_level = maxi(1, int(data.get("village_level", 1)))
	farmer_xp = maxi(0, int(data.get("farmer_xp", 0)))
	farmer_level = maxi(1, int(data.get("farmer_level", 1)))
	skill_points = maxi(0, int(data.get("skill_points", 0)))
	selected_hotbar_index = clampi(int(data.get("selected_hotbar_index", 0)), 0, InventoryManager.HOTBAR_SIZE - 1)
	active_field_id = str(data.get("active_field_id", "field_1"))

	time_weather = TimeWeatherManager.new(balance_config)
	var raw_tw: Variant = data.get("time_weather", {})
	if raw_tw is Dictionary:
		var tw_dict: Dictionary = raw_tw
		if not tw_dict.is_empty():
			time_weather.from_dict(tw_dict)

	inventory = InventoryManager.new(items_db)
	var raw_inv: Variant = data.get("inventory", {})
	if raw_inv is Dictionary:
		var inv_dict: Dictionary = raw_inv
		if not inv_dict.is_empty():
			inventory.from_dict(inv_dict)
		else:
			inventory.setup_starter_inventory()
	else:
		inventory.setup_starter_inventory()

	fields.clear()
	var raw_fields: Variant = data.get("fields", {})
	if raw_fields is Dictionary:
		var fields_dict: Dictionary = raw_fields
		for key: Variant in fields_dict.keys():
			var raw_f: Variant = fields_dict[key]
			if raw_f is Dictionary:
				var f_dict: Dictionary = raw_f
				var sim := GridSimulation.new(balance_config, crops_db)
				sim.from_dict(f_dict)
				sync_state_to_field(sim)
				fields[str(key)] = sim

	if fields.is_empty():
		var fallback := GridSimulation.new(balance_config, crops_db)
		sync_state_to_field(fallback)
		fields["field_1"] = fallback

	if not fields.has(active_field_id):
		active_field_id = str(fields.keys()[0])

	state_changed.emit()
