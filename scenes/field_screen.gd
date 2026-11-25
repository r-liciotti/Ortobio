class_name FieldScreen
extends Control
## Main vertical field screen integrating GameState, 6-slot Hotbar, BackpackPanel, free farmer movement, and touch controls.

const BackpackPanelScript := preload("res://ui/backpack_panel.gd")
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
var _backpack_panel: BackpackPanelScript
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
var _inspector_paused: bool = false
var _backpack_paused: bool = false


func _ready() -> void:
	SceneManager.current_screen = "field"
	SceneManager.reset_modal_pauses()
	_inspector_paused = false
	_backpack_paused = false

	_bind_from_game_state()
	_setup_audio()
	_build_layout()
	_sync_all_ui()
	_show_toast("Benvenuto! Usa Vanga -> Rastrello -> Seme -> Acqua.")


func _exit_tree() -> void:
	if _inspector_paused:
		SceneManager.pop_modal_pause()
		_inspector_paused = false
	if _backpack_paused:
		SceneManager.pop_modal_pause()
		_backpack_paused = false


func _bind_from_game_state() -> void:
	balance_config = GameState.balance_config
	crops_db = GameState.crops_db
	time_weather = GameState.time_weather
	simulation = GameState.get_active_field()
	GameState.sync_state_to_field(simulation)
	if time_weather != null:
		_midnight_notified = (time_weather.minutes_of_day >= float(time_weather.end_hour * 60))


func _setup_audio() -> void:
	var sounds: Dictionary = {
		"spade": "res://assets/audio/sfx_spade.wav",
		"rake": "res://assets/audio/sfx_rake.wav",
		"water": "res://assets/audio/sfx_water.wav",
		"seed": "res://assets/audio/sfx_seed.wav",
		"harvest": "res://assets/audio/sfx_harvest.wav",
		"tap": "res://assets/audio/sfx_tap.wav",
	}
	for k: Variant in sounds.keys():
		var key_str: String = str(k)
		var path_str: String = str(sounds[k])
		if ResourceLoader.exists(path_str):
			_sfx_streams[key_str] = load(path_str)
	for _i: int in range(4):
		var p := AudioStreamPlayer.new()
		p.volume_db = -6.0
		add_child(p)
		_sfx_players.append(p)


func _play_sfx(key: String, pitch: float = 1.0) -> void:
	if not _sfx_streams.has(key) or _sfx_players.is_empty():
		return
	var p: AudioStreamPlayer = _sfx_players[_sfx_idx % _sfx_players.size()]
	_sfx_idx += 1
	p.stream = _sfx_streams[key] as AudioStream
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
	_top_bar.time_cycle_pressed.connect(_on_time_cycle_pressed)
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
	_field_renderer.time_weather = time_weather
	_field_renderer.farmer_action_impact.connect(_on_farmer_action_impact)
	_field_container.add_child(_field_renderer)

	_minimap = VerticalMinimap.new()
	_minimap.simulation = simulation
	_minimap.scroll_requested.connect(_on_minimap_scroll_requested)
	field_hbox.add_child(_minimap)

	# Tile Inspector anchored at bottom of field area
	_inspector = TileInspector.new()
	_inspector.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_inspector.offset_right = -28
	_inspector.closed.connect(func() -> void:
		_set_inspector_visible(false)
		_field_renderer.selected_tile = Vector2i(-1, -1)
		_field_renderer.queue_redraw()
	)
	_field_area.add_child(_inspector)

	# Backpack Modal anchored over field area
	_backpack_panel = BackpackPanelScript.new()
	_backpack_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backpack_panel.offset_left = 8
	_backpack_panel.offset_right = -8
	_backpack_panel.offset_top = 8
	_backpack_panel.offset_bottom = -8
	_backpack_panel.closed.connect(func() -> void:
		_set_backpack_visible(false)
		_play_sfx("tap", 0.95)
	)
	_backpack_panel.inventory_changed.connect(func() -> void:
		_play_sfx("tap", 1.08)
		_tool_dock.refresh_hotbar(GameState.inventory, GameState.selected_hotbar_index)
	)
	_backpack_panel.repair_requested.connect(_on_backpack_repair_requested)
	_backpack_panel.sell_crops_requested.connect(_on_backpack_sell_crops_requested)
	_backpack_panel.refill_seeds_requested.connect(_on_backpack_refill_seeds_requested)
	_backpack_panel.save_requested.connect(_on_backpack_save_requested)
	_backpack_panel.reset_requested.connect(_on_backpack_reset_requested)
	_field_area.add_child(_backpack_panel)

	# Toast Banner inside field area (top-centered, above modals so feedback is always visible)
	_toast_panel = PanelContainer.new()
	_toast_panel.visible = false
	_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_toast_panel.offset_left = 14
	_toast_panel.offset_right = -40
	_toast_panel.offset_top = 8
	var t_sb := StyleBoxFlat.new()
	t_sb.bg_color = Color(0.14, 0.10, 0.08, 0.92)
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

	# 3. Bottom Thumb Dock
	_tool_dock = ToolDock.new()
	_tool_dock.mode_changed.connect(func(mode: String) -> void:
		_play_sfx("tap")
		_set_backpack_visible(false)
		if mode == "work":
			_set_inspector_visible(false)
			_field_renderer.selected_tile = Vector2i(-1, -1)
			_field_renderer.queue_redraw()
			_tool_dock.refresh_hotbar(GameState.inventory, GameState.selected_hotbar_index)
	)
	_tool_dock.hotbar_slot_selected.connect(func(index: int) -> void:
		GameState.selected_hotbar_index = index
		_set_backpack_visible(false)
		_set_inspector_visible(false)
		_field_renderer.selected_tile = Vector2i(-1, -1)
		_field_renderer.queue_redraw()
		_play_sfx("tap", 1.1)
		_tool_dock.refresh_hotbar(GameState.inventory, GameState.selected_hotbar_index)
	)
	_tool_dock.backpack_pressed.connect(func() -> void:
		_play_sfx("tap", 1.05)
		_set_backpack_visible(not _backpack_panel.visible)
	)
	_tool_dock.harvest_all_pressed.connect(_on_harvest_all_pressed)
	_tool_dock.npk_overlay_toggled.connect(func(enabled: bool) -> void:
		_play_sfx("tap", 1.05 if enabled else 0.95)
		_field_renderer.show_npk_overlay = enabled
		_field_renderer.queue_redraw()
		if enabled:
			_show_toast("Vista N-P-K attiva (usa la Sonda sulle zolle '?')")
	)
	root_vbox.add_child(_tool_dock)

	call_deferred("_recompute_field_scale")


func _set_inspector_visible(show_panel: bool) -> void:
	if show_panel:
		if not _inspector_paused:
			SceneManager.push_modal_pause()
			_inspector_paused = true
	else:
		_inspector.visible = false
		if _inspector_paused:
			SceneManager.pop_modal_pause()
			_inspector_paused = false


func _set_backpack_visible(show_panel: bool) -> void:
	if show_panel:
		_set_inspector_visible(false)
		_field_renderer.selected_tile = Vector2i(-1, -1)
		_field_renderer.queue_redraw()
		_backpack_panel.open_panel(GameState.inventory, GameState.crops_db)
		if not _backpack_paused:
			SceneManager.push_modal_pause()
			_backpack_paused = true
	else:
		_backpack_panel.visible = false
		if _backpack_paused:
			SceneManager.pop_modal_pause()
			_backpack_paused = false


func _recompute_field_scale() -> void:
	if _field_container == null or simulation == null:
		return
	var vp_w: float = get_viewport_rect().size.x
	var target_w: float = minf(_field_container.size.x, maxf(64.0, vp_w - 28.0))
	var avail_w: float = maxf(64.0, target_w)
	_field_scale = avail_w / (float(simulation.width) * TILE_SIZE)
	_field_renderer.scale = Vector2(_field_scale, _field_scale)
	_apply_scroll(_scroll_y)


func _max_scroll_y() -> float:
	if _field_container == null or simulation == null:
		return 0.0
	var total_h: float = float(simulation.height) * TILE_SIZE * _field_scale
	return maxf(0.0, total_h - _field_container.size.y)


func _apply_scroll(new_y: float) -> void:
	var max_s: float = _max_scroll_y()
	_scroll_y = clampf(new_y, 0.0, max_s)
	_field_renderer.position = Vector2(0.0, -_scroll_y)
	var total_h: float = maxf(1.0, float(simulation.height) * TILE_SIZE * _field_scale)
	var visible_ratio: float = clampf(_field_container.size.y / total_h, 0.05, 1.0)
	var scroll_ratio: float = 0.0 if max_s <= 0.0 else (_scroll_y / max_s)
	_minimap.set_viewport_ratios(scroll_ratio, visible_ratio)


func _on_minimap_scroll_requested(norm_y: float) -> void:
	_apply_scroll(norm_y * _max_scroll_y())


func _process(delta: float) -> void:
	var is_active: bool = SceneManager.is_clock_running() and not _midnight_notified
	var hit_midnight: bool = time_weather.tick(delta, is_active)
	if hit_midnight and not _midnight_notified:
		_midnight_notified = true
		_show_toast("Mezzanotte! Tocca 'Dormi +1g' per passare al mattino.")
	_top_bar.update_state(time_weather, simulation, GameState.coins, GameState.energy, GameState.max_energy)
	_field_renderer.modulate = time_weather.get_daylight_modulate()

	if _toast_timer > 0.0:
		_toast_timer -= delta
		if _toast_timer <= 0.0:
			_toast_panel.visible = false


func _screen_to_world(local_pos: Vector2) -> Vector2:
	return (local_pos + Vector2(0.0, _scroll_y)) / maxf(0.1, _field_scale)


func _screen_to_tile(local_pos: Vector2) -> Vector2i:
	var world_pos: Vector2 = _screen_to_world(local_pos)
	var gx: int = int(floor(world_pos.x / TILE_SIZE))
	var gy: int = int(floor(world_pos.y / TILE_SIZE))
	return Vector2i(gx, gy)


func _on_field_gui_input(event: InputEvent) -> void:
	if _backpack_panel.visible:
		return
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
	if _backpack_panel.visible:
		return
	_pointer_down = true
	_pointer_start = pos
	_pointer_last = pos
	_pointer_drag_dist = 0.0
	_last_worked_tile = Vector2i(-1, -1)
	if _tool_dock.current_mode == "work":
		var tile: Vector2i = _screen_to_tile(pos)
		_apply_active_tool(tile, true)
		_last_worked_tile = tile


func _handle_pointer_move(pos: Vector2) -> void:
	var delta: Vector2 = pos - _pointer_last
	_pointer_last = pos
	_pointer_drag_dist += delta.length()

	if _tool_dock.current_mode == "explore":
		if _pointer_drag_dist >= TAP_THRESHOLD_PX:
			_apply_scroll(_scroll_y - delta.y)
	else:
		var tile: Vector2i = _screen_to_tile(pos)
		if tile != _last_worked_tile:
			_apply_active_tool(tile, false)
			_last_worked_tile = tile


func _handle_pointer_up(pos: Vector2) -> void:
	if not _pointer_down:
		return
	_pointer_down = false
	if _tool_dock.current_mode == "explore" and _pointer_drag_dist < TAP_THRESHOLD_PX:
		var tile: Vector2i = _screen_to_tile(pos)
		var world_pos: Vector2 = _screen_to_world(pos)
		_handle_explore_tap(tile, world_pos)


func _stand_pos_beside_tile(tile: Vector2i) -> Vector2:
	var tile_center := Vector2((float(tile.x) + 0.5) * TILE_SIZE, (float(tile.y) + 0.5) * TILE_SIZE)
	var field_w: float = float(simulation.width) * TILE_SIZE
	var field_h: float = float(simulation.height) * TILE_SIZE
	var left_x: float = clampf(tile_center.x - 9.0, 9.0, field_w - 9.0)
	var right_x: float = clampf(tile_center.x + 9.0, 9.0, field_w - 9.0)
	var stand_x: float = left_x if absf(_field_renderer.farmer_pos.x - left_x) <= absf(_field_renderer.farmer_pos.x - right_x) else right_x
	var stand_y: float = clampf(tile_center.y + 3.0, 14.0, field_h - 4.0)
	return Vector2(stand_x, stand_y)


func _handle_explore_tap(tile: Vector2i, world_pos: Vector2) -> void:
	if not simulation.is_valid(tile.x, tile.y):
		return
	var cell: Dictionary = simulation.get_cell(tile.x, tile.y)
	var crop: Dictionary = cell["crop"]
	var s_state: int = int(cell["soil_state"])

	if not crop.is_empty() and (bool(crop.get("harvest_ready", false)) or bool(crop.get("withered", false))):
		var crop_id: String = str(crop.get("crop_id", ""))
		var crop_def: Dictionary = crops_db.get(crop_id, {})
		var is_gm: bool = bool(crop_def.get("is_green_manure", false))
		if bool(crop.get("harvest_ready", false)) and not bool(crop.get("withered", false)) and is_gm:
			_field_renderer.command_farmer_walk_to(_stand_pos_beside_tile(tile))
			_field_renderer.selected_tile = tile
			_field_renderer.queue_redraw()
			_inspector.inspect_cell(cell, simulation, time_weather)
			_set_inspector_visible(true)
			_play_sfx("tap")
			_show_toast("Trifoglio maturo! Passa a Lavora -> Vanga per interrarlo (+N/P/K).")
			return
		var act_name: String = "harvest" if bool(crop.get("harvest_ready", false)) else "rake"
		_field_renderer.enqueue_farmer_action({
			"gx": tile.x,
			"gy": tile.y,
			"action": act_name,
			"tool_id": "harvest_or_clear",
			"crop_id": crop_id,
		})
		_set_inspector_visible(false)
		_field_renderer.selected_tile = Vector2i(-1, -1)
		_field_renderer.queue_redraw()
		return

	if s_state == GridSimulation.SoilState.INCOLTO:
		_set_inspector_visible(false)
		_field_renderer.selected_tile = Vector2i(-1, -1)
		_field_renderer.command_farmer_walk_to(world_pos)
		return

	_field_renderer.command_farmer_walk_to(_stand_pos_beside_tile(tile))
	_field_renderer.selected_tile = tile
	_field_renderer.queue_redraw()
	_inspector.inspect_cell(cell, simulation, time_weather)
	_set_inspector_visible(true)
	_play_sfx("tap")


func _resolve_active_hotbar_action(show_feedback: bool) -> Dictionary:
	var slot_idx: int = clampi(GameState.selected_hotbar_index, 0, InventoryManager.HOTBAR_SIZE - 1)
	var slot: Dictionary = GameState.inventory.get_slot("hotbar", slot_idx)
	if slot.is_empty():
		if show_feedback:
			_show_toast("Slot vuoto! Apri lo Zaino per equipaggiare un oggetto.")
		return {}
	if GameState.inventory.is_tool_broken(slot):
		if show_feedback:
			_show_toast("Attrezzo rotto! Riparalo nello Zaino.")
		return {}

	var item_id: String = str(slot.get("item_id", ""))
	var item_def: Dictionary = GameState.items_db.get(item_id, {})
	var category: String = str(item_def.get("category", ""))
	var tid: String = ""
	if category == "tool":
		tid = str(item_def.get("tool_action", ""))
	elif category == "amendment":
		tid = str(item_def.get("tool_action", "compost"))
	elif category == "seed":
		var crop_id: String = str(item_def.get("crop_id", ""))
		if not crop_id.is_empty():
			tid = "seed:" + crop_id
	else:
		if show_feedback:
			_show_toast("Questo e un raccolto, non uno strumento.")
		return {}

	if tid.is_empty():
		return {}

	return {
		"slot_index": slot_idx,
		"item_id": item_id,
		"tool_id": tid,
	}


func _apply_active_tool(tile: Vector2i, is_initial_tap: bool = true) -> void:
	if not simulation.is_valid(tile.x, tile.y):
		return
	var resolved: Dictionary = _resolve_active_hotbar_action(is_initial_tap)
	if resolved.is_empty():
		return

	var tid: String = str(resolved["tool_id"])
	var slot_idx: int = int(resolved["slot_index"])
	var item_id: String = str(resolved["item_id"])

	var cell: Dictionary = simulation.get_cell(tile.x, tile.y)
	var s_state: int = int(cell["soil_state"])
	var crop_dict: Dictionary = cell["crop"]
	var has_crop: bool = not crop_dict.is_empty()

	# Pre-validate so farmer only walks to valid tiles and gives immediate feedback otherwise
	if tid == "spade":
		var can_till_incolto: bool = (not has_crop and s_state == GridSimulation.SoilState.INCOLTO)
		var gm_cid: String = str(crop_dict.get("crop_id", ""))
		var gm_def: Dictionary = crops_db.get(gm_cid, {})
		var can_till_gm: bool = (
			has_crop
			and not bool(crop_dict.get("withered", false))
			and bool(crop_dict.get("harvest_ready", false))
			and bool(gm_def.get("is_green_manure", false))
		)
		if not can_till_incolto and not can_till_gm:
			return
	elif tid == "rake":
		if has_crop or s_state != GridSimulation.SoilState.VANGATO:
			if s_state == GridSimulation.SoilState.INCOLTO:
				_show_toast("Prima dissoda la terra con la Vanga.")
			return
	elif tid == "water" or tid == "compost" or tid == "probe":
		if s_state == GridSimulation.SoilState.INCOLTO:
			_show_toast("Incolto: lavora prima la zolla con la Vanga.")
			return
	elif tid.begins_with("seed:"):
		if has_crop:
			return
		if s_state != GridSimulation.SoilState.RASTRELLATO:
			_show_toast("Prepara il letto di semina col Rastrello.")
			return

	var act_type: String = "seed" if tid.begins_with("seed:") else tid
	var cid: String = tid.substr(5) if tid.begins_with("seed:") else ""
	_field_renderer.enqueue_farmer_action({
		"gx": tile.x,
		"gy": tile.y,
		"action": act_type,
		"tool_id": tid,
		"crop_id": cid,
		"hotbar_index": slot_idx,
		"item_id": item_id,
	})


func _on_farmer_action_impact(req: Dictionary) -> void:
	## Executes the actual simulation change right when the farmer arrives and strikes the tile.
	var gx: int = int(req["gx"])
	var gy: int = int(req["gy"])
	var tid: String = str(req.get("tool_id", ""))
	if not simulation.is_valid(gx, gy):
		return

	if tid == "harvest_or_clear":
		GameState.sync_state_to_field(simulation)
		var h_res: Dictionary = simulation.clear_withered_or_harvest(gx, gy)
		if bool(h_res.get("ok", false)):
			if str(h_res.get("action", "")) == "harvested":
				var earned: int = int(h_res.get("earned", 0))
				simulation.coins -= earned
				var crop_id: String = str(h_res.get("crop_id", ""))
				var cname: String = str(h_res.get("crop_name", crop_id))
				var qty: int = int(h_res.get("yield", 1))
				var added: int = GameState.inventory.add_item(crop_id, qty)
				GameState.sync_field_resources_to_state(simulation)
				_field_renderer.spawn_harvest_pop(gx, gy, crop_id)
				_field_renderer.spawn_action_particles(gx, gy, Color(0.98, 0.85, 0.30), 8)
				_field_renderer.spawn_floating_text(gx, gy, "+%d %s" % [qty, cname], Color(1.0, 0.90, 0.32))
				_play_sfx("harvest")
				if added < qty:
					_show_toast("Zaino pieno! Raccolti %d/%dx %s." % [added, qty, cname])
				else:
					_show_toast("Raccolti %dx %s nello Zaino!" % [qty, cname])
			else:
				GameState.sync_field_resources_to_state(simulation)
				_field_renderer.spawn_action_particles(gx, gy, Color(0.60, 0.45, 0.30), 6)
				_play_sfx("rake")
				_show_toast("Pianta secca rimossa.")
			_sync_all_ui()
		elif str(h_res.get("reason", "")) == "use_spade_green_manure":
			_show_toast("Trifoglio maturo! Passa a Lavora -> Vanga per interrarlo (+N/P/K).")
		return

	var slot_idx: int = int(req.get("hotbar_index", GameState.selected_hotbar_index))
	var expected_item_id: String = str(req.get("item_id", ""))
	var slot: Dictionary = GameState.inventory.get_slot("hotbar", slot_idx)
	if slot.is_empty() or (not expected_item_id.is_empty() and str(slot.get("item_id", "")) != expected_item_id):
		_field_renderer.clear_action_queue()
		_sync_all_ui()
		return
	if GameState.inventory.is_tool_broken(slot):
		_field_renderer.clear_action_queue()
		_show_toast("Attrezzo rotto! Riparalo nello Zaino.")
		_sync_all_ui()
		return

	GameState.sync_state_to_field(simulation)
	var res: Dictionary = {}
	var is_tool_action: bool = false
	var is_consumable_action: bool = false

	if tid == "spade":
		is_tool_action = true
		res = simulation.apply_spade(gx, gy)
		if bool(res.get("ok", false)):
			if str(res.get("action", "")) == "green_manure_tilled":
				_field_renderer.spawn_action_particles(gx, gy, Color(0.38, 0.84, 0.36), 6)
				_field_renderer.spawn_action_particles(gx, gy, Color(0.56, 0.38, 0.22), 5)
				_field_renderer.spawn_floating_text(gx, gy, "+N/P/K!", Color(0.45, 0.96, 0.45))
				_play_sfx("spade", randf_range(0.94, 1.06))
				_show_toast("Trifoglio interrato! Suolo rigenerato (+N/P/K).")
			else:
				_field_renderer.spawn_action_particles(gx, gy, Color(0.62, 0.44, 0.28), 6)
				_play_sfx("spade", randf_range(0.94, 1.06))
	elif tid == "rake":
		is_tool_action = true
		res = simulation.apply_rake(gx, gy)
		if bool(res.get("ok", false)):
			_field_renderer.spawn_action_particles(gx, gy, Color(0.52, 0.34, 0.22), 5)
			_play_sfx("rake", randf_range(0.94, 1.08))
	elif tid == "water":
		is_tool_action = true
		res = simulation.apply_water(gx, gy, time_weather.weather_type)
		if bool(res.get("ok", false)):
			_field_renderer.spawn_action_particles(gx, gy, Color(0.35, 0.70, 0.95), 6)
			_play_sfx("water", randf_range(0.95, 1.05))
	elif tid == "compost":
		is_consumable_action = true
		res = simulation.apply_compost(gx, gy)
		if bool(res.get("ok", false)):
			_field_renderer.spawn_action_particles(gx, gy, Color(0.38, 0.25, 0.16), 5)
			_field_renderer.spawn_action_particles(gx, gy, Color(0.42, 0.80, 0.36), 4)
			_field_renderer.spawn_floating_text(gx, gy, "+Compost", Color(0.62, 0.94, 0.52))
			_play_sfx("rake", randf_range(0.94, 1.06))
	elif tid == "probe":
		is_tool_action = true
		res = simulation.apply_probe(gx, gy)
		if bool(res.get("ok", false)):
			var n_val: int = int(round(float(res["n"])))
			var p_val: int = int(round(float(res["p"])))
			var k_val: int = int(round(float(res["k"])))
			_field_renderer.spawn_action_particles(gx, gy, Color(0.32, 0.88, 0.94), 5)
			_field_renderer.spawn_action_particles(gx, gy, Color(0.42, 0.86, 0.48), 4)
			_field_renderer.spawn_floating_text(gx, gy, "N%d P%d K%d" % [n_val, p_val, k_val], Color(0.55, 0.96, 0.98))
			_play_sfx("tap", 1.25)
			_show_toast("Analisi zolla: N %d · P %d · K %d" % [n_val, p_val, k_val])
	elif tid.begins_with("seed:"):
		is_consumable_action = true
		var crop_id: String = tid.substr(5)
		res = simulation.plant_seed(gx, gy, crop_id)
		if bool(res.get("ok", false)):
			_field_renderer.spawn_action_particles(gx, gy, Color(0.82, 0.78, 0.45), 4)
			_play_sfx("seed", randf_range(0.95, 1.12))

	GameState.sync_field_resources_to_state(simulation)

	if bool(res.get("ok", false)):
		if is_tool_action:
			var dmg: Dictionary = GameState.inventory.damage_tool_in_slot("hotbar", slot_idx, 1)
			if bool(dmg.get("broken", false)):
				_field_renderer.clear_action_queue()
				_show_toast("Attrezzo rotto! Riparalo nello Zaino.")
		elif is_consumable_action:
			GameState.inventory.consume_from_slot("hotbar", slot_idx, 1)
			if GameState.inventory.get_slot("hotbar", slot_idx).is_empty():
				_field_renderer.clear_action_queue()
	elif str(res.get("reason", "")) == "no_energy":
		_field_renderer.clear_action_queue()
		_show_toast("Energia esaurita! Tocca 'Dormi +1g' per ricaricare.")

	_sync_all_ui()


func _on_backpack_repair_requested(container: String, index: int) -> void:
	var slot: Dictionary = GameState.inventory.get_slot(container, index)
	if slot.is_empty() or not slot.has("durability"):
		return
	var item_id: String = str(slot.get("item_id", ""))
	var item_def: Dictionary = GameState.items_db.get(item_id, {})
	var cost: int = int(item_def.get("repair_cost", 15))
	if GameState.coins < cost:
		_play_sfx("tap", 0.8)
		_show_toast("Monete insufficienti! Servono %d €." % cost)
		return
	var rep: Dictionary = GameState.inventory.repair_tool_in_slot(container, index)
	if bool(rep.get("ok", false)):
		var actual_cost: int = int(rep.get("cost", cost))
		GameState.coins -= actual_cost
		GameState.sync_state_to_field(simulation)
		SaveManager.save_game(GameState)
		_play_sfx("rake", 1.15)
		_backpack_panel.refresh(GameState.inventory, GameState.crops_db)
		_sync_all_ui()
		_show_toast("%s riparato (-%d €)!" % [str(item_def.get("name", item_id)), actual_cost])


func _on_backpack_sell_crops_requested() -> void:
	var res: Dictionary = GameState.inventory.sell_all_crops()
	var sold_count: int = int(res.get("sold_count", 0))
	var earned: int = int(res.get("earned", 0))
	if sold_count <= 0:
		_play_sfx("tap", 0.85)
		_show_toast("Nessun raccolto da vendere nello Zaino.")
		return
	GameState.coins += earned
	GameState.sync_state_to_field(simulation)
	SaveManager.save_game(GameState)
	_play_sfx("harvest")
	_backpack_panel.refresh(GameState.inventory, GameState.crops_db)
	_sync_all_ui()
	_show_toast("Venduti %d raccolti (+%d €)!" % [sold_count, earned])


func _on_backpack_refill_seeds_requested() -> void:
	var added_total: int = 0
	for key: Variant in GameState.items_db.keys():
		var item_id: String = str(key)
		var item_def: Dictionary = GameState.items_db[item_id]
		var cat: String = str(item_def.get("category", ""))
		if cat == "seed" or item_id == "compost":
			added_total += GameState.inventory.add_item(item_id, 10)
	_play_sfx("seed", 1.1)
	_backpack_panel.refresh(GameState.inventory, GameState.crops_db)
	_sync_all_ui()
	if added_total > 0:
		_show_toast("+10 di ogni Seme e +10 Compost aggiunti!")
	else:
		_show_toast("Zaino pieno! Libera spazio per aggiungere semi.")


func _on_backpack_save_requested() -> void:
	var ok: bool = SaveManager.save_game(GameState)
	_play_sfx("tap", 1.1)
	_show_toast("Partita salvata!" if ok else "Errore durante il salvataggio.")


func _on_backpack_reset_requested() -> void:
	_field_renderer.clear_action_queue()
	SaveManager.delete_save()
	GameState.new_game()
	_bind_from_game_state()
	_field_renderer.simulation = simulation
	_field_renderer.time_weather = time_weather
	_field_renderer.selected_tile = Vector2i(-1, -1)
	_field_renderer.farmer_pos = Vector2(4.5 * TILE_SIZE, 2.5 * TILE_SIZE)
	_field_renderer.farmer_target = _field_renderer.farmer_pos
	_minimap.simulation = simulation
	_recompute_field_scale()
	_apply_scroll(0.0)
	_set_backpack_visible(false)
	_set_inspector_visible(false)
	_play_sfx("tap", 0.9)
	_sync_all_ui()
	_show_toast("Nuova partita avviata!")


func _on_sleep_pressed() -> void:
	_midnight_notified = false
	_field_renderer.clear_action_queue()
	var summary: Dictionary = GameState.advance_day(true)
	simulation = GameState.get_active_field()
	_set_inspector_visible(false)
	_field_renderer.selected_tile = Vector2i(-1, -1)
	_play_sfx("tap", 0.9)
	if _backpack_panel.visible:
		_backpack_panel.refresh(GameState.inventory, GameState.crops_db)
	_sync_all_ui()

	var msg: String = "%s G.%d (%s %d°/%d°C)" % [
		time_weather.get_season_short(),
		time_weather.day_in_season,
		time_weather.get_weather_icon_text(),
		int(time_weather.temp_min),
		int(time_weather.temp_max),
	]
	var ready_cnt: int = int(summary.get("crops_ready", 0))
	var stressed_cnt: int = int(summary.get("crops_stressed", 0))
	var expired_cnt: int = int(summary.get("expired_count", 0))
	if ready_cnt > 0:
		msg += " · %d pronte!" % ready_cnt
	elif stressed_cnt > 0:
		msg += " · %d in stress termico!" % stressed_cnt
	if expired_cnt > 0:
		msg += " · %d prodotti scaduti -> Scarti Vegetali" % expired_cnt
	_show_toast(msg)


func _on_time_cycle_pressed() -> void:
	_midnight_notified = false
	var phase_label: String = time_weather.cycle_time_of_day_for_test()
	_play_sfx("tap", 1.1)
	_sync_all_ui()
	_show_toast("Fascia oraria: %s" % phase_label)


func _on_season_cycle_pressed() -> void:
	_midnight_notified = false
	time_weather.cycle_season_for_test()
	_set_inspector_visible(false)
	_play_sfx("tap", 1.15)
	_sync_all_ui()
	_show_toast("Test Stagione: %s (%d°/%d°C)" % [
		time_weather.get_season_label(),
		int(time_weather.temp_min),
		int(time_weather.temp_max),
	])


func _is_edible_harvest_ready(crop: Dictionary) -> bool:
	if crop.is_empty() or bool(crop.get("withered", false)) or not bool(crop.get("harvest_ready", false)):
		return false
	var def: Dictionary = crops_db.get(str(crop.get("crop_id", "")), {})
	return not bool(def.get("is_green_manure", false))


func _on_harvest_all_pressed() -> void:
	var queued: int = 0
	for y: int in range(simulation.height):
		for x: int in range(simulation.width):
			var cell: Dictionary = simulation.get_cell(x, y)
			var crop: Dictionary = cell["crop"]
			if _is_edible_harvest_ready(crop):
				_field_renderer.enqueue_farmer_action({
					"gx": x,
					"gy": y,
					"action": "harvest",
					"tool_id": "harvest_or_clear",
					"crop_id": str(crop.get("crop_id", "")),
				})
				queued += 1
	if queued > 0:
		_set_inspector_visible(false)
		_show_toast("Il contadino sta raccogliendo %d piante..." % queued)


func _sync_all_ui() -> void:
	_top_bar.update_state(time_weather, simulation, GameState.coins, GameState.energy, GameState.max_energy)
	var ready_count: int = 0
	for cell: Dictionary in simulation.cells:
		var crop: Dictionary = cell["crop"]
		if _is_edible_harvest_ready(crop):
			ready_count += 1
	_tool_dock.update_ready_count(ready_count)
	_tool_dock.refresh_hotbar(GameState.inventory, GameState.selected_hotbar_index)
	_field_renderer.weather_type = time_weather.weather_type
	_field_renderer.modulate = time_weather.get_daylight_modulate()
	_field_renderer.queue_redraw()
	_minimap.queue_redraw()


func _show_toast(msg: String) -> void:
	_toast_label.text = msg
	_toast_panel.visible = true
	_toast_timer = 3.2
