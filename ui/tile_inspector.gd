class_name TileInspector
extends PanelContainer
## Micro-panel displayed at bottom in Explore mode showing soil and crop diagnostics.

signal closed

var _title_label: Label
var _soil_label: Label
var _crop_label: Label
var _thermal_label: Label


func _init() -> void:
	visible = false
	_build_ui()


func _build_ui() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.18, 0.13, 0.10, 0.96)
	sb.border_width_top = 2
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_color = Color(0.62, 0.45, 0.30, 1.0)
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	add_theme_stylebox_override("panel", sb)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	add_child(vbox)

	var header := HBoxContainer.new()
	vbox.add_child(header)

	_title_label = Label.new()
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.add_theme_font_size_override("font_size", 13)
	_title_label.add_theme_color_override("font_color", Color(0.98, 0.92, 0.76))
	header.add_child(_title_label)

	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.add_theme_font_size_override("font_size", 11)
	close_btn.pressed.connect(func():
		visible = false
		closed.emit()
	)
	header.add_child(close_btn)

	_soil_label = Label.new()
	_soil_label.add_theme_font_size_override("font_size", 12)
	_soil_label.add_theme_color_override("font_color", Color(0.84, 0.80, 0.72))
	vbox.add_child(_soil_label)

	_crop_label = Label.new()
	_crop_label.add_theme_font_size_override("font_size", 12)
	_crop_label.add_theme_color_override("font_color", Color(0.68, 0.92, 0.56))
	vbox.add_child(_crop_label)

	_thermal_label = Label.new()
	_thermal_label.add_theme_font_size_override("font_size", 12)
	_thermal_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45))
	vbox.add_child(_thermal_label)


func inspect_cell(cell: Dictionary, sim: GridSimulation, tw: TimeWeatherManager) -> void:
	if cell.is_empty():
		visible = false
		return

	var x := int(cell["x"])
	var y := int(cell["y"])
	var s_state := int(cell["soil_state"])
	var state_str := "Incolto (usa Vanga)"
	if s_state == GridSimulation.SoilState.VANGATO:
		state_str = "Vangato (usa Rastrello)"
	elif s_state == GridSimulation.SoilState.RASTRELLATO:
		state_str = "Pronto per semina"

	_title_label.text = "Zolla (%d, %d) — %s" % [x + 1, y + 1, state_str]

	var moist := int(round(float(cell["moisture"])))
	var moist_tag := "Secco"
	if moist > 82:
		moist_tag = "Ristagno!"
	elif moist >= 25:
		moist_tag = "Umido"
	var fert := int(round(float(cell["fertility"])))
	_soil_label.text = "Umidita: %d%% (%s)  |  Fertilita: %d%%" % [moist, moist_tag, fert]

	var crop: Dictionary = cell["crop"]
	if crop.is_empty():
		_crop_label.text = "Nessuna coltura piantata."
		_thermal_label.visible = false
	else:
		var def: Dictionary = sim.crops_db.get(str(crop["crop_id"]), {})
		var c_name := str(def.get("name", crop["crop_id"]))
		var target := maxf(1.0, float(def.get("growth_days", 4)))
		var acc := float(crop["growth_days_acc"])
		var pct := int(round(clampf(acc / target, 0.0, 1.0) * 100.0))
		var hp := int(round(float(crop["health"])))

		if bool(crop.get("withered", false)):
			_crop_label.text = "%s — SECCATA (tocca per pulire)" % c_name
			_crop_label.add_theme_color_override("font_color", Color(0.95, 0.45, 0.40))
		elif bool(crop.get("harvest_ready", false)):
			_crop_label.text = "%s — PRONTA AL RACCOLTO! (100%%, Salute %d%%)" % [c_name, hp]
			_crop_label.add_theme_color_override("font_color", Color(1.0, 0.90, 0.35))
		else:
			_crop_label.text = "%s — Crescita %d%% (%.1f/%.0f gg) | Salute %d%%" % [c_name, pct, acc, target, hp]
			_crop_label.add_theme_color_override("font_color", Color(0.68, 0.92, 0.56))

		var therm := sim.evaluate_crop_thermal_status(def, tw.get_weather_snapshot())
		var opt_min := int(def.get("temp", {}).get("optimal_min", 10))
		var opt_max := int(def.get("temp", {}).get("optimal_max", 24))
		_thermal_label.text = "Clima oggi: %s (Ideale %d-%d°C)" % [str(therm["label"]), opt_min, opt_max]
		var st := str(therm["status"])
		if st == "optimal":
			_thermal_label.add_theme_color_override("font_color", Color(0.65, 0.94, 0.65))
		elif st == "suboptimal":
			_thermal_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.42))
		else:
			_thermal_label.add_theme_color_override("font_color", Color(0.96, 0.46, 0.42))
		_thermal_label.visible = true

	visible = true
