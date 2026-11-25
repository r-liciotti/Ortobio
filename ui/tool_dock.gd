class_name ToolDock
extends PanelContainer
## Bottom thumb-zone dock for switching Explore/Work mode and selecting tools or seeds.

signal mode_changed(mode: String)
signal tool_selected(tool_id: String)
signal harvest_all_pressed

var current_mode: String = "explore"
var current_tool: String = "spade"

var _explore_btn: Button
var _work_btn: Button
var _explore_panel: HBoxContainer
var _explore_hint: Label
var _harvest_all_btn: Button
var _tools_scroll: ScrollContainer
var _tool_buttons: Dictionary = {}

const TOOL_ITEMS := [
	{"id": "spade", "label": "Vanga", "icon": "res://assets/ui/icon_spade.png"},
	{"id": "rake", "label": "Rastrello", "icon": "res://assets/ui/icon_rake.png"},
	{"id": "water", "label": "Acqua", "icon": "res://assets/ui/icon_water.png"},
	{"id": "seed:ravanello", "label": "Ravanello", "icon": "res://assets/ui/icon_ravanello.png"},
	{"id": "seed:pomodoro", "label": "Pomodoro", "icon": "res://assets/ui/icon_pomodoro.png"},
	{"id": "seed:cavolo_verza", "label": "Cavolo", "icon": "res://assets/ui/icon_cavolo_verza.png"},
]


func _init() -> void:
	_build_ui()


func _build_ui() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.20, 0.14, 0.11, 0.96)
	sb.border_width_top = 2
	sb.border_color = Color(0.45, 0.31, 0.22, 1.0)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 6
	sb.content_margin_bottom = 8
	add_theme_stylebox_override("panel", sb)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	add_child(vbox)

	# Mode switcher row
	var mode_row := HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", 6)
	vbox.add_child(mode_row)

	_explore_btn = _make_mode_button("Esplora / Raccogli", "explore")
	_work_btn = _make_mode_button("Lavora / Semina", "work")
	mode_row.add_child(_explore_btn)
	mode_row.add_child(_work_btn)

	# Explore contextual bar (visible in Explore mode)
	_explore_panel = HBoxContainer.new()
	_explore_panel.custom_minimum_size = Vector2(0, 56)
	_explore_panel.add_theme_constant_override("separation", 8)
	vbox.add_child(_explore_panel)

	_explore_hint = Label.new()
	_explore_hint.text = "Scorri il campo · Tocca una zolla\nper ispezionare o raccogliere"
	_explore_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_explore_hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_explore_hint.add_theme_font_size_override("font_size", 11)
	_explore_hint.add_theme_color_override("font_color", Color(0.88, 0.84, 0.74))
	_explore_panel.add_child(_explore_hint)

	_harvest_all_btn = Button.new()
	_harvest_all_btn.text = "Raccogli (0)"
	_harvest_all_btn.custom_minimum_size = Vector2(104, 40)
	_harvest_all_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_harvest_all_btn.focus_mode = Control.FOCUS_NONE
	_harvest_all_btn.add_theme_font_size_override("font_size", 12)
	_harvest_all_btn.pressed.connect(func(): harvest_all_pressed.emit())
	_explore_panel.add_child(_harvest_all_btn)

	# Tools & Seeds row (visible in Work mode)
	_tools_scroll = ScrollContainer.new()
	_tools_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tools_scroll.custom_minimum_size = Vector2(0, 56)
	vbox.add_child(_tools_scroll)

	var tools_row := HBoxContainer.new()
	tools_row.add_theme_constant_override("separation", 5)
	tools_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tools_scroll.add_child(tools_row)

	for item in TOOL_ITEMS:
		var tid := str(item["id"])
		var btn := _make_tool_button(tid, str(item["label"]), str(item["icon"]))
		tools_row.add_child(btn)
		_tool_buttons[tid] = btn

	_refresh_styles()


func _make_mode_button(txt: String, mode_id: String) -> Button:
	var btn := Button.new()
	btn.text = txt
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, 32)
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 12)
	btn.pressed.connect(func(): set_mode(mode_id))
	return btn


func _make_tool_button(tid: String, label_txt: String, icon_path: String) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(54, 52)
	btn.focus_mode = Control.FOCUS_NONE

	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(vb)

	var tex_rect := TextureRect.new()
	tex_rect.texture = load(icon_path)
	tex_rect.custom_minimum_size = Vector2(28, 28)
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tex_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(tex_rect)

	var lbl := Label.new()
	lbl.text = label_txt
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", Color(0.94, 0.90, 0.80))
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(lbl)

	btn.pressed.connect(func():
		current_tool = tid
		if current_mode != "work":
			current_mode = "work"
			mode_changed.emit(current_mode)
		tool_selected.emit(current_tool)
		_refresh_styles()
	)
	return btn


func set_mode(mode_id: String) -> void:
	if current_mode == mode_id:
		return
	current_mode = mode_id
	_refresh_styles()
	mode_changed.emit(current_mode)


func update_ready_count(count: int) -> void:
	if _harvest_all_btn == null:
		return
	_harvest_all_btn.text = "Raccogli (%d)" % count
	_harvest_all_btn.disabled = (count <= 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.76, 0.56, 0.16) if count > 0 else Color(0.24, 0.19, 0.15)
	sb.border_width_bottom = 2
	sb.border_color = Color(0.98, 0.84, 0.36) if count > 0 else Color(0.34, 0.26, 0.20)
	sb.corner_radius_top_left = 5
	sb.corner_radius_top_right = 5
	sb.corner_radius_bottom_left = 5
	sb.corner_radius_bottom_right = 5
	_apply_btn_style(_harvest_all_btn, sb)


func _refresh_styles() -> void:
	if _explore_panel != null and _tools_scroll != null:
		_explore_panel.visible = (current_mode == "explore")
		_tools_scroll.visible = (current_mode == "work")

	var active_mode_sb := StyleBoxFlat.new()
	active_mode_sb.bg_color = Color(0.32, 0.56, 0.28)
	active_mode_sb.border_width_bottom = 2
	active_mode_sb.border_color = Color(0.76, 0.90, 0.52)
	active_mode_sb.corner_radius_top_left = 5
	active_mode_sb.corner_radius_top_right = 5
	active_mode_sb.corner_radius_bottom_left = 5
	active_mode_sb.corner_radius_bottom_right = 5

	var idle_mode_sb := StyleBoxFlat.new()
	idle_mode_sb.bg_color = Color(0.28, 0.21, 0.16)
	idle_mode_sb.corner_radius_top_left = 5
	idle_mode_sb.corner_radius_top_right = 5
	idle_mode_sb.corner_radius_bottom_left = 5
	idle_mode_sb.corner_radius_bottom_right = 5

	_apply_btn_style(_explore_btn, active_mode_sb if current_mode == "explore" else idle_mode_sb)
	_apply_btn_style(_work_btn, active_mode_sb if current_mode == "work" else idle_mode_sb)

	for tid in _tool_buttons.keys():
		var tid_str: String = str(tid)
		var btn: Button = _tool_buttons[tid]
		var is_sel: bool = (current_mode == "work" and current_tool == tid_str)
		var t_sb := StyleBoxFlat.new()
		t_sb.bg_color = Color(0.46, 0.34, 0.20) if is_sel else Color(0.26, 0.19, 0.14)
		t_sb.border_width_top = 2 if is_sel else 1
		t_sb.border_width_bottom = 2 if is_sel else 1
		t_sb.border_width_left = 2 if is_sel else 1
		t_sb.border_width_right = 2 if is_sel else 1
		t_sb.border_color = Color(0.95, 0.80, 0.35) if is_sel else Color(0.38, 0.28, 0.20)
		t_sb.corner_radius_top_left = 5
		t_sb.corner_radius_top_right = 5
		t_sb.corner_radius_bottom_left = 5
		t_sb.corner_radius_bottom_right = 5
		_apply_btn_style(btn, t_sb)


func _apply_btn_style(btn: Button, sb: StyleBoxFlat) -> void:
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb)
	btn.add_theme_stylebox_override("pressed", sb)
