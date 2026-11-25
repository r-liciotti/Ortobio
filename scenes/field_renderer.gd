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
	"piselli": 3,
	"trifoglio": 4,
}
const ACTION_SHEET_ROWS := {
	"spade": 1,
	"rake": 2,
	"water": 3,
	"seed": 4,
	"harvest": 5,
	"compost": 6,
	"probe": 7,
}

enum FarmerState {
	IDLE,
	WALKING,
	ACTING,
}

var simulation: GridSimulation
var time_weather: TimeWeatherManager = null
var atlas_tex: Texture2D
var soil_tex: Texture2D
var crops_tex: Texture2D
var farmer_tex: Texture2D
var cloud_tex: Texture2D
var selected_tile: Vector2i = Vector2i(-1, -1)
var weather_type: String = "sole"
var show_npk_overlay: bool = false

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
var _cloud_shadows: Array[Dictionary] = []
var _wind_motes: Array[Dictionary] = []
var _anim_time: float = 0.0
var _wind_time: float = 0.0
var _lantern_sprite: Sprite2D = null
var _npk_sb_high: StyleBoxFlat
var _npk_sb_mid: StyleBoxFlat
var _npk_sb_low: StyleBoxFlat
var _npk_sb_unknown: StyleBoxFlat


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	atlas_tex = _load_pixel_texture("res://assets/tiles/field_atlas.png")
	soil_tex = _load_pixel_texture("res://assets/tiles/soil_autotile.png")
	crops_tex = _load_pixel_texture("res://assets/tiles/crops_atlas.png")
	farmer_tex = _load_pixel_texture("res://assets/tiles/farmer_sheet.png")
	cloud_tex = _load_pixel_texture("res://assets/tiles/cloud_shadows.png")
	_init_weather_drops()
	_init_cloud_shadows()
	_init_wind_motes()
	_init_lantern_glow()


func _init_lantern_glow() -> void:
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.28, 0.65, 1.0])
	grad.colors = PackedColorArray([
		Color(1.0, 0.86, 0.56, 0.55),
		Color(1.0, 0.76, 0.40, 0.28),
		Color(0.95, 0.62, 0.28, 0.08),
		Color(0.90, 0.55, 0.20, 0.0),
	])
	var grad_tex := GradientTexture2D.new()
	grad_tex.gradient = grad
	grad_tex.width = 96
	grad_tex.height = 96
	grad_tex.fill = GradientTexture2D.FILL_RADIAL
	grad_tex.fill_from = Vector2(0.5, 0.5)
	grad_tex.fill_to = Vector2(0.5, 0.0)

	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

	_lantern_sprite = Sprite2D.new()
	_lantern_sprite.texture = grad_tex
	_lantern_sprite.material = mat
	_lantern_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_lantern_sprite.z_index = 5
	_lantern_sprite.visible = false
	add_child(_lantern_sprite)
	_init_npk_styles()


func _init_npk_styles() -> void:
	_npk_sb_high = _make_overlay_sb(Color(0.24, 0.82, 0.34, 0.36))
	_npk_sb_mid = _make_overlay_sb(Color(0.95, 0.78, 0.22, 0.40))
	_npk_sb_low = _make_overlay_sb(Color(0.92, 0.28, 0.24, 0.46))
	_npk_sb_unknown = _make_overlay_sb(Color(0.12, 0.14, 0.18, 0.26))


func _make_overlay_sb(col: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.anti_aliasing = false
	sb.corner_radius_top_left = 2
	sb.corner_radius_top_right = 2
	sb.corner_radius_bottom_left = 2
	sb.corner_radius_bottom_right = 2
	return sb


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
	if _farmer_state == FarmerState.IDLE or (_farmer_state == FarmerState.WALKING and _active_req.is_empty()):
		_start_next_queued_action()
	queue_redraw()


func clear_action_queue() -> void:
	_action_queue.clear()
	_active_req = {}
	_farmer_state = FarmerState.IDLE
	_action_elapsed = 0.0
	_action_impact_fired = false
	queue_redraw()


func command_farmer_walk_to(world_pos: Vector2) -> void:
	## Cancels any pending work and walks the farmer smoothly to a free point in the field.
	_action_queue.clear()
	_active_req = {}
	_action_elapsed = 0.0
	_action_impact_fired = false

	var field_w: float = float(simulation.width if simulation != null else 10) * TILE_SIZE
	var field_h: float = float(simulation.height if simulation != null else 30) * TILE_SIZE
	farmer_target = Vector2(
		clampf(world_pos.x, 9.0, field_w - 9.0),
		clampf(world_pos.y, 14.0, field_h - 4.0)
	)

	# Only reposition if farmer is completely off-screen (> 16 tiles away), keeping them off-edge so no visible snap occurs
	var dist: float = farmer_pos.distance_to(farmer_target)
	if dist > TILE_SIZE * 16.0:
		var dir: Vector2 = (farmer_pos - farmer_target).normalized()
		farmer_pos = farmer_target + dir * (TILE_SIZE * 14.0)
		dist = farmer_pos.distance_to(farmer_target)

	if absf(farmer_target.x - farmer_pos.x) > 0.5:
		farmer_facing_left = (farmer_target.x < farmer_pos.x)
	_farmer_state = FarmerState.WALKING
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

	# Only reposition if farmer is completely off-screen (> 16 tiles away), keeping them off-edge so no visible snap occurs
	var dist := farmer_pos.distance_to(farmer_target)
	if dist > TILE_SIZE * 16.0:
		var dir := (farmer_pos - farmer_target).normalized()
		farmer_pos = farmer_target + dir * (TILE_SIZE * 14.0)
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


func _init_cloud_shadows() -> void:
	_cloud_shadows.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	for i: int in range(6):
		var scale_c: float = rng.randf_range(0.90, 1.35)
		_cloud_shadows.append({
			"x": (float(i) / 6.0) * 260.0 - 40.0 + rng.randf_range(-10.0, 10.0),
			"y": rng.randf_range(24.0, 456.0),
			"variant": i % 3,
			"w": 64.0 * scale_c,
			"h": 32.0 * scale_c,
			"rx": 32.0 * scale_c,
			"ry": 16.0 * scale_c,
			"speed": rng.randf_range(5.0, 10.0),
		})


func _init_wind_motes() -> void:
	_wind_motes.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 4040
	for _i: int in range(12):
		_wind_motes.append({
			"x": rng.randf_range(0.0, 160.0),
			"y": rng.randf_range(0.0, 480.0),
			"speed_x": rng.randf_range(16.0, 30.0),
			"speed_y": rng.randf_range(4.0, 10.0),
			"len": rng.randf_range(3.5, 6.5),
			"is_streak": rng.randf() < 0.45,
			"phase": rng.randf_range(0.0, TAU),
			"alpha": rng.randf_range(0.16, 0.30),
		})


func _effective_weather() -> String:
	if time_weather != null:
		return time_weather.weather_type
	return weather_type


func _get_wind_gust(x: float, y: float) -> float:
	var wave: float = sin(_wind_time * 2.1 + x * 0.45 + y * 0.30) * (0.55 + 0.45 * sin(_wind_time * 0.65 + y * 0.15))
	var cur_weather: String = _effective_weather()
	var weather_mult: float = 1.35 if cur_weather == "pioggia" else (1.12 if cur_weather == "neve" else 1.0)
	return wave * weather_mult


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
	var cur_weather: String = _effective_weather()
	var wind_speed_mult: float = 1.35 if cur_weather == "pioggia" else (1.12 if cur_weather == "neve" else 1.0)
	_wind_time += delta * wind_speed_mult

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
			if _active_req.is_empty():
				_farmer_state = FarmerState.IDLE
			else:
				# Face the target tile and begin the farmer's tool animation!
				var tile_x: float = (float(_active_req["gx"]) + 0.5) * TILE_SIZE
				farmer_facing_left = (tile_x < farmer_pos.x)
				_farmer_state = FarmerState.ACTING
				_action_elapsed = 0.0
				_action_impact_fired = false
	elif _farmer_state == FarmerState.ACTING:
		_action_elapsed += delta
		var ratio := clampf(_action_elapsed / ACTION_DURATION, 0.0, 1.0)
		if not _action_impact_fired and ratio >= ACTION_IMPACT_RATIO:
			_action_impact_fired = true
			farmer_action_impact.emit(_active_req)
		if _action_elapsed >= ACTION_DURATION:
			_start_next_queued_action()

	for i in range(_harvest_pops.size() - 1, -1, -1):
		var hp: Dictionary = _harvest_pops[i]
		hp["elapsed"] = float(hp["elapsed"]) + delta
		if float(hp["elapsed"]) >= float(hp["duration"]):
			_harvest_pops.remove_at(i)

	for i in range(_particles.size() - 1, -1, -1):
		var p: Dictionary = _particles[i]
		p["life"] = float(p["life"]) - delta
		p["pos"] = p["pos"] + p["vel"] * delta
		p["vel"] = p["vel"] + Vector2(0, 60.0) * delta
		if float(p["life"]) <= 0.0:
			_particles.remove_at(i)

	for i in range(_floating_texts.size() - 1, -1, -1):
		var ft: Dictionary = _floating_texts[i]
		ft["life"] = float(ft["life"]) - delta
		ft["pos"] = ft["pos"] + Vector2(0, -14.0) * delta
		if float(ft["life"]) <= 0.0:
			_floating_texts.remove_at(i)

	var field_w: float = float(simulation.width if simulation != null else 10) * TILE_SIZE
	var field_h: float = float(simulation.height if simulation != null else 30) * TILE_SIZE

	var cloud_wrap_min: float = -60.0
	var cloud_wrap_max: float = field_w + 60.0
	var cloud_span: float = cloud_wrap_max - cloud_wrap_min
	for c: Dictionary in _cloud_shadows:
		var nx: float = float(c["x"]) + float(c["speed"]) * wind_speed_mult * delta
		if nx > cloud_wrap_max:
			nx -= cloud_span
		c["x"] = nx

	for m: Dictionary in _wind_motes:
		var mx: float = float(m["x"]) + float(m["speed_x"]) * wind_speed_mult * delta
		var flutter: float = sin(_anim_time * 2.4 + float(m["phase"])) * 4.0 * delta
		var my: float = float(m["y"]) + float(m["speed_y"]) * wind_speed_mult * delta + flutter
		if mx > field_w + 8.0:
			mx = -8.0
		if my > field_h + 4.0:
			my -= (field_h + 8.0)
		elif my < -4.0:
			my += (field_h + 8.0)
		m["x"] = mx
		m["y"] = my

	if cur_weather == "pioggia" or cur_weather == "neve":
		var spd_mult: float = 1.0 if cur_weather == "pioggia" else 0.32
		for d: Dictionary in _weather_drops:
			d["y"] = float(d["y"]) + float(d["speed"]) * spd_mult * delta
			if cur_weather == "neve":
				d["x"] = fmod(float(d["x"]) + sin(_anim_time * 2.0 + float(d["y"]) * 0.05) * 8.0 * delta + field_w, field_w)
			if float(d["y"]) > field_h:
				d["y"] = 0.0

	if _lantern_sprite != null:
		var night_i: float = time_weather.get_night_intensity() if time_weather != null else 0.0
		_lantern_sprite.visible = night_i > 0.04
		if _lantern_sprite.visible:
			var pulse: float = 1.0 + 0.03 * sin(_anim_time * 3.0)
			_lantern_sprite.position = farmer_pos + Vector2(0.0, -10.0)
			_lantern_sprite.scale = Vector2(0.95 * pulse, 0.82 * pulse)
			_lantern_sprite.modulate = Color(1.0, 1.0, 1.0, night_i)

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

	# Pass 1: Organic meadow grass + wind grass blades + 4-bit autotiled rounded 3D soil beds
	for y in range(simulation.height):
		for x in range(simulation.width):
			var cell := simulation.get_cell(x, y)
			var dst := Rect2(x * TILE_SIZE, y * TILE_SIZE, TILE_SIZE, TILE_SIZE)

			var g_var := (x * 7 + y * 13) % 4
			draw_texture_rect_region(atlas_tex, dst, _tile_src(g_var, 0))

			var s_state := int(cell["soil_state"])
			if s_state == GridSimulation.SoilState.INCOLTO:
				_draw_grass_wind_blades(x, y)
			else:
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

				if bool(cell.get("fertilized", false)):
					draw_texture_rect_region(atlas_tex, dst, _tile_src(5, 1))

	# Pass 1b: Optional N-P-K soil diagnostic overlay on tilled tiles
	if show_npk_overlay:
		if _npk_sb_high == null:
			_init_npk_styles()
		var overlay_font: Font = ThemeDB.fallback_font
		for y in range(simulation.height):
			for x in range(simulation.width):
				var cell: Dictionary = simulation.get_cell(x, y)
				if int(cell["soil_state"]) == GridSimulation.SoilState.INCOLTO:
					continue
				var dst := Rect2(x * TILE_SIZE, y * TILE_SIZE, TILE_SIZE, TILE_SIZE)
				var inset := dst.grow(-1.0)
				if bool(cell.get("npk_analyzed", false)):
					var min_v: float = minf(float(cell["n"]), minf(float(cell["p"]), float(cell["k"])))
					var sb_col: StyleBoxFlat = _npk_sb_high
					if min_v < 35.0:
						sb_col = _npk_sb_low
					elif min_v < 65.0:
						sb_col = _npk_sb_mid
					draw_style_box(sb_col, inset)
				else:
					draw_style_box(_npk_sb_unknown, inset)
					draw_string(
						overlay_font,
						Vector2(dst.position.x, dst.position.y + 11.0),
						"?",
						HORIZONTAL_ALIGNMENT_CENTER,
						TILE_SIZE,
						9,
						Color(0.88, 0.92, 0.96, 0.88)
					)

	# Subtle queued-tile highlights so player sees pending drag targets immediately
	if not _active_req.is_empty():
		var act_dst := Rect2(int(_active_req["gx"]) * TILE_SIZE, int(_active_req["gy"]) * TILE_SIZE, TILE_SIZE, TILE_SIZE)
		draw_texture_rect_region(atlas_tex, act_dst, _tile_src(4, 1), Color(1.0, 1.0, 1.0, 0.85))
	for req in _action_queue:
		var q_dst := Rect2(int(req["gx"]) * TILE_SIZE, int(req["gy"]) * TILE_SIZE, TILE_SIZE, TILE_SIZE)
		draw_texture_rect_region(atlas_tex, q_dst, _tile_src(4, 1), Color(1.0, 1.0, 1.0, 0.45))

	# Pass 1c: Projected silhouette sun shadows under planted crops (stage >= 1) and farmer
	var shadow_params: Dictionary = {
		"offset_x": 0.0,
		"offset_y": 1.2,
		"scale_x": 1.0,
		"skew_x": 0.0,
		"scale_y": 0.34,
		"alpha": 0.30,
	}
	if time_weather != null:
		shadow_params = time_weather.get_sun_shadow_params()

	var shadow_alpha: float = float(shadow_params.get("alpha", 0.30))
	if shadow_alpha > 0.01:
		var shadow_skew_x: float = float(shadow_params.get("skew_x", 0.0))
		var shadow_scale_y: float = float(shadow_params.get("scale_y", 0.34))
		var shadow_tint := Color(0.0, 0.0, 0.0, shadow_alpha)

		for y: int in range(simulation.height):
			for x: int in range(simulation.width):
				var cell: Dictionary = simulation.get_cell(x, y)
				var crop: Dictionary = cell["crop"]
				if crop.is_empty():
					continue
				var stage: int = int(crop.get("stage", 0))
				if stage < 1:
					continue
				var crop_id: String = str(crop["crop_id"])
				var row_idx: int = int(CROP_ROWS.get(crop_id, 0))
				var crop_src := Rect2(float(stage) * TILE_SIZE, float(row_idx) * CROP_H, TILE_SIZE, CROP_H)
				var gust: float = _get_wind_gust(float(x), float(y))
				var shear_amp: float = 0.05 + 0.014 * float(mini(stage, 4))
				var total_skew: float = shadow_skew_x - gust * shear_amp
				var base_pos := Vector2((float(x) + 0.5) * TILE_SIZE, float(y) * TILE_SIZE + 14.0)
				var local_dst := Rect2(-TILE_SIZE * 0.5, CROP_Y_OFFSET - 14.0, TILE_SIZE, CROP_H)
				var xform := Transform2D(Vector2(1.0, 0.0), Vector2(-total_skew, shadow_scale_y), base_pos)
				draw_set_transform_matrix(xform)
				draw_texture_rect_region(crops_tex, local_dst, crop_src, shadow_tint)

		if farmer_tex != null:
			var fc: Vector2i = _get_farmer_frame()
			var farmer_src := Rect2(float(fc.x) * FARMER_W, float(fc.y) * FARMER_H, FARMER_W, FARMER_H)
			var farmer_dst := Rect2(-FARMER_W * 0.5, -FARMER_H + 3.0, FARMER_W, FARMER_H)
			var sx: float = -1.0 if farmer_facing_left else 1.0
			var farmer_xform := Transform2D(Vector2(sx, 0.0), Vector2(-shadow_skew_x, shadow_scale_y), farmer_pos)
			draw_set_transform_matrix(farmer_xform)
			draw_texture_rect_region(farmer_tex, farmer_dst, farmer_src, shadow_tint)

		draw_set_transform_matrix(Transform2D.IDENTITY)

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
			var crop_src := Rect2(stage * TILE_SIZE, row_idx * CROP_H, TILE_SIZE, CROP_H)
			if stage >= 1:
				var gust: float = _get_wind_gust(float(x), float(y))
				var shear_amp: float = 0.05 + 0.014 * float(mini(stage, 4))
				var shear: float = gust * shear_amp
				var base_pos := Vector2((float(x) + 0.5) * TILE_SIZE, float(y) * TILE_SIZE + 14.0)
				var local_dst := Rect2(-TILE_SIZE * 0.5, CROP_Y_OFFSET - 14.0, TILE_SIZE, CROP_H)
				draw_set_transform_matrix(Transform2D(Vector2(1.0, 0.0), Vector2(shear, 1.0), base_pos))
				draw_texture_rect_region(crops_tex, local_dst, crop_src)
				draw_set_transform_matrix(Transform2D.IDENTITY)
			else:
				var crop_dst := Rect2(x * TILE_SIZE, y * TILE_SIZE + CROP_Y_OFFSET, TILE_SIZE, CROP_H)
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

	# Pass 5a: Drifting cloud shadows (over ground/crops, under lantern & UI/floating text)
	var cur_weather: String = _effective_weather()
	var night_i: float = time_weather.get_night_intensity() if time_weather != null else 0.0
	var cloud_count: int = 0
	var cloud_alpha: float = 0.0
	if cur_weather == "sole" or cur_weather == "ondata_calore":
		cloud_count = 3
		cloud_alpha = 0.08
	elif cur_weather == "nuvoloso":
		cloud_count = 6
		cloud_alpha = 0.16
	elif cur_weather == "gelata":
		cloud_count = 4
		cloud_alpha = 0.10
	elif cur_weather == "pioggia" or cur_weather == "neve":
		cloud_count = 6
		cloud_alpha = 0.12

	cloud_alpha *= clampf(1.0 - night_i * 0.85, 0.0, 1.0)
	if cloud_tex != null and cloud_count > 0 and cloud_alpha > 0.005:
		var field_h: float = float(simulation.height) * TILE_SIZE
		var limit: int = mini(cloud_count, _cloud_shadows.size())
		var tint := Color(1.0, 1.0, 1.0, cloud_alpha)
		for i: int in range(limit):
			var c: Dictionary = _cloud_shadows[i]
			var cx: float = float(c["x"])
			var cy: float = fposmod(float(c["y"]), field_h)
			var cw: float = float(c.get("w", 64.0))
			var ch: float = float(c.get("h", 32.0))
			var variant: int = int(c.get("variant", 0)) % 3
			var src := Rect2(float(variant) * 64.0, 0.0, 64.0, 32.0)
			var dst := Rect2(cx - cw * 0.5, cy - ch * 0.5, cw, ch)
			draw_texture_rect_region(cloud_tex, dst, src, tint)

	# Pass 5b: Weather precipitation & drifting wind streaks / pollen motes
	if cur_weather == "pioggia":
		for d: Dictionary in _weather_drops:
			var p0 := Vector2(float(d["x"]), float(d["y"]))
			draw_line(p0, p0 + Vector2(-1.5, 4.5), Color(0.55, 0.80, 1.0, 0.55), 1.0)
	elif cur_weather == "neve":
		for d: Dictionary in _weather_drops:
			var p0 := Vector2(float(d["x"]), float(d["y"]))
			draw_rect(Rect2(p0, Vector2(1.5, 1.5)), Color(0.95, 0.98, 1.0, 0.80))

	for m: Dictionary in _wind_motes:
		var mx: float = float(m["x"])
		var my: float = float(m["y"])
		var m_alpha: float = float(m["alpha"]) * (1.0 - night_i * 0.35)
		if bool(m["is_streak"]):
			var slen: float = float(m["len"])
			var streak_col := Color(0.95, 0.98, 1.0, m_alpha * 0.72)
			draw_line(Vector2(mx, my), Vector2(mx + slen, my + slen * 0.28), streak_col, 1.0)
		else:
			var mote_col := Color(1.0, 0.96, 0.78, m_alpha)
			draw_rect(Rect2(mx, my, 1.0, 1.0), mote_col)

	# Pass 6: Floating feedback labels
	var font := ThemeDB.fallback_font
	for ft in _floating_texts:
		var alpha := clampf(float(ft["life"]) / float(ft["max_life"]), 0.0, 1.0)
		var col: Color = ft["color"]
		col.a = alpha
		draw_string(font, ft["pos"], str(ft["text"]), HORIZONTAL_ALIGNMENT_CENTER, -1, 7, col)


func _draw_grass_wind_blades(gx: int, gy: int) -> void:
	var h: int = ((gx + 11) * 73856093 ^ (gy + 23) * 19349663) & 0xFFFF
	if (h % 5) == 0:
		return
	var gust: float = _get_wind_gust(float(gx), float(gy))
	var sway_x: float = gust * 1.5
	var blade_col := Color(0.46, 0.72, 0.30, 0.72)
	var bx1: float = float(gx) * TILE_SIZE + 3.0 + float(h % 9)
	var by1: float = float(gy) * TILE_SIZE + 6.0 + float((h >> 4) % 8)
	draw_line(Vector2(bx1, by1), Vector2(bx1 + sway_x, by1 - 2.2), blade_col, 1.0)
	if ((h >> 8) % 2) == 0:
		var blade_col2 := Color(0.54, 0.78, 0.34, 0.65)
		var bx2: float = float(gx) * TILE_SIZE + 2.0 + float((h >> 3) % 10)
		var by2: float = float(gy) * TILE_SIZE + 5.0 + float((h >> 7) % 9)
		draw_line(Vector2(bx2, by2), Vector2(bx2 + sway_x * 0.9, by2 - 2.0), blade_col2, 1.0)


func _draw_cloud_blob(center: Vector2, rx: float, ry: float, alpha: float) -> void:
	var lobe_alpha: float = alpha * 0.45
	var col_outer := Color(0.06, 0.10, 0.18, lobe_alpha * 0.7)
	var col_inner := Color(0.06, 0.10, 0.18, lobe_alpha * 0.85)
	var lobes: Array[Vector4] = [
		Vector4(0.0, 0.0, rx, ry),
		Vector4(-rx * 0.42, ry * 0.18, rx * 0.68, ry * 0.75),
		Vector4(rx * 0.44, ry * 0.12, rx * 0.65, ry * 0.72),
		Vector4(rx * 0.08, -ry * 0.25, rx * 0.58, ry * 0.68),
	]
	for lobe: Vector4 in lobes:
		var pos := center + Vector2(lobe.x, lobe.y)
		draw_set_transform(pos, 0.0, Vector2(lobe.z, lobe.w))
		draw_circle(Vector2.ZERO, 1.0, col_outer)
		draw_set_transform(pos, 0.0, Vector2(lobe.z * 0.68, lobe.w * 0.68))
		draw_circle(Vector2.ZERO, 1.0, col_inner)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _get_farmer_frame() -> Vector2i:
	var sheet_row: int = 0
	var frame: int = 0
	if _farmer_state == FarmerState.WALKING:
		sheet_row = 0
		var step_idx: int = int(floor(_farmer_walk_phase)) % 4
		frame = step_idx
	elif _farmer_state == FarmerState.ACTING:
		var act: String = str(_active_req.get("action", ""))
		sheet_row = int(ACTION_SHEET_ROWS.get(act, 1))
		var t: float = clampf(_action_elapsed / ACTION_DURATION, 0.0, 0.999)
		frame = clampi(int(floor(t * 4.0)), 0, 3)
	return Vector2i(frame, sheet_row)


func _draw_farmer() -> void:
	var fc: Vector2i = _get_farmer_frame()
	var src := Rect2(float(fc.x) * FARMER_W, float(fc.y) * FARMER_H, FARMER_W, FARMER_H)
	var sx: float = -1.0 if farmer_facing_left else 1.0
	draw_set_transform(farmer_pos, 0.0, Vector2(sx, 1.0))
	draw_texture_rect_region(farmer_tex, Rect2(-FARMER_W * 0.5, -FARMER_H + 3.0, FARMER_W, FARMER_H), src)
	draw_set_transform_matrix(Transform2D.IDENTITY)
