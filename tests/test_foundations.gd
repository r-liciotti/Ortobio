extends SceneTree
## Headless unit tests for Ortobio v0.2b core foundations:
## DataLoader items, InventoryManager, TimeWeatherManager forecast/serialization,
## GridSimulation serialization, GameState + SaveManager round-trip, and SceneManager.
## Run with: godot --headless --path . --script res://tests/test_foundations.gd

const SaveManagerScript := preload("res://core/save_manager.gd")
const GameStateScript := preload("res://core/game_state.gd")
const SceneManagerScript := preload("res://core/scene_manager.gd")

const TEST_SAVE_PATH := "/tmp/ortobio_test_save.json"

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
	var cfg: Dictionary = DataLoader.load_balance_config()
	var crops: Dictionary = DataLoader.load_crops()
	var items: Dictionary = DataLoader.load_items()

	_assert(not cfg.is_empty(), "balance_config.json loaded")
	_assert(not crops.is_empty(), "crops.json loaded")
	_assert(
		items.has("spade") and items.has("rake") and items.has("water") and items.has("probe")
		and items.has("compost") and items.has("seed_ravanello") and items.has("seed_pomodoro")
		and items.has("seed_cavolo_verza") and items.has("seed_piselli") and items.has("seed_trifoglio")
		and items.has("ravanello") and items.has("pomodoro") and items.has("cavolo_verza")
		and items.has("piselli") and items.has("scarti_vegetali"),
		"All 15 items loaded from data/items.json"
	)

	_test_inventory_manager(items)
	_test_time_weather_forecast_and_serialization(cfg)
	_test_time_weather_atmosphere(cfg)
	_test_game_state_and_save_round_trip(cfg, crops, items)
	_test_scene_manager()


func _test_inventory_manager(items: Dictionary) -> void:
	var inv := InventoryManager.new(items)
	inv.setup_starter_inventory()

	_assert(inv.hotbar.size() == 6, "Hotbar has exactly 6 slots")
	_assert(inv.backpack.size() == 24, "Backpack has exactly 24 slots")
	_assert(str(inv.get_slot("hotbar", 0).get("item_id", "")) == "spade", "Hotbar 0 is spade")
	_assert(str(inv.get_slot("hotbar", 1).get("item_id", "")) == "rake", "Hotbar 1 is rake")
	_assert(str(inv.get_slot("hotbar", 2).get("item_id", "")) == "water", "Hotbar 2 is water")
	_assert(str(inv.get_slot("hotbar", 3).get("item_id", "")) == "seed_ravanello", "Hotbar 3 is seed_ravanello")
	_assert(int(inv.get_slot("hotbar", 3).get("qty", 0)) == 10, "Hotbar 3 has 10 seed_ravanello")
	_assert(str(inv.get_slot("hotbar", 4).get("item_id", "")) == "seed_pomodoro", "Hotbar 4 is seed_pomodoro")
	_assert(str(inv.get_slot("hotbar", 5).get("item_id", "")) == "seed_cavolo_verza", "Hotbar 5 is seed_cavolo_verza")
	_assert(str(inv.get_slot("backpack", 0).get("item_id", "")) == "probe", "Backpack 0 is probe")
	_assert(str(inv.get_slot("backpack", 1).get("item_id", "")) == "compost", "Backpack 1 is compost")
	_assert(int(inv.get_slot("backpack", 1).get("qty", 0)) == 15, "Backpack 1 has 15 compost")
	_assert(str(inv.get_slot("backpack", 2).get("item_id", "")) == "seed_piselli", "Backpack 2 is seed_piselli")
	_assert(str(inv.get_slot("backpack", 3).get("item_id", "")) == "seed_trifoglio", "Backpack 3 is seed_trifoglio")
	_assert(inv.get_slot("backpack", 4).is_empty(), "Backpack 4 starts empty")

	# Swap slots between hotbar and backpack
	_assert(inv.swap_slots("hotbar", 0, "backpack", 0), "swap_slots succeeds")
	_assert(str(inv.get_slot("hotbar", 0).get("item_id", "")) == "probe", "Probe moved to hotbar 0")
	_assert(str(inv.get_slot("backpack", 0).get("item_id", "")) == "spade", "Spade moved to backpack 0")
	_assert(inv.swap_slots("hotbar", 0, "backpack", 0), "swap_slots back succeeds")
	_assert(not inv.swap_slots("hotbar", 99, "backpack", 0), "Invalid slot swap fails gracefully")

	# Tool durability damage -> broken at 0 -> repair
	var dmg1: Dictionary = inv.damage_tool_in_slot("hotbar", 0, 10)
	_assert(bool(dmg1.get("ok", false)) and int(dmg1.get("durability", -1)) == 50, "Spade durability drops 60 -> 50")
	_assert(not bool(dmg1.get("broken", true)) and not inv.is_tool_broken(inv.get_slot("hotbar", 0)), "Spade not broken at 50")
	var dmg2: Dictionary = inv.damage_tool_in_slot("hotbar", 0, 100)
	_assert(bool(dmg2.get("ok", false)) and int(dmg2.get("durability", -1)) == 0, "Spade durability clamps at 0")
	_assert(bool(dmg2.get("broken", false)) and inv.is_tool_broken(inv.get_slot("hotbar", 0)), "Spade broken at 0 durability")

	var rep: Dictionary = inv.repair_tool_in_slot("hotbar", 0)
	_assert(bool(rep.get("ok", false)) and int(rep.get("cost", 0)) == 15, "Repair returns cost 15")
	_assert(int(inv.get_slot("hotbar", 0).get("durability", 0)) == 60, "Repaired spade restored to 60")
	_assert(not inv.is_tool_broken(inv.get_slot("hotbar", 0)), "Repaired spade no longer broken")
	_assert(not bool(inv.repair_tool_in_slot("hotbar", 0).get("ok", true)), "Undamaged tool refuses repair")

	# Consume from stack and merge seeds
	_assert(inv.consume_from_slot("hotbar", 3, 4), "Consume 4 seed_ravanello succeeds")
	_assert(inv.get_total_item_count("seed_ravanello") == 6, "Remaining seed_ravanello count is 6")
	_assert(inv.add_item("seed_ravanello", 4) == 4, "Adding seed_ravanello merges into existing stack")
	_assert(int(inv.get_slot("hotbar", 3).get("qty", 0)) == 10, "Merged seed_ravanello back to 10 in hotbar 3")
	_assert(inv.consume_from_slot("hotbar", 3, 4), "Consume 4 seed_ravanello again for later test")
	_assert(inv.add_item("unknown_item", 1) == 0, "Unknown item returns 0")
	_assert(inv.add_item("ravanello", 0) == 0, "Zero qty returns 0")

	# Perishable crops: adding prefers backpack, merges same days_left, separates different days_left
	_assert(inv.add_item("ravanello", 3) == 3, "Added 3 fresh ravanello")
	_assert(str(inv.get_slot("backpack", 4).get("item_id", "")) == "ravanello", "Crop placed into first empty backpack slot (4)")
	_assert(int(inv.get_slot("backpack", 4).get("days_left", 0)) == 7, "Ravanello shelf life defaults to 7 days")
	_assert(inv.add_item("ravanello", 2) == 2, "Added 2 more fresh ravanello (merges)")
	_assert(int(inv.get_slot("backpack", 4).get("qty", 0)) == 5, "Fresh ravanello merged to qty 5")
	_assert(inv.add_item("ravanello", 1, 3) == 1, "Added 1 ravanello with different days_left (3)")
	_assert(str(inv.get_slot("backpack", 5).get("item_id", "")) == "ravanello" and int(inv.get_slot("backpack", 5).get("days_left", 0)) == 3, "Different days_left placed in separate slot (5)")
	_assert(inv.add_item("pomodoro", 2, 1) == 2, "Added 2 pomodoro with 1 day left")
	_assert(str(inv.get_slot("backpack", 6).get("item_id", "")) == "pomodoro", "Pomodoro placed in backpack 6")

	# Non-stackable tool placement
	_assert(inv.add_item("spade", 1) == 1, "Added extra spade (non-stackable)")
	_assert(str(inv.get_slot("backpack", 7).get("item_id", "")) == "spade", "Extra spade placed in first empty slot (backpack 7)")

	# Tick freshness: pomodoro expires into scarti_vegetali, ravanello drops days_left
	var tick1: Dictionary = inv.tick_freshness()
	_assert(int(tick1.get("expired_count", 0)) == 2, "2 pomodoro expired on tick_freshness")
	_assert(inv.get_total_item_count("pomodoro") == 0, "Expired pomodoro removed from inventory")
	_assert(str(inv.get_slot("backpack", 6).get("item_id", "")) == "scarti_vegetali", "Freed slot reused by scarti_vegetali")
	_assert(int(inv.get_slot("backpack", 4).get("days_left", 0)) == 6, "Ravanello days_left decremented 7 -> 6")
	_assert(int(inv.get_slot("backpack", 5).get("days_left", 0)) == 2, "Ravanello (3d) days_left decremented 3 -> 2")
	_assert(inv.get_total_item_count("scarti_vegetali") == 2, "Expired pomodoro converted to 2 scarti_vegetali")

	# Sell all crops sells both ravanello stacks (5 * 14 + 1 * 14 = 84) and leaves scarti_vegetali & seeds untouched
	var sell_res: Dictionary = inv.sell_all_crops()
	_assert(int(sell_res.get("sold_count", 0)) == 6, "sell_all_crops sold 6 pieces")
	_assert(int(sell_res.get("earned", 0)) == 84, "sell_all_crops earned 6 * 14 = 84")
	_assert(inv.get_total_item_count("ravanello") == 0, "Ravanello removed after selling")
	_assert(inv.get_total_item_count("scarti_vegetali") == 2, "scarti_vegetali (material) kept after sell_all_crops")
	_assert(inv.get_total_item_count("seed_ravanello") == 6, "Seeds kept after sell_all_crops")


func _test_time_weather_forecast_and_serialization(cfg: Dictionary) -> void:
	var tw := TimeWeatherManager.new(cfg, 424242)
	var tomorrow_before: Dictionary = tw.get_tomorrow_weather_snapshot()
	_assert(not tomorrow_before.is_empty(), "Tomorrow weather initialized at _init")
	_assert(int(tomorrow_before.get("day", 0)) == 2, "Tomorrow snapshot day is 2 on day 1")

	var today_after: Dictionary = tw.advance_day()
	_assert(int(today_after.get("day", 0)) == 2, "advance_day moves day to 2")
	_assert(str(today_after.get("weather_type", "")) == str(tomorrow_before.get("weather_type", "")), "Tomorrow weather_type promoted to today")
	_assert(is_equal_approx(float(today_after.get("temp_min", 0.0)), float(tomorrow_before.get("temp_min", -99.0))), "Tomorrow temp_min promoted to today")
	_assert(is_equal_approx(float(today_after.get("temp_max", 0.0)), float(tomorrow_before.get("temp_max", -99.0))), "Tomorrow temp_max promoted to today")
	_assert(is_equal_approx(float(today_after.get("temp_avg", 0.0)), float(tomorrow_before.get("temp_avg", -99.0))), "Tomorrow temp_avg promoted to today")

	var tomorrow_after: Dictionary = tw.get_tomorrow_weather_snapshot()
	_assert(int(tomorrow_after.get("day", 0)) == 3, "New tomorrow snapshot rolled for day 3")

	# End-of-season forecast uses next season
	tw.day_in_season = 28
	tw.season_index = 0
	tw.cycle_season_for_test()
	_assert(tw.get_season_id() == "estate" and tw.day_in_season == 1, "cycle_season_for_test advances to estate day 1")
	_assert(str(tw.get_tomorrow_weather_snapshot().get("season", "")) == "estate", "cycle_season_for_test rerolls tomorrow forecast")

	tw.day_in_season = 28
	tw._roll_weather_for_tomorrow()
	_assert(str(tw.get_tomorrow_weather_snapshot().get("season", "")) == "autunno", "Day 28 forecast rolls with next season (autunno)")

	# Serialization round-trip
	tw.minutes_of_day = 755.5
	var tw_dict: Dictionary = tw.to_dict()
	var tw2 := TimeWeatherManager.new(cfg, 999)
	tw2.from_dict(tw_dict)
	_assert(tw2.year == tw.year and tw2.season_index == tw.season_index and tw2.day_in_season == tw.day_in_season, "TimeWeatherManager date preserved across to_dict/from_dict")
	_assert(is_equal_approx(tw2.minutes_of_day, 755.5), "TimeWeatherManager minutes_of_day preserved")
	_assert(tw2.weather_type == tw.weather_type and is_equal_approx(tw2.temp_max, tw.temp_max), "TimeWeatherManager today weather preserved")
	_assert(
		str(tw2.tomorrow_weather.get("weather_type", "")) == str(tw.tomorrow_weather.get("weather_type", ""))
		and is_equal_approx(float(tw2.tomorrow_weather.get("temp_min", 0.0)), float(tw.tomorrow_weather.get("temp_min", -99.0)))
		and str(tw2.tomorrow_weather.get("season", "")) == str(tw.tomorrow_weather.get("season", "")),
		"TimeWeatherManager tomorrow_weather preserved"
	)


func _test_time_weather_atmosphere(cfg: Dictionary) -> void:
	var tw := TimeWeatherManager.new(cfg, 12345)
	tw.season_index = 0
	tw.set_weather_override("sole", 14.0, 24.0)

	# Morning 07:00: shadows point west (left) and are longer than noon
	tw.minutes_of_day = 7.0 * 60.0
	var morning_shadow: Dictionary = tw.get_sun_shadow_params()
	_assert(float(morning_shadow.get("offset_x", 0.0)) < -2.0, "Morning (07:00) sun shadow offset_x < -2.0")
	_assert(is_equal_approx(tw.get_night_intensity(), 0.0), "Morning night_intensity is 0.0")

	# Noon 13:00: shadows are centered and compact
	tw.minutes_of_day = 13.0 * 60.0
	var noon_shadow: Dictionary = tw.get_sun_shadow_params()
	var sunny_alpha: float = float(noon_shadow.get("alpha", 0.0))
	_assert(absf(float(noon_shadow.get("offset_x", 99.0))) < 1.0, "Noon (13:00) sun shadow absf(offset_x) < 1.0")
	_assert(float(morning_shadow.get("scale_x", 0.0)) > float(noon_shadow.get("scale_x", 99.0)), "Morning shadows longer than noon shadows")

	# Evening 19:00: shadows point east (right)
	tw.minutes_of_day = 19.0 * 60.0
	var evening_shadow: Dictionary = tw.get_sun_shadow_params()
	_assert(float(evening_shadow.get("offset_x", 0.0)) > 2.0, "Evening (19:00) sun shadow offset_x > 2.0")

	# Rain lowers shadow alpha compared to sunny
	tw.minutes_of_day = 13.0 * 60.0
	tw.set_weather_override("pioggia", 12.0, 17.0)
	var rain_shadow: Dictionary = tw.get_sun_shadow_params()
	_assert(float(rain_shadow.get("alpha", 99.0)) < sunny_alpha, "Rain weather lowers shadow alpha compared to sunny")

	# Night 22:30: high night intensity and dimmed night shadow + cool indigo modulate
	tw.set_weather_override("sole", 14.0, 24.0)
	tw.minutes_of_day = 13.0 * 60.0
	var noon_mod: Color = tw.get_daylight_modulate()
	tw.minutes_of_day = 22.5 * 60.0
	var night_shadow: Dictionary = tw.get_sun_shadow_params()
	var night_mod: Color = tw.get_daylight_modulate()
	_assert(tw.get_night_intensity() > 0.8, "Night (22:30) has get_night_intensity() > 0.8")
	_assert(float(night_shadow.get("alpha", 99.0)) < sunny_alpha, "Night fades shadow alpha down")
	_assert(night_mod.r < noon_mod.r and night_mod.b > night_mod.r, "Night daylight modulate shifts toward dark indigo")


func _test_game_state_and_save_round_trip(cfg: Dictionary, crops: Dictionary, items: Dictionary) -> void:
	var sm: Node = SaveManagerScript.new()
	var gs: Node = GameStateScript.new()
	var gs_loaded: Node = GameStateScript.new()
	sm.delete_save(TEST_SAVE_PATH)

	gs.balance_config = cfg
	gs.crops_db = crops
	gs.items_db = items
	gs.new_game()

	# Mutate GameState richly: advance a couple days, damage tools, add crops, till & plant & analyze & fertilize tile
	gs.advance_day(false)
	gs.coins = 345
	gs.selected_hotbar_index = 2
	gs.village_level = 2
	gs.farmer_xp = 85
	gs.farmer_level = 3
	gs.skill_points = 1

	var field: GridSimulation = gs.get_active_field()
	gs.sync_state_to_field(field)
	_assert(bool(field.apply_spade(2, 3).get("ok", false)), "Spade tile (2, 3)")
	_assert(bool(field.apply_rake(2, 3).get("ok", false)), "Rake tile (2, 3)")
	_assert(bool(field.apply_compost(2, 3).get("ok", false)), "Compost tile (2, 3)")
	_assert(bool(field.apply_probe(2, 3).get("ok", false)), "Probe tile (2, 3)")
	_assert(bool(field.plant_seed(2, 3, "pomodoro").get("ok", false)), "Plant pomodoro on (2, 3)")
	gs.sync_field_resources_to_state(field)

	# Grow pomodoro 1 day
	gs.advance_day(false)
	# Now spend some energy and damage tools
	field = gs.get_active_field()
	_assert(bool(field.apply_water(2, 3).get("ok", false)), "Water tile (2, 3)")
	gs.sync_field_resources_to_state(field)

	gs.inventory.damage_tool_in_slot("hotbar", 0, 17)
	gs.inventory.damage_tool_in_slot("backpack", 0, 5)
	gs.inventory.add_item("ravanello", 4, 5)
	gs.inventory.consume_from_slot("hotbar", 3, 3)

	var expected_day: int = gs.time_weather.day_in_season
	var expected_season: int = gs.time_weather.season_index
	var expected_tomorrow: Dictionary = gs.time_weather.get_tomorrow_weather_snapshot()
	var expected_coins: int = gs.coins
	var expected_energy: int = gs.energy
	var expected_spade_dur: int = int(gs.inventory.get_slot("hotbar", 0).get("durability", -1))
	var expected_probe_dur: int = int(gs.inventory.get_slot("backpack", 0).get("durability", -1))
	var expected_cell: Dictionary = field.get_cell(2, 3).duplicate(true)

	_assert(sm.save_game(gs, TEST_SAVE_PATH), "SaveManager saves GameState to temp path")
	_assert(sm.has_save(TEST_SAVE_PATH), "SaveManager.has_save reports true")

	# Reset gs_loaded cleanly to fresh state, then load saved JSON
	gs_loaded.balance_config = cfg
	gs_loaded.crops_db = crops
	gs_loaded.items_db = items
	gs_loaded.new_game()
	_assert(sm.load_game(gs_loaded, TEST_SAVE_PATH), "SaveManager loads GameState from temp path")

	_assert(gs_loaded.time_weather.day_in_season == expected_day, "Loaded day_in_season matches")
	_assert(gs_loaded.time_weather.season_index == expected_season, "Loaded season_index matches")
	var loaded_tomorrow: Dictionary = gs_loaded.time_weather.get_tomorrow_weather_snapshot()
	_assert(
		str(loaded_tomorrow.get("weather_type", "")) == str(expected_tomorrow.get("weather_type", ""))
		and is_equal_approx(float(loaded_tomorrow.get("temp_min", 0.0)), float(expected_tomorrow.get("temp_min", -99.0)))
		and is_equal_approx(float(loaded_tomorrow.get("temp_max", 0.0)), float(expected_tomorrow.get("temp_max", -99.0))),
		"Loaded tomorrow_weather matches"
	)
	_assert(gs_loaded.coins == expected_coins, "Loaded coins match")
	_assert(gs_loaded.energy == expected_energy, "Loaded energy matches")
	_assert(gs_loaded.selected_hotbar_index == 2, "Loaded selected_hotbar_index matches")
	_assert(gs_loaded.village_level == 2 and gs_loaded.farmer_xp == 85 and gs_loaded.farmer_level == 3 and gs_loaded.skill_points == 1, "Loaded progression matches")

	# Verify hotbar & backpack & tool durability
	_assert(int(gs_loaded.inventory.get_slot("hotbar", 0).get("durability", -1)) == expected_spade_dur, "Loaded spade durability matches")
	_assert(int(gs_loaded.inventory.get_slot("backpack", 0).get("durability", -1)) == expected_probe_dur, "Loaded probe durability matches")
	_assert(gs_loaded.inventory.get_total_item_count("seed_ravanello") == 7, "Loaded seed_ravanello count matches")
	_assert(gs_loaded.inventory.get_total_item_count("ravanello") == 4, "Loaded ravanello count matches")
	_assert(int(gs_loaded.inventory.get_slot("backpack", 4).get("days_left", -1)) == 5, "Loaded ravanello days_left matches")

	# Verify tile N-P-K, analyzed, fertilized, and crop
	var loaded_field: GridSimulation = gs_loaded.get_active_field()
	_assert(loaded_field.energy == expected_energy and loaded_field.coins == expected_coins, "Loaded field energy & coins synced with GameState")
	var loaded_cell: Dictionary = loaded_field.get_cell(2, 3)
	_assert(int(loaded_cell.get("soil_state", -1)) == int(expected_cell.get("soil_state", -2)), "Loaded tile soil_state matches")
	_assert(bool(loaded_cell.get("npk_analyzed", false)) == true, "Loaded tile npk_analyzed is true")
	_assert(bool(loaded_cell.get("fertilized", false)) == true, "Loaded tile fertilized is true")
	_assert(
		is_equal_approx(float(loaded_cell.get("n", 0.0)), float(expected_cell.get("n", -1.0)))
		and is_equal_approx(float(loaded_cell.get("p", 0.0)), float(expected_cell.get("p", -1.0)))
		and is_equal_approx(float(loaded_cell.get("k", 0.0)), float(expected_cell.get("k", -1.0)))
		and is_equal_approx(float(loaded_cell.get("moisture", 0.0)), float(expected_cell.get("moisture", -1.0))),
		"Loaded tile N-P-K and moisture match"
	)
	var expected_crop: Dictionary = expected_cell.get("crop", {})
	var loaded_crop: Dictionary = loaded_cell.get("crop", {})
	_assert(not loaded_crop.is_empty(), "Loaded tile crop is present")
	_assert(str(loaded_crop.get("crop_id", "")) == "pomodoro", "Loaded crop_id matches")
	_assert(int(loaded_crop.get("days_alive", -1)) == int(expected_crop.get("days_alive", -2)), "Loaded crop days_alive matches")
	_assert(is_equal_approx(float(loaded_crop.get("growth_days_acc", -1.0)), float(expected_crop.get("growth_days_acc", -2.0))), "Loaded crop growth_days_acc matches")

	# Bad schema / missing file checks
	_assert(not sm.load_game(gs_loaded, "/tmp/ortobio_nonexistent_save.json"), "Missing save file returns false")
	sm.delete_save(TEST_SAVE_PATH)
	_assert(not sm.has_save(TEST_SAVE_PATH), "delete_save removes test file")

	sm.free()
	gs.free()
	gs_loaded.free()


func _test_scene_manager() -> void:
	var scm: Node = SceneManagerScript.new()
	_assert(scm.current_screen == "field", "SceneManager starts on field")
	_assert(scm.is_clock_running(), "Clock runs initially on field")

	scm.push_modal_pause()
	_assert(not scm.is_clock_running(), "Clock pauses after push_modal_pause")
	scm.push_modal_pause()
	_assert(not scm.is_clock_running(), "Clock stays paused with nested modal pause")
	scm.pop_modal_pause()
	_assert(not scm.is_clock_running(), "Clock stays paused until all nested pauses pop")
	scm.pop_modal_pause()
	_assert(scm.is_clock_running(), "Clock resumes after matching pops")

	scm.pop_modal_pause()
	_assert(scm.modal_pause_count == 0 and scm.is_clock_running(), "Extra pop clamps modal_pause_count at 0")

	scm.current_screen = "market"
	_assert(not scm.is_clock_running(), "Clock pauses on non-field screen")
	scm.current_screen = "farm"
	_assert(scm.is_clock_running(), "Clock runs on farm screen alias")

	scm.push_modal_pause()
	scm.reset_modal_pauses()
	_assert(scm.is_clock_running(), "reset_modal_pauses clears pause counter")
	_assert(not scm.go_to("unknown_screen"), "go_to unknown screen returns false")

	scm.free()
