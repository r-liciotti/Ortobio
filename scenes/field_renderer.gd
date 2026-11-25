class_name FieldRenderer
extends Node2D
## Crisp 16x16 pixel-art renderer with 4-bit rounded soil autotiling, 3/4 crops,
## and a detailed 24x28 Stardew-style farmer with arrival-triggered per-tool animations.

signal farmer_action_impact(req: Dictionary)

const TILE_SIZE := 16.0
const CROP_H := 20.0
const CROP_Y_OFFSET := -4.0
const FARMER_W := 24.0
const FARMER_H := 28.0
const FARMER_SPEED := 112.0
const ACTION_DURATION := 0.28
const ACTION_IMPACT_RATIO := 0.45

const CROP_ROWS := {
	"ravanello": 0,
	"pomodoro": 1,
	"cavolo_verza": 2,
}
const ACTION_SHEET_ROWS := {
	"spade": 1,
	"rake": 2,
	"water": 3,
	"seed": 4,
	"harvest": 5,
}

enum FarmerState {
	IDLE,
	WALKING,
	ACTING,
}

var simulation: GridSimulation
var atlas_tex: Texture2D
var soil_tex: Texture2D
var crops_tex: Texture2D
var farmer_tex: Texture2D
var selected_tile: Vector2i = Vector2i(-1, -1)
var weather_type: String = "sole"

var farmer_pos: Vector2 = Vector2(4.5 * TILE_SIZE, 2.5 * TILE_SIZE)
var farmer_target: Vector2 = Vector2(4.5 * TILE_SIZE, 2.5 * TILE_SIZE)
var farmer_facing_left: bool = false
var _farmer_state: FarmerState = FarmerState.IDLE
var _farmer_walk_phase: float = 0.0
var _active_req: Dictionary = {}
var _action_elapsed: float = 0.0
var _action_impact_fired: bool = false
var _action_queue: Array[Dictionary] = []

var _harvest_pops: Array[Dictionary] = []
var _particles: Array[Dictionary] = []
var _floating_texts: Array[Dictionary] = []
var _weather_drops: Array[Dictionary] = []
var _anim_time: float = 0.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	atlas_tex = _load_pixel_texture("res://assets/tiles/field_atlas.png")
	soil_tex = _load_pixel_texture("res://assets/tiles/soil_autotile.png")
	crops_tex = _load_pixel_texture("res://assets/tiles/crops_atlas.png")
	farmer_tex = _load_pixel_texture("res://assets/tiles/farmer_sheet.png")
	_init_weather_drops()


func _load_pixel_texture(res_path: String) -> Texture2D:
	if ResourceLoader.exists(res_path):
		var loaded := load(res_path)
		if loaded is Texture2D:
			return loaded
	var img := Image.load_from_file(ProjectSettings.globalize_path(res_path))
	if img != null and not img.is_empty():
		return ImageTexture.create_from_image(img)
	return null


func enqueue_farmer_action(req: Dictionary) -> void:
	## Queues a tile action. The farmer walks to the tile and animates ONLY upon arrival.
	var gx := int(req["gx"])
	var gy := int(req["gy"])
	var act := str(req["action"])

	# Avoid duplicate pending requests on the exact same tile+action
	if not _active_req.is_empty() and int(_active_req["gx"]) == gx and int(_active_req["gy"]) == gy and str(_active_req["action"]) == act:
		return
	for existing in _action_queue:
		if int(existing["gx"]) == gx and int(existing["gy"]) == gy and str(existing["action"]) == act:
			return

	_action_queue.append(req)
	if _farmer_state == FarmerState.IDLE:
		_start_next_queued_action()
	queue_redraw()


func clear_action_queue() -> void:
	_action_queue.clear()
	_active_req = {}
	_farmer_state = FarmerState.IDLE
	_action_elapsed = 0.0
	_action_impact_fired = false
	queue_redraw()


func _start_next_queued_action() -> void:
	if _action_queue.is_empty():
		_active_req = {}
		_farmer_state = FarmerState.IDLE
		return

	_active_req = _action_queue.pop_front()
	var gx := int(_active_req["gx"])
	var gy := int(_active_req["gy"])
	var tile_center := Vector2((gx + 0.5) * TILE_SIZE, (gy + 0.5) * TILE_SIZE)

	# Stand snugly beside the tile (left or right depending on approach side)
	var field_w := float(simulation.width if simulation != null else 10) * TILE_SIZE
	var field_h := float(simulation.height if simulation != null else 30) * TILE_SIZE
	var left_x := clampf(tile_center.x - 9.0, 9.0, field_w - 9.0)
	var right_x := clampf(tile_center.x + 9.0, 9.0, field_w - 9.0)
	var stand_x := left_x if absf(farmer_pos.x - left_x) <= absf(farmer_pos.x - right_x) else right_x
	var stand_y := clampf(tile_center.y + 3.0, 14.0, field_h - 4.0)

	# Avoid awkward backwards step when already standing right next to the target tile
	var dx_to_tile := farmer_pos.x - tile_center.x
	if absf(dx_to_tile) >= 5.0 and absf(dx_to_tile) <= 11.5:
		stand_x = farmer_pos.x

	farmer_target = Vector2(stand_x, stand_y)

	# If player scrolled far away, gently hop closer so farmer jogs in swiftly
	var dist := farmer_pos.distance_to(farmer_target)
	if dist > TILE_SIZE * 6.0:
		var dir := (farmer_pos - farmer_target).normalized()
		farmer_pos = farmer_target + dir * (TILE_SIZE * 2.4)
		dist = farmer_pos.distance_to(farmer_target)

	# For short adjustments near the tile, keep facing the tile instead of turning away
	if dist < 10.0:
		farmer_facing_left = (tile_center.x < stand_x)
	else:
		farmer_facing_left = (farmer_target.x < farmer_pos.x)
	_farmer_state = FarmerState.WALKING


func spawn_harvest_pop(gx: int, gy: int, crop_id: String) -> void:
	_harvest_pops.append({
		"gx": gx,
		"gy": gy,
		"crop_id": crop_id,
		"elapsed": 0.0,
		"duration": 0.42,
	})
	queue_redraw()


func _init_weather_drops() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for _i in range(42):
		_weather_drops.append({
			"x": rng.randf_range(0.0, 160.0),
			"y": rng.randf_range(0.0, 480.0),
			"speed": rng.randf_range(70.0, 130.0),
		})


func spawn_action_particles(gx: int, gy: int, color: Color, count: int = 6) -> void:
	var center := Vector2((gx + 0.5) * TILE_SIZE, (gy + 0.5) * TILE_SIZE)
	for i in range(count):
		var angle := (TAU / float(count)) * float(i) + randf_range(-0.3, 0.3)
		var speed := randf_range(14.0, 32.0)
		_particles.append({
			"pos": center,
			"vel": Vector2(cos(angle), sin(angle) - 0.6) * speed,
			"life": 0.42,
			"max_life": 0.42,
			"color": color,
		})
	queue_redraw()


func spawn_floating_text(gx: int, gy: int, text: String, color: Color) -> void:
	_floating_texts.append({
		"pos": Vector2((gx + 0.5) * TILE_SIZE, gy * TILE_SIZE + 2.0),
		"text": text,
		"color": color,
		"life": 1.1,
		"max_life": 1.1,
	})
	queue_redraw()


func _process(delta: float) -> void:
	_anim_time += delta
	var dirty := false

	# Farmer state machine: WALKING -> arrive -> ACTING -> impact -> next queued tile
	if _farmer_state == FarmerState.WALKING:
		var to_target := farmer_target - farmer_pos
		var dist := to_target.length()
		if dist > 1.2:
			var step := minf(dist, FARMER_SPEED * delta)
			farmer_pos += to_target.normalized() * step
			if dist >= 10.0 and absf(to_target.x) > 0.5:
				farmer_facing_left = (to_target.x < 0.0)
			_farmer_walk_phase += delta * 12.0
		else:
			farmer_pos = farmer_target
			# Face the target tile and begin the farmer's tool animation!
			var tile_x := (float(_active_req["gx"]) + 0.5) * TILE_SIZE
			farmer_facing_left = (tile_x < farmer_pos.x)
			_farmer_state = FarmerState.ACTING
			_action_elapsed = 0.0
			_action_impact_fired = false
		dirty = true
	elif _farmer_state == FarmerState.ACTING:
		_action_elapsed += delta
		var ratio := clampf(_action_elapsed / ACTION_DURATION, 0.0, 1.0)
		if not _action_impact_fired and ratio >= ACTION_IMPACT_RATIO:
			_action_impact_fired = true
			farmer_action_impact.emit(_active_req)
		if _action_elapsed >= ACTION_DURATION:
			_start_next_queued_action()
		dirty = true

	for i in range(_harvest_pops.size() - 1, -1, -1):
		var hp: Dictionary = _harvest_pops[i]
		hp["elapsed"] = float(hp["elapsed"]) + delta
		if float(hp["elapsed"]) >= float(hp["duration"]):
			_harvest_pops.remove_at(i)
		dirty = true

	for i in range(_particles.size() - 1, -1, -1):
		var p: Dictionary = _particles[i]
		p["life"] = float(p["life"]) - delta
		p["pos"] = p["pos"] + p["vel"] * delta
		p["vel"] = p["vel"] + Vector2(0, 60.0) * delta
		if float(p["life"]) <= 0.0:
			_particles.remove_at(i)
		dirty = true

	for i in range(_floating_texts.size() - 1, -1, -1):
		var ft: Dictionary = _floating_texts[i]
		ft["life"] = float(ft["life"]) - delta
		ft["pos"] = ft["pos"] + Vector2(0, -14.0) * delta
		if float(ft["life"]) <= 0.0:
			_floating_texts.remove_at(i)
		dirty = true

	if weather_type == "pioggia" or weather_type == "neve":
		var max_h := float(simulation.height if simulation != null else 30) * TILE_SIZE
		var spd_mult := 1.0 if weather_type == "pioggia" else 0.32
		for d in _weather_drops:
			d["y"] = float(d["y"]) + float(d["speed"]) * spd_mult * delta
			if weather_type == "neve":
				d["x"] = fmod(float(d["x"]) + sin(_anim_time * 2.0 + float(d["y"]) * 0.05) * 8.0 * delta + 160.0, 160.0)
			if float(d["y"]) > max_h:
				d["y"] = 0.0
		dirty = true

	if dirty:
		queue_redraw()


func _tile_src(col: int, row: int) -> Rect2:
	return Rect2(col * TILE_SIZE, row * TILE_SIZE, TILE_SIZE, TILE_SIZE)


func _is_tilled(x: int, y: int) -> bool:
	if not simulation.is_valid(x, y):
		return false
	return int(simulation.get_cell(x, y)["soil_state"]) != GridSimulation.SoilState.INCOLTO


func _draw() -> void:
	if simulation == null or atlas_tex == null or soil_tex == null or crops_tex == null:
		return

	var wet_thresh := float(simulation.config.get("soil", {}).get("moisture_waterlogged_threshold", 82.0))
	var dry_thresh := float(simulation.config.get("soil", {}).get("moisture_dry_threshold", 25.0))

	# Pass 1: Organic meadow grass + 4-bit autotiled rounded 3D soil beds
	for y in range(simulation.height):
		for x in range(simulation.width):
			var cell := simulation.get_cell(x, y)
			var dst := Rect2(x * TILE_SIZE, y * TILE_SIZE, TILE_SIZE, TILE_SIZE)

			var g_var := (x * 7 + y * 13) % 4
			draw_texture_rect_region(atlas_tex, dst, _tile_src(g_var, 0))

			var s_state := int(cell["soil_state"])
			if s_state != GridSimulation.SoilState.INCOLTO:
				var n := _is_tilled(x, y - 1)
				var e := _is_tilled(x + 1, y)
				var s := _is_tilled(x, y + 1)
				var w := _is_tilled(x - 1, y)
				var mask := (1 if n else 0) | (2 if e else 0) | (4 if s else 0) | (8 if w else 0)

				var moist := float(cell["moisture"])
				var is_wet := moist >= dry_thresh
				var soil_row := 0
				if s_state == GridSimulation.SoilState.VANGATO:
					soil_row = 1 if is_wet else 0
				else:
					if moist > wet_thresh:
						soil_row = 4
					else:
						soil_row = 3 if is_wet else 2

				draw_texture_rect_region(soil_tex, dst, _tile_src(mask, soil_row))

				if n and w and not _is_tilled(x - 1, y - 1):
					draw_texture_rect_region(atlas_tex, dst, _tile_src(4, 0))
				if n and e and not _is_tilled(x + 1, y - 1):
					draw_texture_rect_region(atlas_tex, dst, _tile_src(5, 0))
				if s and w and not _is_tilled(x - 1, y + 1):
					draw_texture_rect_region(atlas_tex, dst, _tile_src(6, 0))
				if s and e and not _is_tilled(x + 1, y + 1):
					draw_texture_rect_region(atlas_tex, dst, _tile_src(7, 0))

	# Subtle queued-tile highlights so player sees pending drag targets immediately
	if not _active_req.is_empty():
		var act_dst := Rect2(int(_active_req["gx"]) * TILE_SIZE, int(_active_req["gy"]) * TILE_SIZE, TILE_SIZE, TILE_SIZE)
		draw_texture_rect_region(atlas_tex, act_dst, _tile_src(4, 1), Color(1.0, 1.0, 1.0, 0.85))
	for req in _action_queue:
		var q_dst := Rect2(int(req["gx"]) * TILE_SIZE, int(req["gy"]) * TILE_SIZE, TILE_SIZE, TILE_SIZE)
		draw_texture_rect_region(atlas_tex, q_dst, _tile_src(4, 1), Color(1.0, 1.0, 1.0, 0.45))

	# Pass 2: Y-sorted 3/4-perspective crops (16x20) + detailed 24x28 farmer avatar
	var farmer_row := clampi(int(floor(farmer_pos.y / TILE_SIZE)), 0, simulation.height - 1)
	var farmer_drawn := false
	for y in range(simulation.height):
		for x in range(simulation.width):
			var cell := simulation.get_cell(x, y)
			var crop: Dictionary = cell["crop"]
			if crop.is_empty():
				continue

			var crop_id := str(crop["crop_id"])
			var row_idx := int(CROP_ROWS.get(crop_id, 0))
			var stage := int(crop.get("stage", 0))
			var crop_dst := Rect2(x * TILE_SIZE, y * TILE_SIZE + CROP_Y_OFFSET, TILE_SIZE, CROP_H)
			var crop_src := Rect2(stage * TILE_SIZE, row_idx * CROP_H, TILE_SIZE, CROP_H)
			draw_texture_rect_region(crops_tex, crop_dst, crop_src)

			var tile_pos := Vector2(x * TILE_SIZE, y * TILE_SIZE)
			var stress := str(crop.get("stress_reason", ""))
			if bool(crop.get("harvest_ready", false)):
				draw_texture_rect_region(atlas_tex, Rect2(tile_pos, Vector2(TILE_SIZE, TILE_SIZE)), _tile_src(3, 1))
			elif stress == "frost":
				draw_texture_rect_region(atlas_tex, Rect2(tile_pos + Vector2(8, -2), Vector2(8, 8)), _tile_src(1, 1))
			elif stress == "dry":
				draw_texture_rect_region(atlas_tex, Rect2(tile_pos + Vector2(8, -2), Vector2(8, 8)), _tile_src(0, 1))

		if y == farmer_row and farmer_tex != null:
			_draw_farmer()
			farmer_drawn = true

	if not farmer_drawn and farmer_tex != null:
		_draw_farmer()

	# Pass 3: Selected tile highlight (Explore inspector)
	if selected_tile.x >= 0 and selected_tile.y >= 0:
		var sel_dst := Rect2(selected_tile.x * TILE_SIZE, selected_tile.y * TILE_SIZE, TILE_SIZE, TILE_SIZE)
		draw_texture_rect_region(atlas_tex, sel_dst, _tile_src(4, 1))

	# Pass 4: Harvested crop pop-up & soil/water particles
	for hp in _harvest_pops:
		var cid := str(hp["crop_id"])
		if crops_tex != null and CROP_ROWS.has(cid):
			var t := clampf(float(hp["elapsed"]) / maxf(0.01, float(hp["duration"])), 0.0, 1.0)
			var cx := (float(hp["gx"]) + 0.5) * TILE_SIZE
			var cy := (float(hp["gy"]) + 0.5) * TILE_SIZE
			var pop_y := -sin(t * PI) * 10.0 - t * 4.0
			var row_idx := int(CROP_ROWS[cid])
			var crop_src := Rect2(4 * TILE_SIZE, row_idx * CROP_H, TILE_SIZE, CROP_H)
			draw_texture_rect_region(
				crops_tex,
				Rect2(cx - 8.0, cy - 12.0 + pop_y, TILE_SIZE, CROP_H),
				crop_src,
				Color(1.0, 1.0, 1.0, clampf(1.2 - t, 0.0, 1.0))
			)

	for p in _particles:
		var alpha := clampf(float(p["life"]) / float(p["max_life"]), 0.0, 1.0)
		var col: Color = p["color"]
		col.a = alpha
		draw_rect(Rect2(p["pos"] - Vector2(1, 1), Vector2(2, 2)), col)

	# Pass 5: Weather precipitation overlay
	if weather_type == "pioggia":
		for d in _weather_drops:
			var p0 := Vector2(float(d["x"]), float(d["y"]))
			draw_line(p0, p0 + Vector2(-1.5, 4.5), Color(0.55, 0.80, 1.0, 0.55), 1.0)
	elif weather_type == "neve":
		for d in _weather_drops:
			var p0 := Vector2(float(d["x"]), float(d["y"]))
			draw_rect(Rect2(p0, Vector2(1.5, 1.5)), Color(0.95, 0.98, 1.0, 0.80))

	# Pass 6: Floating feedback labels
	var font := ThemeDB.fallback_font
	for ft in _floating_texts:
		var alpha := clampf(float(ft["life"]) / float(ft["max_life"]), 0.0, 1.0)
		var col: Color = ft["color"]
		col.a = alpha
		draw_string(font, ft["pos"], str(ft["text"]), HORIZONTAL_ALIGNMENT_CENTER, -1, 7, col)


func _draw_farmer() -> void:
	var sheet_row := 0
	var frame := 0
	if _farmer_state == FarmerState.WALKING:
		sheet_row = 0
		var step_idx := int(floor(_farmer_walk_phase)) % 4
		frame = step_idx
	elif _farmer_state == FarmerState.ACTING:
		var act := str(_active_req.get("action", ""))
		sheet_row = int(ACTION_SHEET_ROWS.get(act, 1))
		var t := clampf(_action_elapsed / ACTION_DURATION, 0.0, 0.999)
		frame = clampi(int(floor(t * 4.0)), 0, 3)

	var src := Rect2(frame * FARMER_W, sheet_row * FARMER_H, FARMER_W, FARMER_H)
	var sx := -1.0 if farmer_facing_left else 1.0
	draw_set_transform(farmer_pos, 0.0, Vector2(sx, 1.0))
	draw_texture_rect_region(farmer_tex, Rect2(-FARMER_W * 0.5, -FARMER_H + 3.0, FARMER_W, FARMER_H), src)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
