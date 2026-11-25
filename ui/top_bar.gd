class_name TopBar
extends PanelContainer
## Top HUD bar showing Season/Day, Weather/Temp, Clock, Coins, Energy, and v0.1 quick test buttons.

signal sleep_pressed
signal season_cycle_pressed

var _season_label: Label
var _weather_label: Label
var _clock_label: Label
var _coins_label: Label
var _field_label: Label
var _energy_bar: ProgressBar
var _energy_label: Label


func _init() -> void:
	_build_ui()


func _build_ui() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.20, 0.14, 0.11, 0.94)
	style.border_width_bottom = 2
	style.border_color = Color(0.45, 0.31, 0.22, 1.0)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	add_child(vbox)

	# Row 1: Season/Day, Weather/Temp, Clock, Coins
	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 6)
	vbox.add_child(row1)

	_season_label = _make_pill_label("Prim. G.1", Color(0.95, 0.92, 0.84))
	row1.add_child(_season_label)

	_weather_label = _make_pill_label("Sole 18°C", Color(1.0, 0.90, 0.56))
	_weather_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row1.add_child(_weather_label)

	_clock_label = _make_pill_label("06:00", Color(0.82, 0.92, 0.98))
	row1.add_child(_clock_label)

	_coins_label = _make_pill_label("150 €", Color(1.0, 0.85, 0.35))
	row1.add_child(_coins_label)

	# Row 2: Field label, Energy bar, v0.1 Sleep & Season Test buttons
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 6)
	vbox.add_child(row2)

	_field_label = Label.new()
	_field_label.text = "Campo #1"
	_field_label.add_theme_font_size_override("font_size", 12)
	_field_label.add_theme_color_override("font_color", Color(0.82, 0.78, 0.70))
	row2.add_child(_field_label)

	var energy_box := HBoxContainer.new()
	energy_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	energy_box.add_theme_constant_override("separation", 4)
	row2.add_child(energy_box)

	_energy_bar = ProgressBar.new()
	_energy_bar.custom_minimum_size = Vector2(68, 14)
	_energy_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_energy_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_energy_bar.show_percentage = false
	_energy_bar.max_value = 100
	_energy_bar.value = 100

	var bg_sb := StyleBoxFlat.new()
	bg_sb.bg_color = Color(0.12, 0.09, 0.08)
	bg_sb.corner_radius_top_left = 3
	bg_sb.corner_radius_top_right = 3
	bg_sb.corner_radius_bottom_left = 3
	bg_sb.corner_radius_bottom_right = 3
	_energy_bar.add_theme_stylebox_override("background", bg_sb)

	var fill_sb := StyleBoxFlat.new()
	fill_sb.bg_color = Color(0.42, 0.76, 0.34)
	fill_sb.corner_radius_top_left = 3
	fill_sb.corner_radius_top_right = 3
	fill_sb.corner_radius_bottom_left = 3
	fill_sb.corner_radius_bottom_right = 3
	_energy_bar.add_theme_stylebox_override("fill", fill_sb)
	energy_box.add_child(_energy_bar)

	_energy_label = Label.new()
	_energy_label.text = "100/100"
	_energy_label.add_theme_font_size_override("font_size", 11)
	_energy_label.add_theme_color_override("font_color", Color(0.75, 0.94, 0.65))
	energy_box.add_child(_energy_label)

	var season_btn := _make_compact_button("Stagione >", Color(0.38, 0.28, 0.20))
	season_btn.tooltip_text = "Cambia stagione per testare colture fuori stagione"
	season_btn.pressed.connect(func(): season_cycle_pressed.emit())
	row2.add_child(season_btn)

	var sleep_btn := _make_compact_button("Dormi +1g", Color(0.24, 0.38, 0.56))
	sleep_btn.tooltip_text = "Passa al giorno successivo"
	sleep_btn.pressed.connect(func(): sleep_pressed.emit())
	row2.add_child(sleep_btn)


func _make_pill_label(txt: String, col: Color) -> Label:
	var lbl := Label.new()
	lbl.text = txt
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", col)
	return lbl


func _make_compact_button(txt: String, bg: Color) -> Button:
	var btn := Button.new()
	btn.text = txt
	btn.add_theme_font_size_override("font_size", 11)
	btn.focus_mode = Control.FOCUS_NONE
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_bottom_right = 4
	sb.content_margin_left = 7
	sb.content_margin_right = 7
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	btn.add_theme_stylebox_override("normal", sb)
	var sb_hover := sb.duplicate()
	sb_hover.bg_color = bg.lightened(0.15)
	btn.add_theme_stylebox_override("hover", sb_hover)
	btn.add_theme_stylebox_override("pressed", sb_hover)
	return btn


func update_state(tw: TimeWeatherManager, sim: GridSimulation) -> void:
	_season_label.text = "%s G.%d" % [tw.get_season_short(), tw.day_in_season]
	var t_cur := int(tw.get_current_temperature())
	var t_min := int(tw.temp_min)
	var t_max := int(tw.temp_max)
	_weather_label.text = "%s %d° (%d°/%d°)" % [tw.get_weather_icon_text(), t_cur, t_min, t_max]
	_clock_label.text = tw.get_formatted_time()
	_coins_label.text = "%d €" % sim.coins
	_field_label.text = "Campo %dx%d" % [sim.width, sim.height]
	_energy_bar.max_value = sim.max_energy
	_energy_bar.value = sim.energy
	_energy_label.text = "%d/%d" % [sim.energy, sim.max_energy]
