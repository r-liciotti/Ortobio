extends SceneTree
## Headless unit tests for Ortobio v0.2a simulation, N-P-K & climate logic.
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
	_assert(
		crops.has("ravanello") and crops.has("pomodoro") and crops.has("cavolo_verza")
		and crops.has("piselli") and crops.has("trifoglio"),
		"5 v0.2a crops loaded"
	)

	# 1. Soil workflow, initial N-P-K & energy cost
	var sim := GridSimulation.new(cfg, crops)
	_assert(sim.width == 10 and sim.height == 30, "grid is 10x30")
	var c0 := sim.get_cell(0, 0)
	_assert(
		is_equal_approx(float(c0["n"]), 80.0)
		and is_equal_approx(float(c0["p"]), 80.0)
		and is_equal_approx(float(c0["k"]), 80.0)
		and is_equal_approx(float(c0["fertility"]), 80.0),
		"cells start with N=80, P=80, K=80 and fertility=80"
	)
	_assert(bool(c0["npk_analyzed"]) == false, "npk_analyzed starts false")
	_assert(bool(c0["fertilized"]) == false, "fertilized starts false")
	_assert(sim.apply_probe(0, 0)["ok"] == false and str(sim.apply_probe(0, 0)["reason"]) == "untilled", "cannot probe incolto tile")
	_assert(sim.plant_seed(0, 0, "ravanello")["ok"] == false, "cannot plant on untouched grass")
	_assert(sim.apply_rake(0, 0)["ok"] == false, "cannot rake before spading")
	_assert(sim.apply_spade(0, 0)["ok"] == true, "spade tills incolto -> vangato")
	_assert(sim.energy == 96, "spade consumes 4 energy")
	_assert(sim.apply_rake(0, 0)["ok"] == true, "rake prepares vangato -> rastrellato")
	_assert(sim.energy == 94, "rake consumes 2 energy")
	_assert(sim.plant_seed(0, 0, "ravanello")["ok"] == true, "seed plants on rastrellato at 0 energy")
	_assert(sim.energy == 94, "planting costs 0 energy")
	_assert(sim.apply_water(0, 0, "sole")["ok"] == true, "watering succeeds")

	# 1b. Probe reveals N-P-K and costs 1 energy
	var energy_before_probe := sim.energy
	var probe_res := sim.apply_probe(0, 0)
	_assert(bool(probe_res["ok"]) and int(probe_res["energy_cost"]) == 1, "apply_probe succeeds and reports cost 1")
	_assert(sim.energy == energy_before_probe - 1, "apply_probe consumes 1 energy")
	_assert(bool(sim.get_cell(0, 0)["npk_analyzed"]) == true, "apply_probe sets npk_analyzed to true")
	_assert(is_equal_approx(float(probe_res["n"]), 80.0), "apply_probe returns cell N value")

	# 2. Optimal spring growth of Ravanello (4 days) & v0.2a yield + gentle N-P-K depletion
	var tw := TimeWeatherManager.new(cfg, 12345)
	tw.set_weather_override("sole", 12.0, 20.0) # avg 16C (optimal for Ravanello)
	for _d in range(4):
		sim.get_cell(0, 0)["moisture"] = 60.0
		sim.simulate_day_step(tw.get_weather_snapshot())
	var rav_cell := sim.get_cell(0, 0)
	_assert(bool(rav_cell["crop"].get("harvest_ready", false)), "Ravanello ready in 4 optimal days")
	var h_res := sim.clear_withered_or_harvest(0, 0)
	_assert(bool(h_res["ok"]) and int(h_res["yield"]) == 2 and int(h_res["earned"]) == 28, "Harvesting Ravanello yields 2 pieces and earns 28 coins")
	_assert(not h_res.has("quality"), "Old quality field removed in favor of piece yield")
	_assert(
		is_equal_approx(float(rav_cell["n"]), 77.0)
		and is_equal_approx(float(rav_cell["p"]), 69.0)
		and is_equal_approx(float(rav_cell["k"]), 77.0),
		"Ravanello gently depletes N(-3), P(-11), K(-3) on harvest"
	)
	_assert(
		is_equal_approx(float(rav_cell["fertility"]), (77.0 + 69.0 + 77.0) / 3.0),
		"fertility stays synced as average of N, P, K"
	)

	# 3. Off-season critical frost on Pomodoro in Winter
	sim.apply_spade(1, 0)
	sim.apply_rake(1, 0)
	sim.plant_seed(1, 0, "pomodoro")
	tw.set_weather_override("gelata", -2.0, 4.0) # below Pomodoro critical_min (6C)
	for _d in range(4):
		sim.simulate_day_step(tw.get_weather_snapshot())
	var pom_cell := sim.get_cell(1, 0)
	_assert(bool(pom_cell["crop"].get("withered", false)), "Pomodoro withers after 4 freezing days (-25 HP/day)")
	var clear_res := sim.clear_withered_or_harvest(1, 0)
	_assert(bool(clear_res["ok"]) and str(clear_res["action"]) == "cleared_withered", "Withered Pomodoro can be cleared")

	# 4. Cavolo Verza thrives in Winter cold (2C..10C)
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

	# 7. Poor soil slows growth and lowers piece yield without killing crop
	sim.apply_spade(4, 0)
	sim.apply_rake(4, 0)
	var poor_cell := sim.get_cell(4, 0)
	poor_cell["k"] = 20.0 # < 30.0 -> factor 0.55 for Pomodoro (primary_element = k)
	var pom_def: Dictionary = crops["pomodoro"]
	_assert(is_equal_approx(sim.get_soil_nutrient_factor(poor_cell, pom_def), 0.55), "Low primary nutrient gives 0.55 factor")
	sim.plant_seed(4, 0, "pomodoro")
	tw.set_weather_override("sole", 20.0, 28.0) # avg 24C (optimal for Pomodoro)
	for _d in range(12):
		poor_cell["moisture"] = 60.0
		sim.simulate_day_step(tw.get_weather_snapshot())
	_assert(not bool(poor_cell["crop"].get("withered", false)), "Poor soil never kills crop")
	_assert(is_equal_approx(float(poor_cell["crop"].get("health", 0.0)), 100.0), "Poor soil causes no HP loss")
	_assert(not bool(poor_cell["crop"].get("harvest_ready", false)), "Poor soil slows growth (not ready in 12 days)")
	for _d in range(10):
		poor_cell["moisture"] = 60.0
		sim.simulate_day_step(tw.get_weather_snapshot())
	_assert(bool(poor_cell["crop"].get("harvest_ready", false)), "Pomodoro eventually matures on poor soil")
	var poor_h := sim.clear_withered_or_harvest(4, 0)
	_assert(bool(poor_h["ok"]) and int(poor_h["yield"]) == 2, "Poor soil lowers Pomodoro yield from 3 to 2 pieces")
	_assert(float(poor_cell["k"]) >= 5.0, "Nutrient depletion clamps at minimum 5.0")

	# 8. Piselli regenerates N on harvest and regrows
	sim.apply_spade(5, 0)
	sim.apply_rake(5, 0)
	var pea_cell := sim.get_cell(5, 0)
	pea_cell["n"] = 40.0
	sim.plant_seed(5, 0, "piselli")
	tw.set_weather_override("sole", 12.0, 20.0) # avg 16C (optimal for Piselli)
	for _d in range(8):
		pea_cell["moisture"] = 60.0
		sim.simulate_day_step(tw.get_weather_snapshot())
	_assert(bool(pea_cell["crop"].get("harvest_ready", false)), "Piselli matures in 8 optimal days")
	var pea_h := sim.clear_withered_or_harvest(5, 0)
	_assert(bool(pea_h["ok"]) and int(pea_h["yield"]) == 3, "Piselli harvests 3 pieces on rich P soil")
	_assert(is_equal_approx(float(pea_cell["n"]), 58.0), "Piselli regenerates +18 N on harvest (40 -> 58)")
	_assert(is_equal_approx(float(pea_cell["p"]), 75.0) and is_equal_approx(float(pea_cell["k"]), 76.0), "Piselli gently consumes P(-5) and K(-4)")
	_assert(bool(pea_cell["fertilized"]) == true, "Harvesting N-fixing Piselli sets fertilized to true")
	_assert(not pea_cell["crop"].is_empty() and not bool(pea_cell["crop"].get("harvest_ready", false)), "Multi-harvest Piselli stays planted for regrow")

	# 9. Trifoglio matures in 3 days and apply_spade tills it in as green manure
	sim.apply_spade(6, 0)
	sim.apply_rake(6, 0)
	var gm_cell := sim.get_cell(6, 0)
	gm_cell["n"] = 40.0
	gm_cell["p"] = 50.0
	gm_cell["k"] = 50.0
	sim.plant_seed(6, 0, "trifoglio")
	_assert(sim.apply_spade(6, 0)["ok"] == false, "Cannot till immature green manure with spade")
	tw.set_weather_override("sole", 10.0, 22.0) # avg 16C (optimal for Trifoglio)
	for _d in range(3):
		gm_cell["moisture"] = 60.0
		sim.simulate_day_step(tw.get_weather_snapshot())
	_assert(bool(gm_cell["crop"].get("harvest_ready", false)), "Trifoglio matures in 3 days")
	var gm_harvest_attempt := sim.clear_withered_or_harvest(6, 0)
	_assert(
		not bool(gm_harvest_attempt["ok"])
		and str(gm_harvest_attempt["reason"]) == "use_spade_green_manure",
		"Green manure cannot be harvested for coins"
	)
	var e_before_gm := sim.energy
	_assert(bool(gm_cell["fertilized"]) == false, "Cell is not fertilized before green-manure till")
	var gm_till := sim.apply_spade(6, 0)
	_assert(
		bool(gm_till["ok"])
		and str(gm_till["action"]) == "green_manure_tilled"
		and int(gm_till["energy_cost"]) == 4
		and str(gm_till["crop_id"]) == "trifoglio",
		"apply_spade tills mature Trifoglio as green manure"
	)
	_assert(sim.energy == e_before_gm - 4, "Green manure spade till consumes 4 energy")
	_assert(bool(gm_cell["fertilized"]) == true, "Green-manure apply_spade sets fertilized to true")
	_assert(gm_cell["crop"].is_empty(), "Green manure crop cleared after tilling")
	_assert(int(gm_cell["soil_state"]) == GridSimulation.SoilState.RASTRELLATO, "Tile remains RASTRELLATO after tilling green manure")
	_assert(
		is_equal_approx(float(gm_cell["n"]), 72.0)
		and is_equal_approx(float(gm_cell["p"]), 66.0)
		and is_equal_approx(float(gm_cell["k"]), 64.0),
		"Trifoglio boosts N(+32), P(+16), K(+14)"
	)

	# 10. apply_compost boosts N-P-K and costs 2 energy
	_assert(sim.apply_compost(7, 0)["ok"] == false and str(sim.apply_compost(7, 0)["reason"]) == "untilled", "Cannot compost incolto tile")
	sim.apply_spade(7, 0)
	var comp_cell := sim.get_cell(7, 0)
	comp_cell["n"] = 50.0
	comp_cell["p"] = 50.0
	comp_cell["k"] = 50.0
	var e_before_comp := sim.energy
	_assert(bool(comp_cell["fertilized"]) == false, "Cell starts unfertilized before apply_compost")
	var comp_res := sim.apply_compost(7, 0)
	_assert(bool(comp_res["ok"]) and int(comp_res["energy_cost"]) == 2, "apply_compost succeeds and reports cost 2")
	_assert(sim.energy == e_before_comp - 2, "apply_compost consumes 2 energy")
	_assert(bool(comp_cell["fertilized"]) == true, "apply_compost sets fertilized to true")
	_assert(
		is_equal_approx(float(comp_cell["n"]), 72.0)
		and is_equal_approx(float(comp_cell["p"]), 68.0)
		and is_equal_approx(float(comp_cell["k"]), 68.0),
		"apply_compost boosts N(+22), P(+18), K(+18)"
	)
	sim.apply_compost(7, 0)
	sim.apply_compost(7, 0)
	_assert(
		is_equal_approx(float(comp_cell["n"]), 100.0)
		and is_equal_approx(float(comp_cell["p"]), 100.0)
		and is_equal_approx(float(comp_cell["k"]), 100.0),
		"apply_compost clamps N-P-K to 100.0"
	)

	# 10b. Harvesting non-legume Ravanello resets fertilized back to false
	_assert(sim.apply_rake(7, 0)["ok"] == true, "rake composted tile before planting Ravanello")
	_assert(sim.plant_seed(7, 0, "ravanello")["ok"] == true, "plant Ravanello on fertilized tile")
	_assert(bool(comp_cell["fertilized"]) == true, "fertilized remains true while Ravanello grows")
	tw.set_weather_override("sole", 12.0, 20.0)
	for _d in range(4):
		comp_cell["moisture"] = 60.0
		sim.simulate_day_step(tw.get_weather_snapshot())
	var rav_comp_h := sim.clear_withered_or_harvest(7, 0)
	_assert(bool(rav_comp_h["ok"]) and str(rav_comp_h["action"]) == "harvested", "Fertilized Ravanello harvests cleanly")
	_assert(bool(comp_cell["fertilized"]) == false, "Harvesting Ravanello resets fertilized to false")

	# 11. Empty tile rest regeneration (+0.5/day up to 80.0, preserves >80.0)
	var rest_cell := sim.get_cell(8, 0)
	rest_cell["n"] = 79.7
	rest_cell["p"] = 50.0
	rest_cell["k"] = 90.0
	sim.simulate_day_step(tw.get_weather_snapshot())
	_assert(
		is_equal_approx(float(rest_cell["n"]), 80.0)
		and is_equal_approx(float(rest_cell["p"]), 50.5)
		and is_equal_approx(float(rest_cell["k"]), 90.0),
		"Empty tile regenerates N/P/K by 0.5/day up to 80.0 without lowering >80.0"
	)

	# 12. Nutrient factor bands, rich-soil bonus yield, and off-season 0.75 yield multiplier
	var test_crops: Dictionary = {
		"test_crop": {
			"id": "test_crop",
			"name": "Test Crop",
			"temp": {"germination_min": 5, "critical_min": 0, "optimal_min": 10, "optimal_max": 22},
			"growth_days": 4,
			"primary_element": "n",
			"npk_delta": {"n": -10, "p": -2, "k": -2},
			"base_yield": 4,
			"sell_price": 10,
		},
		"none_crop": {"primary_element": "none"},
	}
	var sim2 := GridSimulation.new(cfg, test_crops)
	sim2.apply_spade(0, 0)
	sim2.apply_rake(0, 0)
	var rich_c := sim2.get_cell(0, 0)
	_assert(is_equal_approx(sim2.get_soil_nutrient_factor(rich_c, test_crops["test_crop"]), 1.15), "N>=65 gives 1.15 factor")
	rich_c["n"] = 50.0
	_assert(is_equal_approx(sim2.get_soil_nutrient_factor(rich_c, test_crops["test_crop"]), 0.90), "30<=N<65 gives 0.90 factor")
	rich_c["n"] = 80.0
	_assert(is_equal_approx(sim2.get_soil_nutrient_factor(rich_c, test_crops["none_crop"]), 1.0), "primary_element none gives 1.0 factor")
	sim2.plant_seed(0, 0, "test_crop")
	rich_c["crop"]["days_alive"] = 4
	rich_c["crop"]["off_season_days"] = 0
	rich_c["crop"]["harvest_ready"] = true
	var rich_h := sim2.clear_withered_or_harvest(0, 0)
	_assert(int(rich_h["yield"]) == 5 and int(rich_h["earned"]) == 50, "Rich soil gives bonus piece (4 * 1.15 -> 5)")

	sim2.plant_seed(0, 0, "test_crop")
	rich_c["n"] = 50.0 # factor 0.90
	rich_c["crop"]["days_alive"] = 4
	rich_c["crop"]["off_season_days"] = 2 # off_ratio = 0.5 > 0.35 -> * 0.75 -> 4 * 0.90 * 0.75 = 2.7 -> 3
	rich_c["crop"]["harvest_ready"] = true
	var off_h := sim2.clear_withered_or_harvest(0, 0)
	_assert(int(off_h["yield"]) == 3, "Off-season >0.35 ratio applies 0.75 yield multiplier")

	# 13. Insufficient energy guardrails for probe, compost, and green-manure spade
	sim2.apply_spade(1, 0)
	sim2.apply_rake(1, 0)
	var e_cell := sim2.get_cell(1, 0)
	sim2.energy = 0
	_assert(sim2.apply_probe(1, 0)["ok"] == false and str(sim2.apply_probe(1, 0)["reason"]) == "no_energy", "Probe fails with 0 energy")
	_assert(bool(e_cell["npk_analyzed"]) == false, "Failed probe does not reveal npk_analyzed")
	_assert(sim2.apply_compost(1, 0)["ok"] == false and str(sim2.apply_compost(1, 0)["reason"]) == "no_energy", "Compost fails with 0 energy")
	_assert(bool(e_cell["fertilized"]) == false, "Failed compost does not set fertilized")
	_assert(is_equal_approx(float(e_cell["n"]), 80.0), "Failed compost does not modify nutrients")

	sim.energy = 0
	sim.plant_seed(6, 0, "trifoglio")
	gm_cell["crop"]["harvest_ready"] = true
	_assert(sim.apply_spade(6, 0)["ok"] == false and str(sim.apply_spade(6, 0)["reason"]) == "no_energy", "Green-manure spade fails with 0 energy")
	_assert(not gm_cell["crop"].is_empty(), "Failed green-manure spade keeps crop intact")

	# 14. Overripe crop perishing (Ravanello overripe_days = 3)
	var sim_over := GridSimulation.new(cfg, crops)
	sim_over.apply_spade(0, 0)
	sim_over.apply_rake(0, 0)
	sim_over.plant_seed(0, 0, "ravanello")
	var over_cell: Dictionary = sim_over.get_cell(0, 0)
	_assert(int(over_cell["crop"].get("days_ready", -1)) == 0, "Newly planted crop starts with days_ready == 0")
	tw.set_weather_override("sole", 12.0, 20.0)
	for _d: int in range(4):
		over_cell["moisture"] = 60.0
		sim_over.simulate_day_step(tw.get_weather_snapshot())
	_assert(bool(over_cell["crop"].get("harvest_ready", false)), "Ravanello matures after 4 days")
	_assert(int(over_cell["crop"].get("days_ready", -1)) == 0, "Maturity day keeps days_ready == 0")
	for _d: int in range(2):
		over_cell["moisture"] = 60.0
		sim_over.simulate_day_step(tw.get_weather_snapshot())
	_assert(
		bool(over_cell["crop"].get("harvest_ready", false))
		and not bool(over_cell["crop"].get("withered", false))
		and int(over_cell["crop"].get("days_ready", -1)) == 2,
		"Ravanello stays harvestable for 2 additional days (days_ready == 2)"
	)
	over_cell["moisture"] = 60.0
	var over_sum: Dictionary = sim_over.simulate_day_step(tw.get_weather_snapshot())
	_assert(int(over_sum.get("crops_withered", 0)) == 1, "Summary reports 1 withered crop on 3rd overripe day")
	_assert(
		bool(over_cell["crop"].get("withered", false))
		and not bool(over_cell["crop"].get("harvest_ready", true))
		and str(over_cell["crop"].get("stress_reason", "")) == "overripe"
		and int(over_cell["crop"].get("stage", -1)) == 5
		and is_equal_approx(float(over_cell["crop"].get("health", -1.0)), 0.0),
		"Ravanello perishes as overripe on 3rd unharvested day"
	)
	var over_clear: Dictionary = sim_over.clear_withered_or_harvest(0, 0)
	_assert(bool(over_clear.get("ok", false)) and str(over_clear.get("action", "")) == "cleared_withered", "Overripe withered crop can be cleared")

	# Multi-harvest regrow resets days_ready
	sim_over.apply_spade(1, 0)
	sim_over.apply_rake(1, 0)
	sim_over.plant_seed(1, 0, "piselli")
	var multi_cell: Dictionary = sim_over.get_cell(1, 0)
	for _d: int in range(7):
		multi_cell["moisture"] = 60.0
		sim_over.simulate_day_step(tw.get_weather_snapshot())
	_assert(bool(multi_cell["crop"].get("harvest_ready", false)) and int(multi_cell["crop"].get("days_ready", -1)) == 0, "Piselli matures in 7 days on rich P soil with days_ready == 0")
	for _d: int in range(2):
		multi_cell["moisture"] = 60.0
		sim_over.simulate_day_step(tw.get_weather_snapshot())
	_assert(int(multi_cell["crop"].get("days_ready", 0)) == 2, "Piselli tracks days_ready == 2 before harvest")
	var multi_h: Dictionary = sim_over.clear_withered_or_harvest(1, 0)
	_assert(bool(multi_h.get("ok", false)) and int(multi_cell["crop"].get("days_ready", -1)) == 0, "Harvesting multi-harvest Piselli resets days_ready to 0")

	# 15. Projected sun shadow skew_x / scale_y parameters
	tw.set_weather_override("sole", 14.0, 22.0)
	tw.minutes_of_day = 6.0 * 60.0
	var sh_dawn: Dictionary = tw.get_sun_shadow_params()
	tw.minutes_of_day = 13.0 * 60.0
	var sh_noon: Dictionary = tw.get_sun_shadow_params()
	tw.minutes_of_day = 20.0 * 60.0
	var sh_dusk: Dictionary = tw.get_sun_shadow_params()
	_assert(float(sh_dawn.get("skew_x", 0.0)) < -0.9, "Dawn shadow skew_x leans West (< -0.9)")
	_assert(absf(float(sh_noon.get("skew_x", 99.0))) < 0.01, "Noon shadow skew_x is straight (~0.0)")
	_assert(float(sh_dusk.get("skew_x", 0.0)) > 0.9, "Sunset shadow skew_x leans East (> 0.9)")
	_assert(float(sh_dawn.get("scale_y", 0.0)) > float(sh_noon.get("scale_y", 99.0)), "Dawn shadow scale_y is longer than noon scale_y")
	_assert(float(sh_dusk.get("scale_y", 0.0)) > float(sh_noon.get("scale_y", 99.0)), "Sunset shadow scale_y is longer than noon scale_y")
