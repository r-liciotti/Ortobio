class_name FieldScreen
extends Control
## Main Milestone 1 (v0.1) vertical field screen integrating simulation, UI, and touch controls.

const TILE_SIZE := 16.0
const TAP_THRESHOLD_PX := 8.0

var balance_config: Dictionary = {}
var crops_db: Dictionary = {}
var time_weather: TimeWeatherManager
var simulation: GridSimulation

var _top_bar: TopBar
var _field_area: Control
var _field_container: Control
var _field_renderer: FieldRenderer
var _minimap: VerticalMinimap
var _inspector: TileInspector
var _tool_dock: ToolDock
var _toast_panel: PanelContainer
var _toast_label: Label

var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_streams: Dictionary = {}
var _sfx_idx: int = 0

var _scroll_y: float = 0.0
var _field_scale: float = 2.0
var _pointer_down: bool = false
var _pointer_start: Vector2 = Vector2.ZERO
var _pointer_last: Vector2 = Vector2.ZERO
var _pointer_drag_dist: float = 0.0
var _last_worked_tile: Vector2i = Vector2i(-1, -1)
var _toast_timer: float = 0.0
var _midnight_notified: bool = false


func _ready() -> void:
	balance_config = DataLoader.load_balance_config()
	crops_db = DataLoader.load_crops()
	time_weather = TimeWeatherManager.new(balance_config)
	simulation = GridSimulation.new(balance_config, crops_db)

	_setup_audio()
	_build_layout()
	_sync_all_ui()
	_show_toast("Benvenuto! Usa Vanga -> Rastrello -> Seme -> Acqua.")


func _setup_audio() -> void:
	var sounds := {
		"spade": "res://assets/audio/sfx_spade.wav",
		"rake": "res://assets/audio/sfx_rake.wav",
		"water": "res://assets/audio/sfx_water.wav",
		"seed": "res://assets/audio/sfx_seed.wav",
		"harvest": "res://assets/audio/sfx_harvest.wav",
		"tap": "res://assets/audio/sfx_tap.wav",
	}
	for k in sounds.keys():
		if ResourceLoader.exists(sounds[k]):
			_sfx_streams[k] = load(sounds[k])
	for _i in range(4):
		var p := AudioStreamPlayer.new()
		p.volume_db = -6.0
		add_child(p)
		_sfx_players.append(p)


func _play_sfx(key: String, pitch: float = 1.0) -> void:
	if not _sfx_streams.has(key) or _sfx_players.is_empty():
		return
	var p := _sfx_players[_sfx_idx % _sfx_players.size()]
	_sfx_idx += 1
	p.stream = _sfx_streams[key]
	p.pitch_scale = pitch
	p.play()


func _build_layout() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var root_vbox := VBoxContainer.new()
	root_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_vbox.add_theme_constant_override("separation", 0)
	add_child(root_vbox)

	# 1. Top Bar
	_top_bar = TopBar.new()
	_top_bar.sleep_pressed.connect(_on_sleep_pressed)
	_top_bar.season_cycle_pressed.connect(_on_season_cycle_pressed)
	root_vbox.add_child(_top_bar)

	# 2. Middle Field + Minimap area
	_field_area = Control.new()
	_field_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_field_area.clip_contents = true
	root_vbox.add_child(_field_area)

	var field_hbox := HBoxContainer.new()
	field_hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	field_hbox.add_theme_constant_override("separation", 0)
	_field_area.add_child(field_hbox)

	_field_container = Control.new()
	_field_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_field_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_field_container.clip_contents = true
	_field_container.mouse_filter = Control.MOUSE_FILTER_STOP
	_field_container.gui_input.connect(_on_field_gui_input)
	_field_container.resized.connect(_recompute_field_scale)
	field_hbox.add_child(_field_container)

	_field_renderer = FieldRenderer.new()
	_field_renderer.simulation = simulation
	_field_renderer.farmer_action_impact.connect(_on_farmer_action_impact)
	_field_container.add_child(_field_renderer)

	_minimap = VerticalMinimap.new()
	_minimap.simulation = simulation
	_minimap.scroll_requested.connect(_on_minimap_scroll_requested)
	field_hbox.add_child(_minimap)

	# Toast Banner inside field area (top-centered)
	_toast_panel = PanelContainer.new()
	_toast_panel.visible = false
	_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_toast_panel.offset_left = 14
	_toast_panel.offset_right = -40
	_toast_panel.offset_top = 8
	var t_sb := StyleBoxFlat.new()
	t_sb.bg_color = Color(0.14, 0.10, 0.08, 0.88)
	t_sb.border_width_bottom = 1
	t_sb.border_color = Color(0.86, 0.72, 0.42, 0.9)
	t_sb.corner_radius_top_left = 6
	t_sb.corner_radius_top_right = 6
	t_sb.corner_radius_bottom_left = 6
	t_sb.corner_radius_bottom_right = 6
	t_sb.content_margin_left = 10
	t_sb.content_margin_right = 10
	t_sb.content_margin_top = 5
	t_sb.content_margin_bottom = 5
	_toast_panel.add_theme_stylebox_override("panel", t_sb)
	_field_area.add_child(_toast_panel)

	_toast_label = Label.new()
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast_label.add_theme_font_size_override("font_size", 12)
	_toast_label.add_theme_color_override("font_color", Color(0.98, 0.94, 0.82))
	_toast_panel.add_child(_toast_label)

	# Tile Inspector anchored at bottom of field area
	_inspector = TileInspector.new()
	_inspector.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_inspector.offset_right = -28
	_inspector.closed.connect(func():
		_field_renderer.selected_tile = Vector2i(-1, -1)
		_field_renderer.queue_redraw()
	)
	_field_area.add_child(_inspector)

	# 3. Bottom Thumb Dock
	_tool_dock = ToolDock.new()
	_tool_dock.mode_changed.connect(func(mode: String):
		_play_sfx("tap")
		if mode == "work":
			_inspector.visible = false
			_field_renderer.selected_tile = Vector2i(-1, -1)
			_field_renderer.queue_redraw()
	)
	_tool_dock.tool_selected.connect(func(_tid: String): _play_sfx("tap", 1.1))
	_tool_dock.harvest_all_pressed.connect(_on_harvest_all_pressed)
	root_vbox.add_child(_tool_dock)

	call_deferred("_recompute_field_scale")


func _recompute_field_scale() -> void:
	if _field_container == null or simulation == null:
		return
	var avail_w := maxf(64.0, _field_container.size.x)
	_field_scale = avail_w / (float(simulation.width) * TILE_SIZE)
	_field_renderer.scale = Vector2(_field_scale, _field_scale)
	_apply_scroll(_scroll_y)


func _max_scroll_y() -> float:
	if _field_container == null or simulation == null:
		return 0.0
	var total_h := float(simulation.height) * TILE_SIZE * _field_scale
	return maxf(0.0, total_h - _field_container.size.y)


func _apply_scroll(new_y: float) -> void:
	var max_s := _max_scroll_y()
	_scroll_y = clampf(new_y, 0.0, max_s)
	_field_renderer.position = Vector2(0.0, -_scroll_y)
	var total_h := maxf(1.0, float(simulation.height) * TILE_SIZE * _field_scale)
	var visible_ratio := clampf(_field_container.size.y / total_h, 0.05, 1.0)
	var scroll_ratio := 0.0 if max_s <= 0.0 else (_scroll_y / max_s)
	_minimap.set_viewport_ratios(scroll_ratio, visible_ratio)


func _on_minimap_scroll_requested(norm_y: float) -> void:
	_apply_scroll(norm_y * _max_scroll_y())


func _process(delta: float) -> void:
	var is_active := not _inspector.visible and not _midnight_notified
	var hit_midnight := time_weather.tick(delta, is_active)
	if hit_midnight and not _midnight_notified:
		_midnight_notified = true
		_show_toast("Mezzanotte! Tocca 'Dormi +1g' per passare al mattino.")
	_top_bar.update_state(time_weather, simulation)
	_field_renderer.modulate = time_weather.get_daylight_modulate()

	if _toast_timer > 0.0:
		_toast_timer -= delta
		if _toast_timer <= 0.0:
			_toast_panel.visible = false


func _screen_to_tile(local_pos: Vector2) -> Vector2i:
	var world_pos := (local_pos + Vector2(0.0, _scroll_y)) / maxf(0.1, _field_scale)
	var gx := int(floor(world_pos.x / TILE_SIZE))
	var gy := int(floor(world_pos.y / TILE_SIZE))
	return Vector2i(gx, gy)


func _on_field_gui_input(event: InputEvent) -> void:
	# Mouse wheel scroll works in both Explore and Work modes
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_apply_scroll(_scroll_y - 36.0)
			return
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_apply_scroll(_scroll_y + 36.0)
			return
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_handle_pointer_down(mb.position)
			else:
				_handle_pointer_up(mb.position)
	elif event is InputEventMouseMotion and _pointer_down:
		var mm := event as InputEventMouseMotion
		_handle_pointer_move(mm.position)
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_handle_pointer_down(st.position)
		else:
			_handle_pointer_up(st.position)
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		_handle_pointer_move(sd.position)


func _handle_pointer_down(pos: Vector2) -> void:
	_pointer_down = true
	_pointer_start = pos
	_pointer_last = pos
	_pointer_drag_dist = 0.0
	_last_worked_tile = Vector2i(-1, -1)
	if _tool_dock.current_mode == "work":
		var tile := _screen_to_tile(pos)
		_apply_active_tool(tile)
		_last_worked_tile = tile


func _handle_pointer_move(pos: Vector2) -> void:
	var delta := pos - _pointer_last
	_pointer_last = pos
	_pointer_drag_dist += delta.length()

	if _tool_dock.current_mode == "explore":
		if _pointer_drag_dist >= TAP_THRESHOLD_PX:
			_apply_scroll(_scroll_y - delta.y)
	else:
		var tile := _screen_to_tile(pos)
		if tile != _last_worked_tile:
			_apply_active_tool(tile)
			_last_worked_tile = tile


func _handle_pointer_up(pos: Vector2) -> void:
	if not _pointer_down:
		return
	_pointer_down = false
	if _tool_dock.current_mode == "explore" and _pointer_drag_dist < TAP_THRESHOLD_PX:
		var tile := _screen_to_tile(pos)
		_handle_explore_tap(tile)


func _handle_explore_tap(tile: Vector2i) -> void:
	if not simulation.is_valid(tile.x, tile.y):
		return
	var cell := simulation.get_cell(tile.x, tile.y)
	var crop: Dictionary = cell["crop"]
	if not crop.is_empty() and (bool(crop.get("harvest_ready", false)) or bool(crop.get("withered", false))):
		var act_name := "harvest" if bool(crop.get("harvest_ready", false)) else "rake"
		_field_renderer.enqueue_farmer_action({
			"gx": tile.x,
			"gy": tile.y,
			"action": act_name,
			"tool_id": "harvest_or_clear",
			"crop_id": str(crop.get("crop_id", "")),
		})
		_inspector.visible = false
		return

	_field_renderer.selected_tile = tile
	_field_renderer.queue_redraw()
	_inspector.inspect_cell(cell, simulation, time_weather)
	_play_sfx("tap")


func _apply_active_tool(tile: Vector2i) -> void:
	if not simulation.is_valid(tile.x, tile.y):
		return
	var tid := _tool_dock.current_tool
	var cell := simulation.get_cell(tile.x, tile.y)
	var s_state := int(cell["soil_state"])
	var crop_dict: Dictionary = cell["crop"]
	var has_crop: bool = not crop_dict.is_empty()

	# Pre-validate so farmer only walks to valid tiles and gives immediate feedback otherwise
	if tid == "spade":
		if has_crop or s_state != GridSimulation.SoilState.INCOLTO:
			return
	elif tid == "rake":
		if has_crop or s_state != GridSimulation.SoilState.VANGATO:
			if s_state == GridSimulation.SoilState.INCOLTO:
				_show_toast("Prima dissoda la terra con la Vanga.")
			return
	elif tid == "water":
		if s_state == GridSimulation.SoilState.INCOLTO:
			_show_toast("Incolto: lavora prima la zolla con la Vanga.")
			return
	elif tid.begins_with("seed:"):
		if has_crop:
			return
		if s_state != GridSimulation.SoilState.RASTRELLATO:
			_show_toast("Prepara il letto di semina col Rastrello.")
			return

	var act_type := "seed" if tid.begins_with("seed:") else tid
	var cid := tid.substr(5) if tid.begins_with("seed:") else ""
	_field_renderer.enqueue_farmer_action({
		"gx": tile.x,
		"gy": tile.y,
		"action": act_type,
		"tool_id": tid,
		"crop_id": cid,
	})


func _on_farmer_action_impact(req: Dictionary) -> void:
	## Executes the actual simulation change right when the farmer arrives and strikes the tile.
	var gx := int(req["gx"])
	var gy := int(req["gy"])
	var tid := str(req.get("tool_id", ""))
	if not simulation.is_valid(gx, gy):
		return

	if tid == "harvest_or_clear":
		var res := simulation.clear_withered_or_harvest(gx, gy)
		if bool(res.get("ok", false)):
			if str(res.get("action", "")) == "harvested":
				var earned := int(res["earned"])
				var cname := str(res["crop_name"])
				var qty := int(res["yield"])
				_field_renderer.spawn_harvest_pop(gx, gy, str(res.get("crop_id", "")))
				_field_renderer.spawn_action_particles(gx, gy, Color(0.98, 0.85, 0.30), 8)
				_field_renderer.spawn_floating_text(gx, gy, "+%d €" % earned, Color(1.0, 0.90, 0.32))
				_play_sfx("harvest")
				_show_toast("Raccolto %dx %s (+%d €)!" % [qty, cname, earned])
			else:
				_field_renderer.spawn_action_particles(gx, gy, Color(0.60, 0.45, 0.30), 6)
				_play_sfx("rake")
				_show_toast("Pianta secca rimossa.")
			_sync_all_ui()
		return

	var res: Dictionary = {}
	if tid == "spade":
		res = simulation.apply_spade(gx, gy)
		if bool(res.get("ok", false)):
			_field_renderer.spawn_action_particles(gx, gy, Color(0.62, 0.44, 0.28), 6)
			_play_sfx("spade", randf_range(0.94, 1.06))
	elif tid == "rake":
		res = simulation.apply_rake(gx, gy)
		if bool(res.get("ok", false)):
			_field_renderer.spawn_action_particles(gx, gy, Color(0.52, 0.34, 0.22), 5)
			_play_sfx("rake", randf_range(0.94, 1.08))
	elif tid == "water":
		res = simulation.apply_water(gx, gy, time_weather.weather_type)
		if bool(res.get("ok", false)):
			_field_renderer.spawn_action_particles(gx, gy, Color(0.35, 0.70, 0.95), 6)
			_play_sfx("water", randf_range(0.95, 1.05))
	elif tid.begins_with("seed:"):
		var crop_id := tid.substr(5)
		res = simulation.plant_seed(gx, gy, crop_id)
		if bool(res.get("ok", false)):
			_field_renderer.spawn_action_particles(gx, gy, Color(0.82, 0.78, 0.45), 4)
			_play_sfx("seed", randf_range(0.95, 1.12))

	if not bool(res.get("ok", false)) and str(res.get("reason", "")) == "no_energy":
		_field_renderer.clear_action_queue()
		_show_toast("Energia esaurita! Tocca 'Dormi +1g' per ricaricare.")

	_sync_all_ui()


func _on_sleep_pressed() -> void:
	_midnight_notified = false
	_field_renderer.clear_action_queue()
	var weather := time_weather.advance_day()
	var summary := simulation.simulate_day_step(weather)
	_inspector.visible = false
	_field_renderer.selected_tile = Vector2i(-1, -1)
	_play_sfx("tap", 0.9)
	_sync_all_ui()

	var msg := "%s G.%d (%s %d°/%d°C)" % [
		time_weather.get_season_short(),
		time_weather.day_in_season,
		time_weather.get_weather_icon_text(),
		int(time_weather.temp_min),
		int(time_weather.temp_max),
	]
	if int(summary["crops_ready"]) > 0:
		msg += " · %d pronte!" % int(summary["crops_ready"])
	elif int(summary["crops_stressed"]) > 0:
		msg += " · %d in stress termico!" % int(summary["crops_stressed"])
	_show_toast(msg)


func _on_season_cycle_pressed() -> void:
	_midnight_notified = false
	time_weather.cycle_season_for_test()
	_inspector.visible = false
	_play_sfx("tap", 1.15)
	_sync_all_ui()
	_show_toast("Test Stagione: %s (%d°/%d°C)" % [
		time_weather.get_season_label(),
		int(time_weather.temp_min),
		int(time_weather.temp_max),
	])


func _on_harvest_all_pressed() -> void:
	var queued := 0
	for y in range(simulation.height):
		for x in range(simulation.width):
			var cell := simulation.get_cell(x, y)
			var crop: Dictionary = cell["crop"]
			if not crop.is_empty() and bool(crop.get("harvest_ready", false)):
				_field_renderer.enqueue_farmer_action({
					"gx": x,
					"gy": y,
					"action": "harvest",
					"tool_id": "harvest_or_clear",
					"crop_id": str(crop.get("crop_id", "")),
				})
				queued += 1
	if queued > 0:
		_inspector.visible = false
		_show_toast("Il contadino sta raccogliendo %d piante..." % queued)


func _sync_all_ui() -> void:
	_top_bar.update_state(time_weather, simulation)
	var ready_count := 0
	for cell in simulation.cells:
		var crop: Dictionary = cell["crop"]
		if not crop.is_empty() and bool(crop.get("harvest_ready", false)):
			ready_count += 1
	_tool_dock.update_ready_count(ready_count)
	_field_renderer.weather_type = time_weather.weather_type
	_field_renderer.modulate = time_weather.get_daylight_modulate()
	_field_renderer.queue_redraw()
	_minimap.queue_redraw()


func _show_toast(msg: String) -> void:
	_toast_label.text = msg
	_toast_panel.visible = true
	_toast_timer = 3.2
