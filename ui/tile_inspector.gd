class_name TileInspector
extends PanelContainer
## Micro-panel displayed at bottom in Explore mode showing soil and crop diagnostics.

signal closed

var _title_label: Label
var _soil_label: Label
var _npk_hidden_label: Label
var _npk_bars_box: VBoxContainer
var _npk_n_bar: ProgressBar
var _npk_n_label: Label
var _npk_p_bar: ProgressBar
var _npk_p_label: Label
var _npk_k_bar: ProgressBar
var _npk_k_label: Label
var _npk_tip_label: Label
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
	_soil_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_soil_label)

	_npk_hidden_label = Label.new()
	_npk_hidden_label.text = "Nutrienti N-P-K: ??? (usa la Sonda per analizzare)"
	_npk_hidden_label.add_theme_font_size_override("font_size", 11)
	_npk_hidden_label.add_theme_color_override("font_color", Color(0.68, 0.80, 0.86))
	_npk_hidden_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_npk_hidden_label)

	_npk_bars_box = VBoxContainer.new()
	_npk_bars_box.add_theme_constant_override("separation", 2)
	vbox.add_child(_npk_bars_box)

	var bars_row := HBoxContainer.new()
	bars_row.add_theme_constant_override("separation", 6)
	_npk_bars_box.add_child(bars_row)

	var n_ui: Dictionary = _make_npk_bar_item("N 80", Color(0.32, 0.78, 0.36))
	_npk_n_label = n_ui["label"] as Label
	_npk_n_bar = n_ui["bar"] as ProgressBar
	bars_row.add_child(n_ui["box"] as HBoxContainer)

	var p_ui: Dictionary = _make_npk_bar_item("P 80", Color(0.92, 0.68, 0.22))
	_npk_p_label = p_ui["label"] as Label
	_npk_p_bar = p_ui["bar"] as ProgressBar
	bars_row.add_child(p_ui["box"] as HBoxContainer)

	var k_ui: Dictionary = _make_npk_bar_item("K 80", Color(0.84, 0.42, 0.68))
	_npk_k_label = k_ui["label"] as Label
	_npk_k_bar = k_ui["bar"] as ProgressBar
	bars_row.add_child(k_ui["box"] as HBoxContainer)

	_npk_tip_label = Label.new()
	_npk_tip_label.add_theme_font_size_override("font_size", 11)
	_npk_tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_npk_bars_box.add_child(_npk_tip_label)

	_crop_label = Label.new()
	_crop_label.add_theme_font_size_override("font_size", 12)
	_crop_label.add_theme_color_override("font_color", Color(0.68, 0.92, 0.56))
	_crop_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_crop_label)

	_thermal_label = Label.new()
	_thermal_label.add_theme_font_size_override("font_size", 12)
	_thermal_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45))
	_thermal_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_thermal_label)


func _make_npk_bar_item(initial_txt: String, fill_color: Color) -> Dictionary:
	var item_box := HBoxContainer.new()
	item_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_box.add_theme_constant_override("separation", 4)

	var lbl := Label.new()
	lbl.text = initial_txt
	lbl.custom_minimum_size = Vector2(34, 0)
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", fill_color.lightened(0.32))
	item_box.add_child(lbl)

	var bar := ProgressBar.new()
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.custom_minimum_size = Vector2(22, 9)
	bar.max_value = 100.0
	bar.value = 80.0
	bar.show_percentage = false

	var bg_sb := StyleBoxFlat.new()
	bg_sb.bg_color = Color(0.11, 0.08, 0.07)
	bg_sb.corner_radius_top_left = 2
	bg_sb.corner_radius_top_right = 2
	bg_sb.corner_radius_bottom_left = 2
	bg_sb.corner_radius_bottom_right = 2
	bar.add_theme_stylebox_override("background", bg_sb)

	var fill_sb := StyleBoxFlat.new()
	fill_sb.bg_color = fill_color
	fill_sb.corner_radius_top_left = 2
	fill_sb.corner_radius_top_right = 2
	fill_sb.corner_radius_bottom_left = 2
	fill_sb.corner_radius_bottom_right = 2
	bar.add_theme_stylebox_override("fill", fill_sb)
	item_box.add_child(bar)

	return {"box": item_box, "label": lbl, "bar": bar}


func inspect_cell(cell: Dictionary, sim: GridSimulation, tw: TimeWeatherManager) -> void:
	if cell.is_empty():
		visible = false
		return

	var x: int = int(cell["x"])
	var y: int = int(cell["y"])
	var s_state: int = int(cell["soil_state"])
	var state_str: String = "Incolto (usa Vanga)"
	if s_state == GridSimulation.SoilState.VANGATO:
		state_str = "Vangato (usa Rastrello)"
	elif s_state == GridSimulation.SoilState.RASTRELLATO:
		state_str = "Pronto per semina"

	_title_label.text = "Zolla (%d, %d) — %s" % [x + 1, y + 1, state_str]

	var moist: int = int(round(float(cell["moisture"])))
	var moist_tag: String = "Secco"
	if moist > 82:
		moist_tag = "Ristagno!"
	elif moist >= 25:
		moist_tag = "Umido"
	var fert: int = int(round(float(cell["fertility"])))
	_soil_label.text = "Umidita: %d%% (%s)  |  Fertilita: %d%%" % [moist, moist_tag, fert]
	if bool(cell.get("fertilized", false)):
		_soil_label.text += " · Concimata"

	if s_state == GridSimulation.SoilState.INCOLTO:
		_npk_hidden_label.visible = false
		_npk_bars_box.visible = false
	elif not bool(cell.get("npk_analyzed", false)):
		_npk_hidden_label.visible = true
		_npk_bars_box.visible = false
	else:
		_npk_hidden_label.visible = false
		_npk_bars_box.visible = true
		var n_f: float = float(cell.get("n", 80.0))
		var p_f: float = float(cell.get("p", 80.0))
		var k_f: float = float(cell.get("k", 80.0))
		var n_i: int = int(round(n_f))
		var p_i: int = int(round(p_f))
		var k_i: int = int(round(k_f))
		_npk_n_label.text = "N %d" % n_i
		_npk_n_bar.value = n_f
		_npk_p_label.text = "P %d" % p_i
		_npk_p_bar.value = p_f
		_npk_k_label.text = "K %d" % k_i
		_npk_k_bar.value = k_f

		if n_f < 45.0 or p_f < 45.0 or k_f < 45.0:
			if n_f <= p_f and n_f <= k_f:
				_npk_tip_label.text = "Azoto basso -> semina Piselli/Trifoglio o usa Compost"
			elif p_f <= k_f:
				_npk_tip_label.text = "Fosforo basso -> usa Compost o Trifoglio"
			else:
				_npk_tip_label.text = "Potassio basso -> usa Compost o ruota coltura"
			_npk_tip_label.add_theme_color_override("font_color", Color(0.98, 0.72, 0.36))
			_npk_tip_label.visible = true
		elif n_f >= 65.0 and p_f >= 65.0 and k_f >= 65.0:
			_npk_tip_label.text = "Suolo equilibrato: produttivita alta!"
			_npk_tip_label.add_theme_color_override("font_color", Color(0.62, 0.92, 0.56))
			_npk_tip_label.visible = true
		else:
			_npk_tip_label.visible = false

	var crop: Dictionary = cell["crop"]
	if crop.is_empty():
		_crop_label.text = "Nessuna coltura piantata."
		_crop_label.add_theme_color_override("font_color", Color(0.68, 0.92, 0.56))
		_thermal_label.visible = false
	else:
		var def: Dictionary = sim.crops_db.get(str(crop["crop_id"]), {})
		var c_name: String = str(def.get("name", crop["crop_id"]))
		var target: float = maxf(1.0, float(def.get("growth_days", 4)))
		var acc: float = float(crop["growth_days_acc"])
		var pct: int = int(round(clampf(acc / target, 0.0, 1.0) * 100.0))
		var hp: int = int(round(float(crop["health"])))

		if bool(crop.get("withered", false)):
			_crop_label.text = "%s — SECCATA (tocca per pulire)" % c_name
			_crop_label.add_theme_color_override("font_color", Color(0.95, 0.45, 0.40))
		elif bool(crop.get("harvest_ready", false)):
			if bool(def.get("is_green_manure", false)):
				_crop_label.text = "%s — MATURO! Usa la Vanga per interrarlo (+N/P/K)" % c_name
				_crop_label.add_theme_color_override("font_color", Color(0.56, 0.96, 0.52))
			else:
				_crop_label.text = "%s — PRONTA AL RACCOLTO! (100%%, Salute %d%%)" % [c_name, hp]
				_crop_label.add_theme_color_override("font_color", Color(1.0, 0.90, 0.35))
		else:
			_crop_label.text = "%s — Crescita %d%% (%.1f/%.0f gg) | Salute %d%%" % [c_name, pct, acc, target, hp]
			_crop_label.add_theme_color_override("font_color", Color(0.68, 0.92, 0.56))

		var therm: Dictionary = sim.evaluate_crop_thermal_status(def, tw.get_weather_snapshot())
		var opt_min: int = int(def.get("temp", {}).get("optimal_min", 10))
		var opt_max: int = int(def.get("temp", {}).get("optimal_max", 24))
		_thermal_label.text = "Clima oggi: %s (Ideale %d-%d°C)" % [str(therm["label"]), opt_min, opt_max]
		var st: String = str(therm["status"])
		if st == "optimal":
			_thermal_label.add_theme_color_override("font_color", Color(0.65, 0.94, 0.65))
		elif st == "suboptimal":
			_thermal_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.42))
		else:
			_thermal_label.add_theme_color_override("font_color", Color(0.96, 0.46, 0.42))
		_thermal_label.visible = true

	visible = true
