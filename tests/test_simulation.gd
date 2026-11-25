extends SceneTree
## Headless unit tests for Ortobio Milestone 1 (v0.1) simulation & climate logic.
## Run with: godot --headless --script res://tests/test_simulation.gd

var _failures: int = 0


func _init() -> void:
	_run_all()
	if _failures > 0:
		printerr("FAILED: %d assertion(s) failed." % _failures)
		quit(1)
	else:
		print("ALL TESTS PASSED!")
		quit(0)


func _assert(cond: bool, msg: String) -> void:
	if not cond:
		_failures += 1
		printerr("ASSERTION FAILED: %s" % msg)


func _run_all() -> void:
	var cfg := DataLoader.load_balance_config()
	var crops := DataLoader.load_crops()
	_assert(not cfg.is_empty(), "balance_config.json loaded")
	_assert(crops.has("ravanello") and crops.has("pomodoro") and crops.has("cavolo_verza"), "3 v0.1 crops loaded")

	# 1. Soil workflow & energy cost
	var sim := GridSimulation.new(cfg, crops)
	_assert(sim.width == 10 and sim.height == 30, "grid is 10x30")
	_assert(sim.plant_seed(0, 0, "ravanello")["ok"] == false, "cannot plant on untouched grass")
	_assert(sim.apply_rake(0, 0)["ok"] == false, "cannot rake before spading")
	_assert(sim.apply_spade(0, 0)["ok"] == true, "spade tills incolto -> vangato")
	_assert(sim.energy == 96, "spade consumes 4 energy")
	_assert(sim.apply_rake(0, 0)["ok"] == true, "rake prepares vangato -> rastrellato")
	_assert(sim.energy == 94, "rake consumes 2 energy")
	_assert(sim.plant_seed(0, 0, "ravanello")["ok"] == true, "seed plants on rastrellato at 0 energy")
	_assert(sim.energy == 94, "planting costs 0 energy")
	_assert(sim.apply_water(0, 0, "sole")["ok"] == true, "watering succeeds")

	# 2. Optimal spring growth of Ravanello (4 days)
	var tw := TimeWeatherManager.new(cfg, 12345)
	tw.set_weather_override("sole", 12.0, 20.0) # avg 16C (optimal for Ravanello)
	for _d in range(4):
		sim.get_cell(0, 0)["moisture"] = 60.0
		sim.simulate_day_step(tw.get_weather_snapshot())
	var rav_cell := sim.get_cell(0, 0)
	_assert(bool(rav_cell["crop"].get("harvest_ready", false)), "Ravanello ready in 4 optimal days")
	var h_res := sim.clear_withered_or_harvest(0, 0)
	_assert(bool(h_res["ok"]) and int(h_res["earned"]) == 25, "Harvesting Ravanello earns 25 coins")

	# 3. Off-season critical frost on Pomodoro in Winter
	sim.apply_spade(1, 0)
	sim.apply_rake(1, 0)
	sim.plant_seed(1, 0, "pomodoro")
	tw.set_weather_override("gelata", -2.0, 4.0) # below Pomodoro critical_min (6C)
	for _d in range(4):
		sim.simulate_day_step(tw.get_weather_snapshot())
	var pom_cell := sim.get_cell(1, 0)
	_assert(bool(pom_cell["crop"].get("withered", false)), "Pomodoro withers after 4 freezing days (-25 HP/day)")

	# 4. Cavolo Verza thrives in Winter cold (4C..10C)
	sim.apply_spade(2, 0)
	sim.apply_rake(2, 0)
	sim.plant_seed(2, 0, "cavolo_verza")
	tw.set_weather_override("nuvoloso", 2.0, 10.0) # avg 6C (optimal 4..16C for Cavolo)
	for _d in range(14):
		sim.get_cell(2, 0)["moisture"] = 60.0
		sim.simulate_day_step(tw.get_weather_snapshot())
	var cav_cell := sim.get_cell(2, 0)
	_assert(bool(cav_cell["crop"].get("harvest_ready", false)), "Cavolo Verza thrives and matures in winter")

	# 5. High summer heat never stresses or kills cool-season crops (heat stress removed)
	sim.apply_spade(3, 0)
	sim.apply_rake(3, 0)
	sim.plant_seed(3, 0, "ravanello")
	tw.set_weather_override("ondata_calore", 22.0, 40.0)
	for _d in range(5):
		sim.get_cell(3, 0)["moisture"] = 60.0
		sim.simulate_day_step(tw.get_weather_snapshot())
	var heat_cell := sim.get_cell(3, 0)
	_assert(not bool(heat_cell["crop"].get("withered", false)), "Ravanello does not die in summer heat")
	_assert(is_equal_approx(float(heat_cell["crop"].get("health", 0.0)), 100.0), "No HP loss from heat")

	# 6. Smart pause clock check
	var start_m := tw.minutes_of_day
	tw.tick(10.0, false)
	_assert(is_equal_approx(tw.minutes_of_day, start_m), "Smart pause freezes clock when inactive")
	tw.tick(10.0, true)
	_assert(tw.minutes_of_day > start_m, "Clock advances when field is active")
