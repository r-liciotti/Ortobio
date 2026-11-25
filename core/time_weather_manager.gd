class_name TimeWeatherManager
extends RefCounted
## Manages calendar (28-day seasons), real-time clock with smart pause, and daily climate.

var config: Dictionary = {}
var seasons: Array = ["primavera", "estate", "autunno", "inverno"]
var days_per_season: int = 28
var start_hour: int = 6
var end_hour: int = 24
var day_duration_seconds: float = 720.0

var year: int = 1
var season_index: int = 0
var day_in_season: int = 1
var minutes_of_day: float = 360.0 # 06:00

var weather_type: String = "sole"
var temp_min: float = 10.0
var temp_max: float = 19.0
var temp_avg: float = 14.5

var _rng := RandomNumberGenerator.new()


func _init(balance_config: Dictionary = {}, seed_val: int = 0) -> void:
	config = balance_config
	var cal: Dictionary = config.get("calendar", {})
	seasons = cal.get("seasons", seasons)
	days_per_season = int(cal.get("days_per_season", 28))
	start_hour = int(cal.get("start_hour", 6))
	end_hour = int(cal.get("end_hour", 24))
	day_duration_seconds = float(cal.get("day_duration_seconds", 720.0))
	minutes_of_day = float(start_hour * 60)
	if seed_val != 0:
		_rng.seed = seed_val
	else:
		_rng.randomize()
	_roll_weather_for_today()


func get_season_id() -> String:
	return str(seasons[season_index % seasons.size()])


func get_season_short() -> String:
	match get_season_id():
		"primavera": return "Prim."
		"estate": return "Est."
		"autunno": return "Aut."
		"inverno": return "Inv."
	return get_season_id()


func get_season_label() -> String:
	var climate: Dictionary = config.get("climate", {})
	var s_data: Dictionary = climate.get(get_season_id(), {})
	return str(s_data.get("label", get_season_id().capitalize()))


func tick(delta: float, is_active: bool) -> bool:
	## Advances the in-game clock only when active (smart pause).
	## Returns true if the day reached midnight (end_hour).
	if not is_active:
		return false
	var active_minutes := float((end_hour - start_hour) * 60)
	var mins_per_sec := active_minutes / maxf(1.0, day_duration_seconds)
	minutes_of_day += delta * mins_per_sec
	if minutes_of_day >= float(end_hour * 60):
		minutes_of_day = float(end_hour * 60)
		return true
	return false


func advance_day() -> Dictionary:
	## Moves to next morning, handles season/year rollover, and rolls new weather.
	day_in_season += 1
	if day_in_season > days_per_season:
		day_in_season = 1
		season_index += 1
		if season_index >= seasons.size():
			season_index = 0
			year += 1
	minutes_of_day = float(start_hour * 60)
	_roll_weather_for_today()
	return get_weather_snapshot()


func cycle_season_for_test() -> Dictionary:
	## v0.1 helper: switches directly to the next season so off-season crops can be tested.
	season_index = (season_index + 1) % seasons.size()
	if season_index == 0:
		year += 1
	day_in_season = 1
	minutes_of_day = float(start_hour * 60)
	_roll_weather_for_today()
	return get_weather_snapshot()


func set_weather_override(w_type: String, t_min: float, t_max: float) -> void:
	## Deterministic override useful for unit tests.
	weather_type = w_type
	temp_min = t_min
	temp_max = t_max
	temp_avg = (t_min + t_max) * 0.5


func get_weather_snapshot() -> Dictionary:
	return {
		"year": year,
		"season": get_season_id(),
		"season_label": get_season_label(),
		"day": day_in_season,
		"weather_type": weather_type,
		"temp_min": temp_min,
		"temp_max": temp_max,
		"temp_avg": temp_avg,
	}


func get_formatted_time() -> String:
	var total_mins := int(minutes_of_day)
	var hh := (total_mins / 60) % 24
	var mm := (total_mins % 60) / 10 * 10
	return "%02d:%02d" % [hh, mm]


func get_weather_icon_text() -> String:
	match weather_type:
		"pioggia": return "Pioggia"
		"neve": return "Neve"
		"gelata": return "Gelata"
		"ondata_calore": return "Caldo!"
		"nuvoloso": return "Nuvoloso"
		_: return "Sole"


func get_current_temperature() -> float:
	## Interpolates between temp_min (06:00) and temp_max (15:00), cooling toward evening.
	var hour := minutes_of_day / 60.0
	var phase := clampf((hour - 6.0) / 9.0, 0.0, 1.0)
	if hour > 15.0:
		phase = clampf(1.0 - (hour - 15.0) / 11.0 * 0.65, 0.25, 1.0)
	return roundf(lerpf(temp_min, temp_max, phase))


func get_season_tint() -> Color:
	var climate: Dictionary = config.get("climate", {})
	var s_data: Dictionary = climate.get(get_season_id(), {})
	var hex := str(s_data.get("tint", "#ffffff"))
	return Color.from_string(hex, Color.WHITE)


func get_daylight_modulate() -> Color:
	var base := get_season_tint()
	var hour := minutes_of_day / 60.0
	var time_tint := Color.WHITE
	if hour < 8.0:
		var t := clampf((hour - 6.0) / 2.0, 0.0, 1.0)
		time_tint = Color(0.88, 0.90, 0.98).lerp(Color.WHITE, t)
	elif hour >= 18.0:
		var t := clampf((hour - 18.0) / 6.0, 0.0, 1.0)
		if hour < 20.5:
			var s := clampf((hour - 18.0) / 2.5, 0.0, 1.0)
			time_tint = Color.WHITE.lerp(Color(1.0, 0.84, 0.72), s)
		else:
			var n := clampf((hour - 20.5) / 3.5, 0.0, 1.0)
			time_tint = Color(1.0, 0.84, 0.72).lerp(Color(0.62, 0.68, 0.88), n)
	if weather_type == "pioggia" or weather_type == "nuvoloso":
		time_tint = time_tint.lerp(Color(0.84, 0.88, 0.94), 0.35)
	return base * time_tint


func _roll_weather_for_today() -> void:
	var season_id := get_season_id()
	var climate: Dictionary = config.get("climate", {})
	var s_data: Dictionary = climate.get(season_id, {
		"day_min": 14, "day_max": 22, "night_min": 6, "night_max": 12,
		"rain_chance": 0.25, "frost_chance": 0.0, "heatwave_chance": 0.0, "snow_chance": 0.0
	})

	temp_max = roundf(_rng.randf_range(float(s_data.get("day_min", 14)), float(s_data.get("day_max", 22))))
	temp_min = roundf(_rng.randf_range(float(s_data.get("night_min", 6)), float(s_data.get("night_max", 12))))

	var roll := _rng.randf()
	var p_snow := float(s_data.get("snow_chance", 0.0))
	var p_rain := float(s_data.get("rain_chance", 0.2))
	var p_heat := float(s_data.get("heatwave_chance", 0.0))
	var p_frost := float(s_data.get("frost_chance", 0.0))

	if roll < p_snow:
		weather_type = "neve"
		temp_min = minf(temp_min, -1.0)
		temp_max = minf(temp_max, 3.0)
	elif roll < p_snow + p_rain:
		weather_type = "pioggia"
	elif roll < p_snow + p_rain + p_heat:
		weather_type = "ondata_calore"
		temp_max = maxf(temp_max, 39.0)
		temp_min = maxf(temp_min, 21.0)
	elif roll < p_snow + p_rain + p_heat + p_frost:
		weather_type = "gelata"
		temp_min = minf(temp_min, 0.0)
	elif _rng.randf() < 0.25:
		weather_type = "nuvoloso"
	else:
		weather_type = "sole"

	if temp_max < temp_min + 2.0:
		temp_max = temp_min + 2.0
	temp_avg = (temp_min + temp_max) * 0.5
