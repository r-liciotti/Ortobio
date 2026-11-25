class_name GridSimulation
extends RefCounted
## Pure agronomic grid simulation for Ortobio, decoupled from Godot scene nodes.

enum SoilState {
	INCOLTO = 0,
	VANGATO = 1,
	RASTRELLATO = 2,
}

var width: int = 10
var height: int = 30
var config: Dictionary = {}
var crops_db: Dictionary = {}
var cells: Array[Dictionary] = []

var energy: int = 100
var max_energy: int = 100
var coins: int = 150


func _init(balance_config: Dictionary = {}, crops: Dictionary = {}) -> void:
	config = balance_config
	crops_db = crops
	var grid_cfg: Dictionary = config.get("grid", {})
	width = int(grid_cfg.get("width", 10))
	height = int(grid_cfg.get("height", 30))
	var energy_cfg: Dictionary = config.get("energy", {})
	max_energy = int(energy_cfg.get("max_energy", 100))
	energy = max_energy
	coins = int(config.get("economy", {}).get("starting_coins", 150))
	_init_cells()


func _make_default_cell(x: int, y: int) -> Dictionary:
	var soil_cfg: Dictionary = config.get("soil", {})
	var default_n: float = float(soil_cfg.get("default_n", 80.0))
	var default_p: float = float(soil_cfg.get("default_p", 80.0))
	var default_k: float = float(soil_cfg.get("default_k", 80.0))
	var variant: int = (x * 7 + y * 13) % 3
	var cell: Dictionary = {
		"x": x,
		"y": y,
		"soil_state": SoilState.INCOLTO,
		"moisture": 20.0,
		"n": default_n,
		"p": default_p,
		"k": default_k,
		"npk_analyzed": false,
		"fertility": 80.0,
		"fertilized": false,
		"waterlogged_days": 0,
		"grass_variant": variant,
		"crop": {},
	}
	_sync_fertility(cell)
	return cell


func _init_cells() -> void:
	cells.clear()
	for y in range(height):
		for x in range(width):
			cells.append(_make_default_cell(x, y))


func _normalize_crop(raw_crop: Dictionary) -> Dictionary:
	if raw_crop.is_empty():
		return {}
	return {
		"crop_id": str(raw_crop.get("crop_id", "")),
		"growth_days_acc": float(raw_crop.get("growth_days_acc", 0.0)),
		"health": float(raw_crop.get("health", 100.0)),
		"stage": int(raw_crop.get("stage", 0)),
		"harvest_ready": bool(raw_crop.get("harvest_ready", false)),
		"withered": bool(raw_crop.get("withered", false)),
		"stress_reason": str(raw_crop.get("stress_reason", "")),
		"days_alive": int(raw_crop.get("days_alive", 0)),
		"off_season_days": int(raw_crop.get("off_season_days", 0)),
		"days_ready": maxi(0, int(raw_crop.get("days_ready", 0))),
	}


func _normalize_cell(raw_cell: Dictionary, fallback_x: int = 0, fallback_y: int = 0) -> Dictionary:
	var cx: int = int(raw_cell.get("x", fallback_x))
	var cy: int = int(raw_cell.get("y", fallback_y))
	var crop_dict: Dictionary = {}
	var raw_crop: Variant = raw_cell.get("crop", {})
	if raw_crop is Dictionary:
		var raw_crop_dict: Dictionary = raw_crop
		crop_dict = _normalize_crop(raw_crop_dict)
	var cell: Dictionary = {
		"x": cx,
		"y": cy,
		"soil_state": clampi(int(raw_cell.get("soil_state", SoilState.INCOLTO)), SoilState.INCOLTO, SoilState.RASTRELLATO),
		"moisture": clampf(float(raw_cell.get("moisture", 20.0)), 0.0, 100.0),
		"n": clampf(float(raw_cell.get("n", 80.0)), 0.0, 100.0),
		"p": clampf(float(raw_cell.get("p", 80.0)), 0.0, 100.0),
		"k": clampf(float(raw_cell.get("k", 80.0)), 0.0, 100.0),
		"npk_analyzed": bool(raw_cell.get("npk_analyzed", false)),
		"fertility": float(raw_cell.get("fertility", 80.0)),
		"fertilized": bool(raw_cell.get("fertilized", false)),
		"waterlogged_days": maxi(0, int(raw_cell.get("waterlogged_days", 0))),
		"grass_variant": int(raw_cell.get("grass_variant", (cx * 7 + cy * 13) % 3)),
		"crop": crop_dict,
	}
	_sync_fertility(cell)
	return cell


func to_dict() -> Dictionary:
	var serialized_cells: Array[Dictionary] = []
	for cell: Dictionary in cells:
		serialized_cells.append(_normalize_cell(cell, int(cell.get("x", 0)), int(cell.get("y", 0))))
	return {
		"width": width,
		"height": height,
		"energy": energy,
		"max_energy": max_energy,
		"coins": coins,
		"cells": serialized_cells,
	}


func from_dict(data: Dictionary) -> void:
	width = maxi(1, int(data.get("width", width)))
	height = maxi(1, int(data.get("height", height)))
	max_energy = maxi(1, int(data.get("max_energy", max_energy)))
	energy = clampi(int(data.get("energy", max_energy)), 0, max_energy)
	coins = int(data.get("coins", coins))

	var expected_count: int = width * height
	var raw_cells: Variant = data.get("cells", [])
	if raw_cells is Array and (raw_cells as Array).size() == expected_count:
		var arr: Array = raw_cells
		cells.clear()
		for idx: int in range(expected_count):
			var fx: int = idx % width
			var fy: int = idx / width
			var entry: Variant = arr[idx]
			if entry is Dictionary:
				var entry_dict: Dictionary = entry
				cells.append(_normalize_cell(entry_dict, fx, fy))
			else:
				cells.append(_make_default_cell(fx, fy))
	else:
		_init_cells()
		if raw_cells is Array:
			var arr: Array = raw_cells
			for entry: Variant in arr:
				if entry is Dictionary:
					var entry_dict: Dictionary = entry
					var cx: int = int(entry_dict.get("x", -1))
					var cy: int = int(entry_dict.get("y", -1))
					if is_valid(cx, cy):
						cells[cy * width + cx] = _normalize_cell(entry_dict, cx, cy)


func _sync_fertility(cell: Dictionary) -> void:
	var n_val := float(cell.get("n", 80.0))
	var p_val := float(cell.get("p", 80.0))
	var k_val := float(cell.get("k", 80.0))
	cell["fertility"] = (n_val + p_val + k_val) / 3.0


func _apply_npk_delta(cell: Dictionary, delta: Dictionary, min_val: float = 0.0, max_val: float = 100.0) -> void:
	cell["n"] = clampf(float(cell["n"]) + float(delta.get("n", 0.0)), min_val, max_val)
	cell["p"] = clampf(float(cell["p"]) + float(delta.get("p", 0.0)), min_val, max_val)
	cell["k"] = clampf(float(cell["k"]) + float(delta.get("k", 0.0)), min_val, max_val)
	_sync_fertility(cell)


func get_soil_nutrient_factor(cell: Dictionary, crop_def: Dictionary) -> float:
	var raw_primary: Variant = crop_def.get("primary_element", "none")
	var primary := "none" if raw_primary == null else str(raw_primary).strip_edges().to_lower()
	if primary.is_empty() or primary == "none":
		return 1.0
	if primary != "n" and primary != "p" and primary != "k":
		return 1.0
	var val := float(cell.get(primary, 80.0))
	if val < 30.0:
		return 0.55
	if val < 65.0:
		return 0.90
	return 1.15


func is_valid(x: int, y: int) -> bool:
	return x >= 0 and x < width and y >= 0 and y < height


func get_cell(x: int, y: int) -> Dictionary:
	if not is_valid(x, y):
		return {}
	return cells[y * width + x]


func get_energy_cost(action_key: String) -> int:
	var energy_cfg: Dictionary = config.get("energy", {})
	var costs: Dictionary = energy_cfg.get("costs", {})
	if costs.has(action_key):
		return int(costs[action_key])
	match action_key:
		"spade":
			return 4
		"rake":
			return 2
		"water":
			return 2
		"compost":
			return 2
		"probe":
			return 1
		_:
			return 0


func _consume_energy(cost: int) -> bool:
	if cost <= 0:
		return true
	if energy < cost:
		return false
	energy -= cost
	return true


func apply_spade(x: int, y: int) -> Dictionary:
	if not is_valid(x, y):
		return {"ok": false, "reason": "out_of_bounds"}
	var cell := get_cell(x, y)
	var crop: Dictionary = cell["crop"]
	if not crop.is_empty():
		var crop_id := str(crop.get("crop_id", ""))
		var crop_def: Dictionary = crops_db.get(crop_id, {})
		var is_gm := bool(crop_def.get("is_green_manure", false))
		if is_gm and bool(crop.get("harvest_ready", false)) and not bool(crop.get("withered", false)):
			var gm_cost := get_energy_cost("spade")
			if not _consume_energy(gm_cost):
				return {"ok": false, "reason": "no_energy"}
			var npk_delta: Dictionary = crop_def.get("npk_delta", {})
			_apply_npk_delta(cell, npk_delta, 0.0, 100.0)
			cell["fertilized"] = true
			cell["crop"] = {}
			cell["soil_state"] = SoilState.RASTRELLATO
			return {
				"ok": true,
				"action": "green_manure_tilled",
				"energy_cost": gm_cost,
				"crop_id": crop_id,
			}
		return {"ok": false, "reason": "crop_present"}
	if int(cell["soil_state"]) != SoilState.INCOLTO:
		return {"ok": false, "reason": "already_tilled"}
	var cost := get_energy_cost("spade")
	if not _consume_energy(cost):
		return {"ok": false, "reason": "no_energy"}
	cell["soil_state"] = SoilState.VANGATO
	return {"ok": true, "energy_cost": cost}


func apply_rake(x: int, y: int) -> Dictionary:
	if not is_valid(x, y):
		return {"ok": false, "reason": "out_of_bounds"}
	var cell := get_cell(x, y)
	if not cell["crop"].is_empty():
		return {"ok": false, "reason": "crop_present"}
	if int(cell["soil_state"]) != SoilState.VANGATO:
		return {"ok": false, "reason": "needs_spade"}
	var cost := get_energy_cost("rake")
	if not _consume_energy(cost):
		return {"ok": false, "reason": "no_energy"}
	cell["soil_state"] = SoilState.RASTRELLATO
	return {"ok": true, "energy_cost": cost}


func apply_water(x: int, y: int, weather_type: String = "sole") -> Dictionary:
	if not is_valid(x, y):
		return {"ok": false, "reason": "out_of_bounds"}
	var cell := get_cell(x, y)
	if int(cell["soil_state"]) == SoilState.INCOLTO:
		return {"ok": false, "reason": "untilled"}
	var cost := 0 if weather_type == "pioggia" else get_energy_cost("water")
	if not _consume_energy(cost):
		return {"ok": false, "reason": "no_energy"}
	var add_amt := float(config.get("soil", {}).get("moisture_water_add", 65.0))
	cell["moisture"] = clampf(float(cell["moisture"]) + add_amt, 0.0, 100.0)
	return {"ok": true, "energy_cost": cost}


func apply_compost(x: int, y: int) -> Dictionary:
	if not is_valid(x, y):
		return {"ok": false, "reason": "out_of_bounds"}
	var cell := get_cell(x, y)
	if int(cell["soil_state"]) == SoilState.INCOLTO:
		return {"ok": false, "reason": "untilled"}
	var cost := get_energy_cost("compost")
	if not _consume_energy(cost):
		return {"ok": false, "reason": "no_energy"}
	var soil_cfg: Dictionary = config.get("soil", {})
	var default_compost: Dictionary = {"n": 22.0, "p": 18.0, "k": 18.0}
	var delta: Dictionary = soil_cfg.get("compost_delta", default_compost)
	if delta.is_empty():
		delta = default_compost
	_apply_npk_delta(cell, delta, 0.0, 100.0)
	cell["fertilized"] = true
	return {"ok": true, "energy_cost": cost}


func apply_probe(x: int, y: int) -> Dictionary:
	## Sonda Analisi Suolo: reveals N-P-K values on a tilled cell.
	if not is_valid(x, y):
		return {"ok": false, "reason": "out_of_bounds"}
	var cell := get_cell(x, y)
	if int(cell["soil_state"]) == SoilState.INCOLTO:
		return {"ok": false, "reason": "untilled"}
	var cost := get_energy_cost("probe")
	if not _consume_energy(cost):
		return {"ok": false, "reason": "no_energy"}
	cell["npk_analyzed"] = true
	return {
		"ok": true,
		"energy_cost": cost,
		"n": float(cell["n"]),
		"p": float(cell["p"]),
		"k": float(cell["k"]),
	}


func plant_seed(x: int, y: int, crop_id: String) -> Dictionary:
	if not is_valid(x, y):
		return {"ok": false, "reason": "out_of_bounds"}
	if not crops_db.has(crop_id):
		return {"ok": false, "reason": "unknown_crop"}
	var cell := get_cell(x, y)
	if int(cell["soil_state"]) != SoilState.RASTRELLATO:
		return {"ok": false, "reason": "needs_rake"}
	if not cell["crop"].is_empty():
		return {"ok": false, "reason": "crop_present"}
	cell["crop"] = {
		"crop_id": crop_id,
		"growth_days_acc": 0.0,
		"health": 100.0,
		"stage": 0,
		"harvest_ready": false,
		"withered": false,
		"stress_reason": "",
		"days_alive": 0,
		"off_season_days": 0,
		"days_ready": 0,
	}
	return {"ok": true, "energy_cost": 0, "crop_id": crop_id}


func clear_withered_or_harvest(x: int, y: int) -> Dictionary:
	## Harvests a ready crop or clears a withered crop (0 energy).
	if not is_valid(x, y):
		return {"ok": false, "reason": "out_of_bounds"}
	var cell := get_cell(x, y)
	var crop: Dictionary = cell["crop"]
	if crop.is_empty():
		return {"ok": false, "reason": "no_crop"}
	if bool(crop.get("withered", false)):
		cell["crop"] = {}
		return {"ok": true, "action": "cleared_withered"}
	if not bool(crop.get("harvest_ready", false)):
		return {"ok": false, "reason": "not_ready"}

	var crop_id := str(crop["crop_id"])
	var def: Dictionary = crops_db.get(crop_id, {})
	if bool(def.get("is_green_manure", false)):
		return {"ok": false, "reason": "use_spade_green_manure"}

	var base_yield := int(def.get("base_yield", 2))
	var nutr_f := get_soil_nutrient_factor(cell, def)
	var total_days := maxi(1, int(crop.get("days_alive", 1)))
	var off_ratio := float(crop.get("off_season_days", 0)) / float(total_days)
	var mult := nutr_f * (0.75 if off_ratio > 0.35 else 1.0)
	var actual_yield := maxi(1, int(round(float(base_yield) * mult)))
	var earned := int(def.get("sell_price", 10)) * actual_yield
	coins += earned

	var npk_delta: Dictionary = def.get("npk_delta", {})
	_apply_npk_delta(cell, npk_delta, 5.0, 100.0)

	if bool(def.get("multi_harvest", false)):
		var g_days := float(def.get("growth_days", 12))
		var regrow := float(def.get("regrow_days", 3))
		crop["growth_days_acc"] = maxf(0.0, g_days - regrow)
		crop["harvest_ready"] = false
		crop["days_ready"] = 0
		crop["stage"] = 3
	else:
		cell["crop"] = {}

	if float(npk_delta.get("n", 0.0)) > 0.0:
		cell["fertilized"] = true
	else:
		cell["fertilized"] = false

	return {
		"ok": true,
		"action": "harvested",
		"crop_id": crop_id,
		"crop_name": str(def.get("name", crop_id)),
		"yield": actual_yield,
		"earned": earned,
		"npk_delta": npk_delta,
	}


func evaluate_crop_thermal_status(crop_def: Dictionary, weather: Dictionary) -> Dictionary:
	## Shared thermal evaluation used by both daily growth and TileInspector UI.
	## Heat never stresses or kills crops (only slows growth if above optimal range).
	var temp_cfg: Dictionary = crop_def.get("temp", {})
	var t_min := float(weather.get("temp_min", 10.0))
	var t_max := float(weather.get("temp_max", 20.0))
	var t_avg := float(weather.get("temp_avg", (t_min + t_max) * 0.5))

	var crit_min := float(temp_cfg.get("critical_min", 0.0))
	var opt_min := float(temp_cfg.get("optimal_min", 12.0))
	var opt_max := float(temp_cfg.get("optimal_max", 24.0))

	if t_min < crit_min:
		return {"f_temp": 0.0, "status": "frost", "label": "Critico (Gelo)"}
	if t_avg >= opt_min and t_avg <= opt_max:
		return {"f_temp": 1.0, "status": "optimal", "label": "Ottimale"}
	return {"f_temp": 0.5, "status": "suboptimal", "label": "Sub-ottimale (Lenta)"}


func simulate_day_step(weather: Dictionary) -> Dictionary:
	## Advances soil moisture and all planted crops by 1 full day.
	energy = max_energy
	var soil_cfg: Dictionary = config.get("soil", {})
	var dry_thresh := float(soil_cfg.get("moisture_dry_threshold", 25.0))
	var wet_thresh := float(soil_cfg.get("moisture_waterlogged_threshold", 82.0))
	var rain_add := float(soil_cfg.get("moisture_rain_add", 55.0))
	var evap_base := float(soil_cfg.get("moisture_evap_base", 22.0))
	var wl_penalty_days := int(soil_cfg.get("waterlogged_penalty_days", 2))
	var rest_regen := float(soil_cfg.get("rest_regen_per_day", 0.5))

	var w_type := str(weather.get("weather_type", "sole"))
	var t_max := float(weather.get("temp_max", 20.0))
	var evap := evap_base
	if t_max >= 28.0:
		evap += 10.0
	elif t_max <= 10.0:
		evap -= 8.0

	var summary := {
		"crops_grown": 0,
		"crops_ready": 0,
		"crops_stressed": 0,
		"crops_withered": 0,
	}

	for cell in cells:
		var m := float(cell["moisture"])
		if w_type == "pioggia":
			m = clampf(m + rain_add, 0.0, 100.0)
		elif w_type == "neve":
			m = clampf(m + 10.0, 0.0, 100.0)
		else:
			m = clampf(m - evap, 0.0, 100.0)
		cell["moisture"] = m

		if m > wet_thresh:
			cell["waterlogged_days"] = int(cell["waterlogged_days"]) + 1
		else:
			cell["waterlogged_days"] = 0

		var crop: Dictionary = cell["crop"]
		if crop.is_empty():
			var cur_n := float(cell["n"])
			var cur_p := float(cell["p"])
			var cur_k := float(cell["k"])
			if cur_n < 80.0 or cur_p < 80.0 or cur_k < 80.0:
				if cur_n < 80.0:
					cell["n"] = minf(80.0, cur_n + rest_regen)
				if cur_p < 80.0:
					cell["p"] = minf(80.0, cur_p + rest_regen)
				if cur_k < 80.0:
					cell["k"] = minf(80.0, cur_k + rest_regen)
				_sync_fertility(cell)
			continue
		if bool(crop.get("withered", false)):
			continue

		var crop_def: Dictionary = crops_db.get(str(crop["crop_id"]), {})
		if crop_def.is_empty():
			continue

		if bool(crop.get("harvest_ready", false)):
			var next_days_ready: int = int(crop.get("days_ready", 0)) + 1
			crop["days_ready"] = next_days_ready
			var max_ready: int = maxi(1, int(crop_def.get("overripe_days", 4)))
			if next_days_ready >= max_ready:
				crop["withered"] = true
				crop["harvest_ready"] = false
				crop["stage"] = 5
				crop["health"] = 0.0
				crop["stress_reason"] = "overripe"
				summary["crops_withered"] = int(summary["crops_withered"]) + 1
				continue

		crop["days_alive"] = int(crop.get("days_alive", 0)) + 1

		var thermal := evaluate_crop_thermal_status(crop_def, weather)
		var f_temp := float(thermal["f_temp"])
		var thermal_status := str(thermal["status"])

		# Check germination minimum on stage 0 seeds
		var germ_min := float(crop_def.get("temp", {}).get("germination_min", 5.0))
		if float(crop["growth_days_acc"]) <= 0.01 and t_max < germ_min and f_temp > 0.0:
			f_temp = 0.0
			thermal_status = "cold_dormant"

		var f_water := 1.0
		if m < dry_thresh:
			f_water = 0.25
		elif int(cell["waterlogged_days"]) >= wl_penalty_days:
			f_water = 0.6

		var f_soil := get_soil_nutrient_factor(cell, crop_def)

		if thermal_status == "frost":
			crop["health"] = maxf(0.0, float(crop["health"]) - 25.0)
			crop["stress_reason"] = "frost"
			crop["off_season_days"] = int(crop.get("off_season_days", 0)) + 1
			summary["crops_stressed"] += 1
		elif thermal_status == "suboptimal":
			crop["health"] = minf(100.0, float(crop["health"]) + 10.0)
			crop["off_season_days"] = int(crop.get("off_season_days", 0)) + 1
			crop["stress_reason"] = ""
		else:
			crop["health"] = minf(100.0, float(crop["health"]) + 15.0)
			crop["stress_reason"] = "dry" if f_water < 0.5 else ("waterlogged" if f_water < 0.8 else "")

		if float(crop["health"]) <= 0.0:
			crop["withered"] = true
			crop["stage"] = 5
			crop["harvest_ready"] = false
			summary["crops_withered"] += 1
			continue

		if not bool(crop.get("harvest_ready", false)):
			var advance := 1.0 * f_temp * f_water * f_soil
			crop["growth_days_acc"] = float(crop["growth_days_acc"]) + advance
			if advance > 0.0:
				summary["crops_grown"] += 1

		var target_days := maxf(1.0, float(crop_def.get("growth_days", 4)))
		var progress := clampf(float(crop["growth_days_acc"]) / target_days, 0.0, 1.0)
		if progress >= 1.0:
			crop["harvest_ready"] = true
			crop["stage"] = 4
			summary["crops_ready"] += 1
		elif float(crop["health"]) < 60.0 or thermal_status == "frost":
			crop["stage"] = 5
		elif progress >= 0.70:
			crop["stage"] = 3
		elif progress >= 0.35:
			crop["stage"] = 2
		elif progress >= 0.05:
			crop["stage"] = 1
		else:
			crop["stage"] = 0

	return summary
