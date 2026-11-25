class_name VerticalMinimap
extends Control
## Right-edge vertical minimap & scrollbar for quick jumping across all field rows.

signal scroll_requested(normalized_y: float)

var simulation: GridSimulation
var scroll_ratio: float = 0.0
var visible_ratio: float = 0.4
var _dragging: bool = false


func _init() -> void:
	custom_minimum_size = Vector2(28, 120)
	mouse_filter = Control.MOUSE_FILTER_STOP


func set_viewport_ratios(s_ratio: float, v_ratio: float) -> void:
	scroll_ratio = clampf(s_ratio, 0.0, 1.0)
	visible_ratio = clampf(v_ratio, 0.05, 1.0)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_dragging = mb.pressed
			if _dragging:
				_emit_from_pos(mb.position.y)
				accept_event()
	elif event is InputEventMouseMotion and _dragging:
		var mm := event as InputEventMouseMotion
		_emit_from_pos(mm.position.y)
		accept_event()
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		_dragging = st.pressed
		if _dragging:
			_emit_from_pos(st.position.y)
			accept_event()
	elif event is InputEventScreenDrag and _dragging:
		var sd := event as InputEventScreenDrag
		_emit_from_pos(sd.position.y)
		accept_event()


func _emit_from_pos(local_y: float) -> void:
	var h := maxf(1.0, size.y - 8.0)
	var ratio := clampf((local_y - 4.0) / h, 0.0, 1.0)
	scroll_requested.emit(ratio)


func _draw() -> void:
	# Background rail
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.14, 0.10, 0.08, 0.92))
	draw_line(Vector2(0, 0), Vector2(0, size.y), Color(0.42, 0.30, 0.21), 1.0)

	if simulation == null:
		return

	var pad := 4.0
	var inner_w := size.x - pad * 2.0
	var inner_h := size.y - pad * 2.0
	var cell_w := inner_w / float(simulation.width)
	var cell_h := inner_h / float(simulation.height)

	for y in range(simulation.height):
		for x in range(simulation.width):
			var cell := simulation.get_cell(x, y)
			var col := Color(0.36, 0.56, 0.24) # Grass
			var state := int(cell["soil_state"])
			if state == GridSimulation.SoilState.VANGATO:
				col = Color(0.56, 0.38, 0.24)
			elif state == GridSimulation.SoilState.RASTRELLATO:
				col = Color(0.40, 0.26, 0.16)
			if float(cell["moisture"]) >= 35.0 and state != GridSimulation.SoilState.INCOLTO:
				col = col.darkened(0.25)

			var crop: Dictionary = cell["crop"]
			if not crop.is_empty():
				if bool(crop.get("withered", false)):
					col = Color(0.55, 0.45, 0.32)
				elif bool(crop.get("harvest_ready", false)):
					col = Color(0.95, 0.82, 0.26)
				else:
					col = Color(0.45, 0.80, 0.36)

			var rect := Rect2(pad + x * cell_w, pad + y * cell_h, maxf(1.5, cell_w), maxf(1.5, cell_h))
			draw_rect(rect, col)

	# Viewport indicator thumb
	var thumb_h := maxf(14.0, inner_h * visible_ratio)
	var max_top := maxf(0.0, inner_h - thumb_h)
	var thumb_y := pad + scroll_ratio * max_top
	var thumb_rect := Rect2(2.0, thumb_y, size.x - 4.0, thumb_h)
	draw_rect(thumb_rect, Color(1.0, 1.0, 1.0, 0.18), true)
	draw_rect(thumb_rect, Color(0.98, 0.92, 0.72, 0.92), false, 1.5)
