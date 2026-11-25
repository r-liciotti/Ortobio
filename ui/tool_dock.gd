class_name ToolDock
extends PanelContainer
## Bottom thumb-zone dock for switching Explore/Work mode, opening Backpack, and selecting the 6-slot Hotbar.

signal mode_changed(mode: String)
signal hotbar_slot_selected(index: int)
signal backpack_pressed
signal harvest_all_pressed
signal npk_overlay_toggled(enabled: bool)

const HOTBAR_SIZE := 6

var current_mode: String = "explore"
var selected_slot_index: int = 0
var npk_overlay_enabled: bool = false

var _explore_btn: Button
var _work_btn: Button
var _backpack_btn: Button
var _explore_panel: HBoxContainer
var _explore_hint: Label
var _npk_toggle_btn: Button
var _harvest_all_btn: Button
var _hotbar_row: HBoxContainer
var _hotbar_slots: Array[Dictionary] = []
var _icon_cache: Dictionary = {}
var _cached_inv: InventoryManager = null


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

	# Top mode row: [Esplora] [Lavora] [Zaino]
	var mode_row := HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", 6)
	vbox.add_child(mode_row)

	_explore_btn = _make_mode_button("Esplora", "explore")
	_work_btn = _make_mode_button("Lavora", "work")
	_backpack_btn = Button.new()
	_backpack_btn.text = "Zaino"
	_backpack_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_backpack_btn.custom_minimum_size = Vector2(0, 32)
	_backpack_btn.focus_mode = Control.FOCUS_NONE
	_backpack_btn.add_theme_font_size_override("font_size", 12)
	_backpack_btn.add_theme_color_override("font_color", Color(1.0, 0.94, 0.78))
	_backpack_btn.pressed.connect(func() -> void:
		backpack_pressed.emit()
	)

	mode_row.add_child(_explore_btn)
	mode_row.add_child(_work_btn)
	mode_row.add_child(_backpack_btn)

	# Explore contextual bar (visible in Explore mode)
	_explore_panel = HBoxContainer.new()
	_explore_panel.custom_minimum_size = Vector2(0, 54)
	_explore_panel.add_theme_constant_override("separation", 8)
	vbox.add_child(_explore_panel)

	_explore_hint = Label.new()
	_explore_hint.text = "Tocca prato: cammina\nZolla: ispeziona/raccogli"
	_explore_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_explore_hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_explore_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_explore_hint.add_theme_font_size_override("font_size", 11)
	_explore_hint.add_theme_color_override("font_color", Color(0.88, 0.84, 0.74))
	_explore_panel.add_child(_explore_hint)

	_npk_toggle_btn = Button.new()
	_npk_toggle_btn.text = "N-P-K"
	_npk_toggle_btn.tooltip_text = "Mostra/nascondi vista N-P-K del suolo"
	_npk_toggle_btn.custom_minimum_size = Vector2(54, 40)
	_npk_toggle_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_npk_toggle_btn.focus_mode = Control.FOCUS_NONE
	_npk_toggle_btn.add_theme_font_size_override("font_size", 11)
	_npk_toggle_btn.pressed.connect(func() -> void:
		npk_overlay_enabled = not npk_overlay_enabled
		_refresh_npk_btn_style()
		npk_overlay_toggled.emit(npk_overlay_enabled)
	)
	_explore_panel.add_child(_npk_toggle_btn)

	_harvest_all_btn = Button.new()
	_harvest_all_btn.text = "Raccogli (0)"
	_harvest_all_btn.custom_minimum_size = Vector2(104, 40)
	_harvest_all_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_harvest_all_btn.focus_mode = Control.FOCUS_NONE
	_harvest_all_btn.add_theme_font_size_override("font_size", 12)
	_harvest_all_btn.pressed.connect(func() -> void:
		harvest_all_pressed.emit()
	)
	_explore_panel.add_child(_harvest_all_btn)

	# 6-Slot Fixed Minecraft-style Hotbar (visible in Work mode)
	_hotbar_row = HBoxContainer.new()
	_hotbar_row.custom_minimum_size = Vector2(0, 54)
	_hotbar_row.add_theme_constant_override("separation", 5)
	_hotbar_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(_hotbar_row)

	for i: int in range(HOTBAR_SIZE):
		var slot_ui: Dictionary = _make_hotbar_slot(i)
		var btn: Button = slot_ui["button"] as Button
		_hotbar_row.add_child(btn)
		_hotbar_slots.append(slot_ui)

	_apply_backpack_btn_style()
	_refresh_styles()


func _load_icon_texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if _icon_cache.has(path):
		var cached: Variant = _icon_cache[path]
		if cached is Texture2D:
			return cached as Texture2D
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		var loaded: Resource = load(path)
		if loaded is Texture2D:
			tex = loaded as Texture2D
	if tex == null:
		var img: Image = Image.load_from_file(ProjectSettings.globalize_path(path))
		if img != null and not img.is_empty():
			tex = ImageTexture.create_from_image(img)
	if tex != null:
		_icon_cache[path] = tex
	return tex


func _make_mode_button(txt: String, mode_id: String) -> Button:
	var btn := Button.new()
	btn.text = txt
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, 32)
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 12)
	btn.pressed.connect(func() -> void:
		set_mode(mode_id)
	)
	return btn


func _make_hotbar_slot(index: int) -> Dictionary:
	var btn := Button.new()
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, 52)
	btn.focus_mode = Control.FOCUS_NONE
	btn.clip_contents = true

	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(overlay)

	var empty_lbl := Label.new()
	empty_lbl.text = str(index + 1)
	empty_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	empty_lbl.add_theme_font_size_override("font_size", 12)
	empty_lbl.add_theme_color_override("font_color", Color(0.56, 0.48, 0.40, 0.72))
	empty_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(empty_lbl)

	var icon := TextureRect.new()
	icon.set_anchors_preset(Control.PRESET_CENTER)
	icon.offset_left = -15
	icon.offset_top = -17
	icon.offset_right = 15
	icon.offset_bottom = 13
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(icon)

	var freshness_lbl := Label.new()
	freshness_lbl.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	freshness_lbl.offset_left = -28
	freshness_lbl.offset_top = 1
	freshness_lbl.offset_right = -3
	freshness_lbl.offset_bottom = 14
	freshness_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	freshness_lbl.add_theme_font_size_override("font_size", 9)
	freshness_lbl.add_theme_color_override("font_color", Color(0.55, 0.94, 0.96))
	freshness_lbl.add_theme_constant_override("outline_size", 3)
	freshness_lbl.add_theme_color_override("font_outline_color", Color(0.08, 0.06, 0.05, 0.95))
	freshness_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	freshness_lbl.visible = false
	overlay.add_child(freshness_lbl)

	var qty_lbl := Label.new()
	qty_lbl.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	qty_lbl.offset_left = -32
	qty_lbl.offset_top = -15
	qty_lbl.offset_right = -3
	qty_lbl.offset_bottom = -2
	qty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	qty_lbl.add_theme_font_size_override("font_size", 10)
	qty_lbl.add_theme_color_override("font_color", Color(0.98, 0.96, 0.88))
	qty_lbl.add_theme_constant_override("outline_size", 3)
	qty_lbl.add_theme_color_override("font_outline_color", Color(0.08, 0.06, 0.05, 0.95))
	qty_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	qty_lbl.visible = false
	overlay.add_child(qty_lbl)

	var broken_lbl := Label.new()
	broken_lbl.text = "ROTTO"
	broken_lbl.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	broken_lbl.offset_left = 2
	broken_lbl.offset_right = -2
	broken_lbl.offset_top = -19
	broken_lbl.offset_bottom = -7
	broken_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	broken_lbl.add_theme_font_size_override("font_size", 8)
	broken_lbl.add_theme_color_override("font_color", Color(1.0, 0.36, 0.32))
	broken_lbl.add_theme_constant_override("outline_size", 3)
	broken_lbl.add_theme_color_override("font_outline_color", Color(0.08, 0.04, 0.04, 0.95))
	broken_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	broken_lbl.visible = false
	overlay.add_child(broken_lbl)

	var dur_bar := ProgressBar.new()
	dur_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	dur_bar.offset_left = 5
	dur_bar.offset_right = -5
	dur_bar.offset_top = -7
	dur_bar.offset_bottom = -3
	dur_bar.show_percentage = false
	dur_bar.max_value = 60.0
	dur_bar.value = 60.0
	dur_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dur_bar.visible = false

	var dur_bg := StyleBoxFlat.new()
	dur_bg.bg_color = Color(0.07, 0.05, 0.05, 0.95)
	dur_bar.add_theme_stylebox_override("background", dur_bg)
	var dur_fill := StyleBoxFlat.new()
	dur_fill.bg_color = Color(0.28, 0.86, 0.36)
	dur_bar.add_theme_stylebox_override("fill", dur_fill)
	overlay.add_child(dur_bar)

	btn.pressed.connect(func() -> void:
		selected_slot_index = index
		if current_mode != "work":
			current_mode = "work"
			mode_changed.emit(current_mode)
		_refresh_styles()
		hotbar_slot_selected.emit(index)
	)

	return {
		"button": btn,
		"empty_lbl": empty_lbl,
		"icon": icon,
		"freshness_lbl": freshness_lbl,
		"qty_lbl": qty_lbl,
		"broken_lbl": broken_lbl,
		"dur_bar": dur_bar,
		"dur_fill": dur_fill,
		"occupied": false,
	}


func refresh_hotbar(inv: InventoryManager, selected_index: int) -> void:
	_cached_inv = inv
	selected_slot_index = clampi(selected_index, 0, HOTBAR_SIZE - 1)
	if inv == null:
		return

	for i: int in range(HOTBAR_SIZE):
		var ui: Dictionary = _hotbar_slots[i]
		var slot: Dictionary = inv.get_slot("hotbar", i)
		var empty_lbl: Label = ui["empty_lbl"] as Label
		var icon: TextureRect = ui["icon"] as TextureRect
		var freshness_lbl: Label = ui["freshness_lbl"] as Label
		var qty_lbl: Label = ui["qty_lbl"] as Label
		var broken_lbl: Label = ui["broken_lbl"] as Label
		var dur_bar: ProgressBar = ui["dur_bar"] as ProgressBar
		var dur_fill: StyleBoxFlat = ui["dur_fill"] as StyleBoxFlat

		if slot.is_empty():
			ui["occupied"] = false
			empty_lbl.visible = true
			icon.texture = null
			icon.modulate = Color.WHITE
			freshness_lbl.visible = false
			qty_lbl.visible = false
			broken_lbl.visible = false
			dur_bar.visible = false
			continue

		ui["occupied"] = true
		empty_lbl.visible = false

		var item_id: String = str(slot.get("item_id", ""))
		var item_def: Dictionary = inv.items_db.get(item_id, {})
		var category: String = str(item_def.get("category", ""))
		var icon_path: String = str(item_def.get("icon", ""))
		icon.texture = _load_icon_texture(icon_path)

		if category == "tool":
			qty_lbl.visible = false
			freshness_lbl.visible = false
			var max_dur: int = maxi(1, int(slot.get("max_durability", item_def.get("max_durability", 60))))
			var dur: int = clampi(int(slot.get("durability", max_dur)), 0, max_dur)
			dur_bar.max_value = float(max_dur)
			dur_bar.value = float(dur)
			dur_bar.visible = true

			var pct: float = float(dur) / float(max_dur)
			if pct < 0.20:
				dur_fill.bg_color = Color(0.94, 0.26, 0.24)
			elif pct < 0.50:
				dur_fill.bg_color = Color(0.96, 0.80, 0.22)
			else:
				dur_fill.bg_color = Color(0.28, 0.86, 0.36)

			if dur <= 0:
				icon.modulate = Color(1.0, 0.42, 0.42, 0.88)
				broken_lbl.visible = true
			else:
				icon.modulate = Color.WHITE
				broken_lbl.visible = false
		else:
			icon.modulate = Color.WHITE
			broken_lbl.visible = false
			dur_bar.visible = false
			var qty: int = int(slot.get("qty", 0))
			if qty > 0:
				qty_lbl.text = "x%d" % qty
				qty_lbl.visible = true
			else:
				qty_lbl.visible = false

			if slot.has("days_left"):
				var days_left: int = int(slot.get("days_left", 0))
				freshness_lbl.text = "%dg" % days_left
				if days_left <= 1:
					freshness_lbl.add_theme_color_override("font_color", Color(1.0, 0.46, 0.38))
				elif days_left <= 3:
					freshness_lbl.add_theme_color_override("font_color", Color(1.0, 0.84, 0.36))
				else:
					freshness_lbl.add_theme_color_override("font_color", Color(0.55, 0.94, 0.96))
				freshness_lbl.visible = true
			else:
				freshness_lbl.visible = false

	_refresh_styles()


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


func _apply_backpack_btn_style() -> void:
	if _backpack_btn == null:
		return
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.46, 0.32, 0.16)
	sb.border_width_bottom = 2
	sb.border_color = Color(0.92, 0.74, 0.32)
	sb.corner_radius_top_left = 5
	sb.corner_radius_top_right = 5
	sb.corner_radius_bottom_left = 5
	sb.corner_radius_bottom_right = 5
	_apply_btn_style(_backpack_btn, sb)


func _refresh_styles() -> void:
	if _explore_panel != null and _hotbar_row != null:
		_explore_panel.visible = (current_mode == "explore")
		_hotbar_row.visible = (current_mode == "work")

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
	_refresh_npk_btn_style()

	for i: int in range(_hotbar_slots.size()):
		var ui: Dictionary = _hotbar_slots[i]
		var btn: Button = ui["button"] as Button
		var occupied: bool = bool(ui.get("occupied", false))
		var is_sel: bool = (current_mode == "work" and i == selected_slot_index)

		var t_sb := StyleBoxFlat.new()
		if is_sel:
			t_sb.bg_color = Color(0.46, 0.34, 0.20) if occupied else Color(0.26, 0.20, 0.14)
		else:
			t_sb.bg_color = Color(0.26, 0.19, 0.14) if occupied else Color(0.15, 0.11, 0.09)
		t_sb.border_width_top = 2 if is_sel else 1
		t_sb.border_width_bottom = 2 if is_sel else 1
		t_sb.border_width_left = 2 if is_sel else 1
		t_sb.border_width_right = 2 if is_sel else 1
		t_sb.border_color = Color(0.98, 0.82, 0.32) if is_sel else Color(0.36, 0.27, 0.19)
		t_sb.corner_radius_top_left = 5
		t_sb.corner_radius_top_right = 5
		t_sb.corner_radius_bottom_left = 5
		t_sb.corner_radius_bottom_right = 5
		_apply_btn_style(btn, t_sb)


func _refresh_npk_btn_style() -> void:
	if _npk_toggle_btn == null:
		return
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.16, 0.54, 0.44) if npk_overlay_enabled else Color(0.26, 0.19, 0.14)
	sb.border_width_top = 2 if npk_overlay_enabled else 1
	sb.border_width_bottom = 2 if npk_overlay_enabled else 1
	sb.border_width_left = 2 if npk_overlay_enabled else 1
	sb.border_width_right = 2 if npk_overlay_enabled else 1
	sb.border_color = Color(0.46, 0.94, 0.74) if npk_overlay_enabled else Color(0.38, 0.28, 0.20)
	sb.corner_radius_top_left = 5
	sb.corner_radius_top_right = 5
	sb.corner_radius_bottom_left = 5
	sb.corner_radius_bottom_right = 5
	_apply_btn_style(_npk_toggle_btn, sb)
	var font_col: Color = Color(0.96, 1.0, 0.94) if npk_overlay_enabled else Color(0.84, 0.78, 0.68)
	_npk_toggle_btn.add_theme_color_override("font_color", font_col)


func _apply_btn_style(btn: Button, sb: StyleBoxFlat) -> void:
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb)
	btn.add_theme_stylebox_override("pressed", sb)
