class_name BackpackPanel
extends PanelContainer
## Modal backpack & hotbar manager with drag-and-drop, tap-to-swap, tool repair, and v0.2b test actions.


class SlotButton extends Button:
	var owner_panel: BackpackPanel = null
	var slot_container: String = ""
	var slot_index: int = -1

	func _get_drag_data(_at_position: Vector2) -> Variant:
		if owner_panel == null:
			return null
		return owner_panel._begin_slot_drag(slot_container, slot_index, self)

	func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
		return data is Dictionary and data.has("container") and data.has("index")

	func _drop_data(_at_position: Vector2, data: Variant) -> void:
		if owner_panel != null and data is Dictionary:
			var d: Dictionary = data as Dictionary
			owner_panel._complete_slot_drop(
				str(d.get("container", "")),
				int(d.get("index", -1)),
				slot_container,
				slot_index
			)


signal closed
signal inventory_changed
signal repair_requested(container: String, index: int)
signal sell_crops_requested
signal refill_seeds_requested
signal save_requested
signal reset_requested

var _inv: InventoryManager = null
var _crops_db: Dictionary = {}
var _selected_container: String = ""
var _selected_index: int = -1

var _hotbar_slots: Array[Dictionary] = []
var _backpack_slots: Array[Dictionary] = []
var _info_title_lbl: Label
var _info_detail_lbl: Label
var _repair_btn: Button
var _icon_cache: Dictionary = {}


func _init() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()


func _build_ui() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.16, 0.11, 0.09, 0.97)
	sb.border_width_top = 2
	sb.border_width_bottom = 2
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_color = Color(0.64, 0.47, 0.30, 1.0)
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 10
	add_theme_stylebox_override("panel", sb)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	add_child(vbox)

	# Header
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	vbox.add_child(header)

	var title_lbl := Label.new()
	title_lbl.text = "Zaino & Hotbar (Trascina o tocca 2 slot)"
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_lbl.add_theme_font_size_override("font_size", 12)
	title_lbl.add_theme_color_override("font_color", Color(0.98, 0.90, 0.70))
	header.add_child(title_lbl)

	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(28, 26)
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.add_theme_font_size_override("font_size", 11)
	close_btn.pressed.connect(func() -> void:
		_clear_selection()
		visible = false
		closed.emit()
	)
	header.add_child(close_btn)

	# Section 1: Hotbar Rapida (6 slots)
	var hb_title := Label.new()
	hb_title.text = "Hotbar Rapida (6 slot)"
	hb_title.add_theme_font_size_override("font_size", 11)
	hb_title.add_theme_color_override("font_color", Color(0.86, 0.79, 0.66))
	vbox.add_child(hb_title)

	var hb_row := HBoxContainer.new()
	hb_row.add_theme_constant_override("separation", 4)
	vbox.add_child(hb_row)

	for i: int in range(InventoryManager.HOTBAR_SIZE):
		var slot_ui: Dictionary = _make_slot_ui("hotbar", i)
		hb_row.add_child(slot_ui["button"] as Button)
		_hotbar_slots.append(slot_ui)

	# Section 2: Zaino (24 slots = 6 x 4)
	var bp_title := Label.new()
	bp_title.text = "Zaino (24 slot)"
	bp_title.add_theme_font_size_override("font_size", 11)
	bp_title.add_theme_color_override("font_color", Color(0.86, 0.79, 0.66))
	vbox.add_child(bp_title)

	var bp_grid := GridContainer.new()
	bp_grid.columns = 6
	bp_grid.add_theme_constant_override("h_separation", 4)
	bp_grid.add_theme_constant_override("v_separation", 4)
	vbox.add_child(bp_grid)

	for i: int in range(InventoryManager.BACKPACK_SIZE):
		var slot_ui: Dictionary = _make_slot_ui("backpack", i)
		bp_grid.add_child(slot_ui["button"] as Button)
		_backpack_slots.append(slot_ui)

	# Info Strip
	var info_panel := PanelContainer.new()
	info_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var info_sb := StyleBoxFlat.new()
	info_sb.bg_color = Color(0.11, 0.08, 0.07, 0.94)
	info_sb.border_width_top = 1
	info_sb.border_width_bottom = 1
	info_sb.border_width_left = 1
	info_sb.border_width_right = 1
	info_sb.border_color = Color(0.36, 0.27, 0.19, 1.0)
	info_sb.corner_radius_top_left = 5
	info_sb.corner_radius_top_right = 5
	info_sb.corner_radius_bottom_left = 5
	info_sb.corner_radius_bottom_right = 5
	info_sb.content_margin_left = 8
	info_sb.content_margin_right = 8
	info_sb.content_margin_top = 6
	info_sb.content_margin_bottom = 6
	info_panel.add_theme_stylebox_override("panel", info_sb)
	vbox.add_child(info_panel)

	var info_hbox := HBoxContainer.new()
	info_hbox.add_theme_constant_override("separation", 8)
	info_panel.add_child(info_hbox)

	var info_text_vbox := VBoxContainer.new()
	info_text_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_text_vbox.add_theme_constant_override("separation", 2)
	info_hbox.add_child(info_text_vbox)

	_info_title_lbl = Label.new()
	_info_title_lbl.text = "Seleziona uno slot"
	_info_title_lbl.add_theme_font_size_override("font_size", 12)
	_info_title_lbl.add_theme_color_override("font_color", Color(0.98, 0.92, 0.74))
	info_text_vbox.add_child(_info_title_lbl)

	_info_detail_lbl = Label.new()
	_info_detail_lbl.text = "Tocca due slot per scambiare strumenti, semi o raccolti."
	_info_detail_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_detail_lbl.add_theme_font_size_override("font_size", 11)
	_info_detail_lbl.add_theme_color_override("font_color", Color(0.82, 0.78, 0.70))
	info_text_vbox.add_child(_info_detail_lbl)

	_repair_btn = _make_action_button("Ripara (15 €)", Color(0.24, 0.52, 0.62))
	_repair_btn.custom_minimum_size = Vector2(96, 34)
	_repair_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_repair_btn.visible = false
	_repair_btn.pressed.connect(func() -> void:
		if not _selected_container.is_empty() and _selected_index >= 0:
			repair_requested.emit(_selected_container, _selected_index)
	)
	info_hbox.add_child(_repair_btn)

	# Bottom Action Row
	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 5)
	vbox.add_child(action_row)

	var sell_btn: Button = _make_action_button("Vendi Raccolti", Color(0.62, 0.44, 0.16))
	sell_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sell_btn.pressed.connect(func() -> void: sell_crops_requested.emit())
	action_row.add_child(sell_btn)

	var refill_btn: Button = _make_action_button("+Semi Test", Color(0.26, 0.50, 0.28))
	refill_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	refill_btn.pressed.connect(func() -> void: refill_seeds_requested.emit())
	action_row.add_child(refill_btn)

	var save_btn: Button = _make_action_button("Salva", Color(0.26, 0.42, 0.58))
	save_btn.pressed.connect(func() -> void: save_requested.emit())
	action_row.add_child(save_btn)

	var reset_btn: Button = _make_action_button("Reset", Color(0.56, 0.24, 0.22))
	reset_btn.pressed.connect(func() -> void: reset_requested.emit())
	action_row.add_child(reset_btn)


func _make_action_button(txt: String, bg: Color) -> Button:
	var btn := Button.new()
	btn.text = txt
	btn.custom_minimum_size = Vector2(0, 32)
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 11)
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_width_bottom = 2
	sb.border_color = bg.lightened(0.25)
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_bottom_right = 4
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	btn.add_theme_stylebox_override("normal", sb)
	var sb_hover: StyleBoxFlat = sb.duplicate() as StyleBoxFlat
	sb_hover.bg_color = bg.lightened(0.14)
	btn.add_theme_stylebox_override("hover", sb_hover)
	btn.add_theme_stylebox_override("pressed", sb_hover)
	return btn


func _make_slot_ui(container: String, index: int) -> Dictionary:
	var btn := SlotButton.new()
	btn.owner_panel = self
	btn.slot_container = container
	btn.slot_index = index
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, 44)
	btn.focus_mode = Control.FOCUS_NONE
	btn.clip_contents = true

	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(overlay)

	var empty_lbl := Label.new()
	empty_lbl.text = str(index + 1) if container == "hotbar" else ""
	empty_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	empty_lbl.add_theme_font_size_override("font_size", 11)
	empty_lbl.add_theme_color_override("font_color", Color(0.54, 0.46, 0.38, 0.65))
	empty_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(empty_lbl)

	var icon := TextureRect.new()
	icon.set_anchors_preset(Control.PRESET_CENTER)
	icon.offset_left = -13
	icon.offset_top = -15
	icon.offset_right = 13
	icon.offset_bottom = 11
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(icon)

	var freshness_lbl := Label.new()
	freshness_lbl.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	freshness_lbl.offset_left = -26
	freshness_lbl.offset_top = 1
	freshness_lbl.offset_right = -2
	freshness_lbl.offset_bottom = 13
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
	qty_lbl.offset_left = -28
	qty_lbl.offset_top = -14
	qty_lbl.offset_right = -2
	qty_lbl.offset_bottom = -2
	qty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	qty_lbl.add_theme_font_size_override("font_size", 9)
	qty_lbl.add_theme_color_override("font_color", Color(0.98, 0.96, 0.88))
	qty_lbl.add_theme_constant_override("outline_size", 3)
	qty_lbl.add_theme_color_override("font_outline_color", Color(0.08, 0.06, 0.05, 0.95))
	qty_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	qty_lbl.visible = false
	overlay.add_child(qty_lbl)

	var broken_lbl := Label.new()
	broken_lbl.text = "ROTTO"
	broken_lbl.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	broken_lbl.offset_left = 1
	broken_lbl.offset_right = -1
	broken_lbl.offset_top = -18
	broken_lbl.offset_bottom = -6
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
	dur_bar.offset_left = 4
	dur_bar.offset_right = -4
	dur_bar.offset_top = -6
	dur_bar.offset_bottom = -2
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
		_on_slot_tapped(container, index)
	)

	return {
		"container": container,
		"index": index,
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


func open_panel(inv: InventoryManager, crops_db: Dictionary = {}) -> void:
	_clear_selection()
	refresh(inv, crops_db)
	visible = true


func refresh(inv: InventoryManager = null, crops_db: Dictionary = {}) -> void:
	if inv != null:
		_inv = inv
	if not crops_db.is_empty():
		_crops_db = crops_db
	if _inv == null:
		return

	for i: int in range(InventoryManager.HOTBAR_SIZE):
		_update_slot_visual(_hotbar_slots[i], "hotbar", i)
	for i: int in range(InventoryManager.BACKPACK_SIZE):
		_update_slot_visual(_backpack_slots[i], "backpack", i)

	_refresh_info_strip()


func _update_slot_visual(ui: Dictionary, container: String, index: int) -> void:
	var slot: Dictionary = _inv.get_slot(container, index)
	var btn: Button = ui["button"] as Button
	var empty_lbl: Label = ui["empty_lbl"] as Label
	var icon: TextureRect = ui["icon"] as TextureRect
	var freshness_lbl: Label = ui["freshness_lbl"] as Label
	var qty_lbl: Label = ui["qty_lbl"] as Label
	var broken_lbl: Label = ui["broken_lbl"] as Label
	var dur_bar: ProgressBar = ui["dur_bar"] as ProgressBar
	var dur_fill: StyleBoxFlat = ui["dur_fill"] as StyleBoxFlat

	var occupied: bool = not slot.is_empty()
	ui["occupied"] = occupied

	if not occupied:
		empty_lbl.visible = (container == "hotbar")
		icon.texture = null
		icon.modulate = Color.WHITE
		freshness_lbl.visible = false
		qty_lbl.visible = false
		broken_lbl.visible = false
		dur_bar.visible = false
	else:
		empty_lbl.visible = false
		var item_id: String = str(slot.get("item_id", ""))
		var item_def: Dictionary = _inv.items_db.get(item_id, {})
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

	var is_sel: bool = (_selected_container == container and _selected_index == index)
	var sb := StyleBoxFlat.new()
	if is_sel:
		sb.bg_color = Color(0.22, 0.36, 0.40) if occupied else Color(0.18, 0.28, 0.32)
		sb.border_width_top = 2
		sb.border_width_bottom = 2
		sb.border_width_left = 2
		sb.border_width_right = 2
		sb.border_color = Color(0.38, 0.94, 0.98)
	else:
		sb.bg_color = Color(0.26, 0.19, 0.14) if occupied else Color(0.14, 0.10, 0.08)
		sb.border_width_top = 1
		sb.border_width_bottom = 1
		sb.border_width_left = 1
		sb.border_width_right = 1
		sb.border_color = Color(0.42, 0.31, 0.22) if container == "hotbar" else Color(0.32, 0.23, 0.17)
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_bottom_right = 4
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb)
	btn.add_theme_stylebox_override("pressed", sb)


func _begin_slot_drag(container: String, index: int, source_btn: Button) -> Variant:
	if _inv == null:
		return null
	var slot: Dictionary = _inv.get_slot(container, index)
	if slot.is_empty():
		return null

	var item_id: String = str(slot.get("item_id", ""))
	var item_def: Dictionary = _inv.items_db.get(item_id, {})
	var icon_tex: Texture2D = _load_icon_texture(str(item_def.get("icon", "")))

	var preview_root := Control.new()
	preview_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tex_rect := TextureRect.new()
	tex_rect.texture = icon_tex
	tex_rect.custom_minimum_size = Vector2(32, 32)
	tex_rect.size = Vector2(32, 32)
	tex_rect.position = Vector2(-16, -16)
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_root.add_child(tex_rect)
	source_btn.set_drag_preview(preview_root)

	_selected_container = container
	_selected_index = index
	_refresh_info_strip()
	return {"container": container, "index": index}


func _complete_slot_drop(from_c: String, from_i: int, to_c: String, to_i: int) -> void:
	if _inv == null or from_c.is_empty() or from_i < 0:
		return
	if from_c == to_c and from_i == to_i:
		return
	_clear_selection()
	if _inv.swap_slots(from_c, from_i, to_c, to_i):
		_selected_container = to_c
		_selected_index = to_i
		refresh(_inv, _crops_db)
		inventory_changed.emit()


func _on_slot_tapped(container: String, index: int) -> void:
	if _inv == null:
		return
	if _selected_container.is_empty():
		_selected_container = container
		_selected_index = index
		refresh(_inv, _crops_db)
		return

	if _selected_container == container and _selected_index == index:
		_clear_selection()
		refresh(_inv, _crops_db)
		return

	var c1: String = _selected_container
	var i1: int = _selected_index
	_clear_selection()
	if _inv.swap_slots(c1, i1, container, index):
		refresh(_inv, _crops_db)
		inventory_changed.emit()


func _clear_selection() -> void:
	_selected_container = ""
	_selected_index = -1


func _category_label(cat: String) -> String:
	match cat:
		"tool":
			return "Attrezzo"
		"seed":
			return "Seme"
		"crop":
			return "Raccolto"
		"amendment":
			return "Ammendante"
		"material":
			return "Materiale"
		_:
			return cat.capitalize()


func _refresh_info_strip() -> void:
	if _inv == null or _selected_container.is_empty() or _selected_index < 0:
		_info_title_lbl.text = "Seleziona o trascina uno slot"
		_info_detail_lbl.text = "Trascina un oggetto tra Zaino e Hotbar (o tocca 2 slot)."
		_repair_btn.visible = false
		return

	var slot: Dictionary = _inv.get_slot(_selected_container, _selected_index)
	if slot.is_empty():
		_info_title_lbl.text = "Slot vuoto (%s #%d)" % [
			"Hotbar" if _selected_container == "hotbar" else "Zaino",
			_selected_index + 1,
		]
		_info_detail_lbl.text = "Tocca un altro slot per spostare un oggetto qui."
		_repair_btn.visible = false
		return

	var item_id: String = str(slot.get("item_id", ""))
	var item_def: Dictionary = _inv.items_db.get(item_id, {})
	var item_name: String = str(item_def.get("name", item_id))
	var category: String = str(item_def.get("category", ""))
	_info_title_lbl.text = "%s · %s" % [item_name, _category_label(category)]

	if category == "tool":
		var max_dur: int = maxi(1, int(slot.get("max_durability", item_def.get("max_durability", 60))))
		var cur_dur: int = clampi(int(slot.get("durability", max_dur)), 0, max_dur)
		var repair_cost: int = int(item_def.get("repair_cost", 15))
		if cur_dur <= 0:
			_info_detail_lbl.text = "Durabilita: 0/%d (ROTTO — ripara per usare)" % max_dur
		else:
			_info_detail_lbl.text = "Durabilita: %d/%d" % [cur_dur, max_dur]
		_repair_btn.text = "Ripara (%d €)" % repair_cost
		_repair_btn.visible = (cur_dur < max_dur)
		return

	_repair_btn.visible = false
	if slot.has("days_left"):
		var days_left: int = int(slot.get("days_left", 0))
		var sell_price: int = int(item_def.get("sell_price", 0))
		_info_detail_lbl.text = "Freschezza: %d giorni rimasti · Valore: %d €/pz" % [days_left, sell_price]
		return

	if item_def.has("description"):
		_info_detail_lbl.text = str(item_def["description"])
	elif category == "seed":
		var crop_id: String = str(item_def.get("crop_id", ""))
		var crop_def: Dictionary = _crops_db.get(crop_id, {})
		if crop_def.has("description"):
			_info_detail_lbl.text = str(crop_def["description"])
		else:
			_info_detail_lbl.text = "Seme pronto per la semina su zolla rastrellata."
	elif category == "amendment":
		_info_detail_lbl.text = "Ammendante organico: rigenera N, P e K del suolo."
	elif category == "material":
		var sell_p: int = int(item_def.get("sell_price", 2))
		_info_detail_lbl.text = "Scarti vegetali riciclabili · Valore: %d €/pz" % sell_p
	else:
		_info_detail_lbl.text = "Quantita: %d" % int(slot.get("qty", 1))
