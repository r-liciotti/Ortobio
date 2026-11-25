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
var tomorrow_weather: Dictionary = {}

var _rng := RandomNumberGenerator.new()


func _init(balance_config: Dictionary = {}, seed_val: int = 0) -> void:
	config = balance_config
	var cal: Dictionary = config.get("calendar", {})
	var raw_seasons: Variant = cal.get("seasons", seasons)
	if raw_seasons is Array:
		seasons = raw_seasons
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
	_roll_weather_for_tomorrow()


func get_season_id() -> String:
	return str(seasons[season_index % seasons.size()])


func get_season_short() -> String:
	match get_season_id():
		"primavera": return "Prim."
		"estate": return "Est."
		"autunno": return "Aut."
		"inverno": return "Inv."
	return get_season_id()


func _get_season_label_for(season_id: String) -> String:
	var climate: Dictionary = config.get("climate", {})
	var s_data: Dictionary = climate.get(season_id, {})
	return str(s_data.get("label", season_id.capitalize()))


func get_season_label() -> String:
	return _get_season_label_for(get_season_id())


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


func _get_next_calendar_date() -> Dictionary:
	var next_day: int = day_in_season + 1
	var next_season_index: int = season_index
	var next_year: int = year
	if next_day > days_per_season:
		next_day = 1
		next_season_index += 1
		if next_season_index >= seasons.size():
			next_season_index = 0
			next_year += 1
	var next_season_id: String = str(seasons[next_season_index % seasons.size()])
	return {
		"year": next_year,
		"season_index": next_season_index,
		"season": next_season_id,
		"day": next_day,
	}


func advance_day() -> Dictionary:
	## Moves to next morning, handles season/year rollover, promotes tomorrow's weather, and rolls a new forecast.
	var next_date: Dictionary = _get_next_calendar_date()
	day_in_season = int(next_date["day"])
	season_index = int(next_date["season_index"])
	year = int(next_date["year"])
	minutes_of_day = float(start_hour * 60)
	if tomorrow_weather.is_empty():
		_roll_weather_for_today()
	else:
		weather_type = str(tomorrow_weather.get("weather_type", "sole"))
		temp_min = float(tomorrow_weather.get("temp_min", 10.0))
		temp_max = float(tomorrow_weather.get("temp_max", 19.0))
		temp_avg = float(tomorrow_weather.get("temp_avg", (temp_min + temp_max) * 0.5))
	_roll_weather_for_tomorrow()
	return get_weather_snapshot()


func cycle_season_for_test() -> Dictionary:
	## v0.1 helper: switches directly to the next season so off-season crops can be tested.
	season_index = (season_index + 1) % seasons.size()
	if season_index == 0:
		year += 1
	day_in_season = 1
	minutes_of_day = float(start_hour * 60)
	_roll_weather_for_today()
	_roll_weather_for_tomorrow()
	return get_weather_snapshot()


func cycle_time_of_day_for_test() -> String:
	## Test helper: cycles smoothly through Morning (07:00), Day (13:00), Sunset (18:30), Night (22:30).
	var hour: float = minutes_of_day / 60.0
	if hour < 10.0:
		minutes_of_day = 13.0 * 60.0
		return "Giorno (13:00)"
	elif hour < 16.5:
		minutes_of_day = 18.5 * 60.0
		return "Tramonto (18:30)"
	elif hour < 21.0:
		minutes_of_day = 22.5 * 60.0
		return "Notte (22:30)"
	else:
		minutes_of_day = 7.0 * 60.0
		return "Mattina (07:00)"


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


func get_tomorrow_weather_snapshot() -> Dictionary:
	if tomorrow_weather.is_empty():
		_roll_weather_for_tomorrow()
	var next_date: Dictionary = _get_next_calendar_date()
	var next_season: String = str(tomorrow_weather.get("season", next_date["season"]))
	var t_min: float = float(tomorrow_weather.get("temp_min", 10.0))
	var t_max: float = float(tomorrow_weather.get("temp_max", 19.0))
	return {
		"year": int(tomorrow_weather.get("year", next_date["year"])),
		"season": next_season,
		"season_label": str(tomorrow_weather.get("season_label", _get_season_label_for(next_season))),
		"day": int(tomorrow_weather.get("day", next_date["day"])),
		"weather_type": str(tomorrow_weather.get("weather_type", "sole")),
		"temp_min": t_min,
		"temp_max": t_max,
		"temp_avg": float(tomorrow_weather.get("temp_avg", (t_min + t_max) * 0.5)),
	}


func to_dict() -> Dictionary:
	return {
		"year": year,
		"season_index": season_index,
		"day_in_season": day_in_season,
		"minutes_of_day": minutes_of_day,
		"weather_type": weather_type,
		"temp_min": temp_min,
		"temp_max": temp_max,
		"temp_avg": temp_avg,
		"tomorrow_weather": tomorrow_weather.duplicate(true),
	}


func from_dict(data: Dictionary) -> void:
	year = maxi(1, int(data.get("year", 1)))
	season_index = posmod(int(data.get("season_index", 0)), maxi(1, seasons.size()))
	day_in_season = clampi(int(data.get("day_in_season", 1)), 1, maxi(1, days_per_season))
	minutes_of_day = float(data.get("minutes_of_day", float(start_hour * 60)))
	weather_type = str(data.get("weather_type", "sole"))
	temp_min = float(data.get("temp_min", 10.0))
	temp_max = float(data.get("temp_max", 19.0))
	temp_avg = float(data.get("temp_avg", (temp_min + temp_max) * 0.5))
	var raw_tomorrow: Variant = data.get("tomorrow_weather", {})
	if raw_tomorrow is Dictionary:
		var tw_dict: Dictionary = raw_tomorrow
		if not tw_dict.is_empty():
			var next_date: Dictionary = _get_next_calendar_date()
			var next_season: String = str(tw_dict.get("season", next_date["season"]))
			var t_min: float = float(tw_dict.get("temp_min", 10.0))
			var t_max: float = float(tw_dict.get("temp_max", 19.0))
			tomorrow_weather = {
				"year": int(tw_dict.get("year", next_date["year"])),
				"season": next_season,
				"season_label": str(tw_dict.get("season_label", _get_season_label_for(next_season))),
				"day": int(tw_dict.get("day", next_date["day"])),
				"weather_type": str(tw_dict.get("weather_type", "sole")),
				"temp_min": t_min,
				"temp_max": t_max,
				"temp_avg": float(tw_dict.get("temp_avg", (t_min + t_max) * 0.5)),
			}
			return
	_roll_weather_for_tomorrow()


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
	var base: Color = get_season_tint()
	var hour: float = minutes_of_day / 60.0
	var time_tint: Color = Color.WHITE
	if hour < 8.5:
		var t: float = clampf((hour - 6.0) / 2.5, 0.0, 1.0)
		time_tint = Color(0.95, 0.84, 0.90).lerp(Color.WHITE, t)
	elif hour >= 17.0 and hour < 20.0:
		var s: float = clampf((hour - 17.0) / 3.0, 0.0, 1.0)
		time_tint = Color.WHITE.lerp(Color(1.0, 0.78, 0.58), s)
	elif hour >= 20.0:
		var n: float = clampf((hour - 20.0) / 3.0, 0.0, 1.0)
		time_tint = Color(1.0, 0.78, 0.58).lerp(Color(0.38, 0.44, 0.66), n)
	if weather_type == "nuvoloso" or weather_type == "pioggia" or weather_type == "neve":
		var lum: float = time_tint.r * 0.299 + time_tint.g * 0.587 + time_tint.b * 0.114
		var overcast_tint := Color(lum * 0.80, lum * 0.86, lum * 0.96)
		var strength: float = 0.34 if weather_type == "nuvoloso" else 0.44
		time_tint = time_tint.lerp(overcast_tint, strength)
	return base * time_tint


func get_night_intensity() -> float:
	var hour: float = minutes_of_day / 60.0
	if hour <= 19.0:
		return 0.0
	return smoothstep(19.0, 22.0, hour)


func get_sun_shadow_params() -> Dictionary:
	var hour: float = minutes_of_day / 60.0
	var day_t: float = clampf((hour - 6.0) / 14.0, 0.0, 1.0)
	var offset_x: float = lerpf(-5.5, 5.5, day_t)
	var scale_x: float = 1.0 + absf(day_t - 0.5) * 0.9
	var skew_x: float = lerpf(-1.05, 1.05, day_t)
	var scale_y: float = lerpf(0.46, 0.30, 1.0 - absf(day_t - 0.5) * 2.0)
	var base_alpha: float = 0.34
	match weather_type:
		"nuvoloso", "gelata":
			base_alpha = 0.16
		"pioggia", "neve":
			base_alpha = 0.08
		_:
			base_alpha = 0.34
	var alpha: float = lerpf(base_alpha, 0.06, get_night_intensity())
	return {
		"offset_x": offset_x,
		"offset_y": 1.2,
		"scale_x": scale_x,
		"skew_x": skew_x,
		"scale_y": scale_y,
		"alpha": alpha,
	}


func _roll_weather_for_season(season_id: String) -> Dictionary:
	var climate: Dictionary = config.get("climate", {})
	var s_data: Dictionary = climate.get(season_id, {
		"day_min": 14, "day_max": 22, "night_min": 6, "night_max": 12,
		"rain_chance": 0.25, "frost_chance": 0.0, "heatwave_chance": 0.0, "snow_chance": 0.0
	})

	var t_max: float = roundf(_rng.randf_range(float(s_data.get("day_min", 14)), float(s_data.get("day_max", 22))))
	var t_min: float = roundf(_rng.randf_range(float(s_data.get("night_min", 6)), float(s_data.get("night_max", 12))))

	var roll: float = _rng.randf()
	var p_snow: float = float(s_data.get("snow_chance", 0.0))
	var p_rain: float = float(s_data.get("rain_chance", 0.2))
	var p_heat: float = float(s_data.get("heatwave_chance", 0.0))
	var p_frost: float = float(s_data.get("frost_chance", 0.0))
	var w_type: String = "sole"

	if roll < p_snow:
		w_type = "neve"
		t_min = minf(t_min, -1.0)
		t_max = minf(t_max, 3.0)
	elif roll < p_snow + p_rain:
		w_type = "pioggia"
	elif roll < p_snow + p_rain + p_heat:
		w_type = "ondata_calore"
		t_max = maxf(t_max, 39.0)
		t_min = maxf(t_min, 21.0)
	elif roll < p_snow + p_rain + p_heat + p_frost:
		w_type = "gelata"
		t_min = minf(t_min, 0.0)
	elif _rng.randf() < 0.25:
		w_type = "nuvoloso"

	if t_max < t_min + 2.0:
		t_max = t_min + 2.0
	var t_avg: float = (t_min + t_max) * 0.5
	return {
		"weather_type": w_type,
		"temp_min": t_min,
		"temp_max": t_max,
		"temp_avg": t_avg,
	}


func _roll_weather_for_today() -> void:
	var rolled: Dictionary = _roll_weather_for_season(get_season_id())
	weather_type = str(rolled["weather_type"])
	temp_min = float(rolled["temp_min"])
	temp_max = float(rolled["temp_max"])
	temp_avg = float(rolled["temp_avg"])


func _roll_weather_for_tomorrow() -> void:
	var next_date: Dictionary = _get_next_calendar_date()
	var next_season: String = str(next_date["season"])
	var rolled: Dictionary = _roll_weather_for_season(next_season)
	tomorrow_weather = {
		"year": int(next_date["year"]),
		"season": next_season,
		"season_label": _get_season_label_for(next_season),
		"day": int(next_date["day"]),
		"weather_type": str(rolled["weather_type"]),
		"temp_min": float(rolled["temp_min"]),
		"temp_max": float(rolled["temp_max"]),
		"temp_avg": float(rolled["temp_avg"]),
	}
