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


func _init_cells() -> void:
	cells.clear()
	var default_fert := float(config.get("soil", {}).get("default_fertility", 65.0))
	for y in range(height):
		for x in range(width):
			var variant := (x * 7 + y * 13) % 3
			cells.append({
				"x": x,
				"y": y,
				"soil_state": SoilState.INCOLTO,
				"moisture": 20.0,
				"fertility": default_fert,
				"waterlogged_days": 0,
				"grass_variant": variant,
				"crop": {},
			})


func is_valid(x: int, y: int) -> bool:
	return x >= 0 and x < width and y >= 0 and y < height


func get_cell(x: int, y: int) -> Dictionary:
	if not is_valid(x, y):
		return {}
	return cells[y * width + x]


func get_energy_cost(action_key: String) -> int:
	var costs: Dictionary = config.get("energy", {}).get("costs", {})
	return int(costs.get(action_key, 0))


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
	if not cell["crop"].is_empty():
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
	var def: Dictionary = crops_db[crop_id]
	var base_yield := int(def.get("base_yield", 1))
	var total_days := maxi(1, int(crop.get("days_alive", 1)))
	var off_ratio := float(crop.get("off_season_days", 0)) / float(total_days)
	var yield_mult := 0.65 if off_ratio > 0.35 else 1.0
	var actual_yield := maxi(1, int(round(float(base_yield) * yield_mult)))
	var quality := "Scarsa" if float(crop.get("health", 100.0)) < 75.0 or off_ratio > 0.35 else "Standard"
	var price_mult := 0.7 if quality == "Scarsa" else 1.0
	var earned := int(round(float(def.get("sell_price", 10)) * float(actual_yield) * price_mult))
	coins += earned

	var fert_delta := float(def.get("soil_fertility_delta", -10))
	cell["fertility"] = clampf(float(cell["fertility"]) + fert_delta, 10.0, 100.0)

	if bool(def.get("multi_harvest", false)):
		var g_days := float(def.get("growth_days", 12))
		var regrow := float(def.get("regrow_days", 3))
		crop["growth_days_acc"] = maxf(0.0, g_days - regrow)
		crop["harvest_ready"] = false
		crop["stage"] = 3
	else:
		cell["crop"] = {}

	return {
		"ok": true,
		"action": "harvested",
		"crop_id": crop_id,
		"crop_name": str(def.get("name", crop_id)),
		"yield": actual_yield,
		"quality": quality,
		"earned": earned,
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
		if crop.is_empty() or bool(crop.get("withered", false)):
			continue

		var crop_def: Dictionary = crops_db.get(str(crop["crop_id"]), {})
		if crop_def.is_empty():
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

		var fert := float(cell["fertility"])
		var f_soil := 1.0
		if fert < 35.0:
			f_soil = 0.6
		elif fert > 75.0:
			f_soil = 1.15

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
