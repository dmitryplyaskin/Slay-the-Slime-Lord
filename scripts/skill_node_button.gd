extends Button
class_name SkillNodeButton

enum VisualState {
	LOCKED,
	AVAILABLE,
	PURCHASED,
}

var skill_id := ""
var icon_key := ""
var visual_state := VisualState.LOCKED


func _ready() -> void:
	flat = true
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_PASS
	text = ""
	var empty := StyleBoxEmpty.new()
	add_theme_stylebox_override("normal", empty)
	add_theme_stylebox_override("hover", empty)
	add_theme_stylebox_override("pressed", empty)
	add_theme_stylebox_override("disabled", empty)


func configure(next_skill_id: String, next_icon_key: String) -> void:
	skill_id = next_skill_id
	icon_key = next_icon_key
	queue_redraw()


func set_visual_state(next_state: int) -> void:
	visual_state = next_state
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var border := _border_color()
	var fill := _fill_color()
	var inner := rect.grow(-8.0)
	var icon_rect := rect.grow(-17.0)

	draw_rect(rect, Color(0.0, 0.0, 0.0, 0.8), true)
	draw_rect(rect, border, false, 6.0)
	draw_rect(rect.grow(-6.0), border.darkened(0.22), false, 2.0)
	draw_rect(inner, fill, true)
	draw_rect(inner, Color(0.0, 0.0, 0.0, 0.9), false, 2.0)
	_draw_icon(icon_rect, _icon_color())

	if is_hovered() and not disabled:
		draw_rect(rect.grow(4.0), Color(1.0, 0.96, 0.54, 0.72), false, 3.0)


func _border_color() -> Color:
	match visual_state:
		VisualState.PURCHASED:
			return Color(0.12, 0.95, 0.16, 1.0)
		VisualState.AVAILABLE:
			return Color(0.98, 0.88, 0.0, 1.0)
		_:
			return Color(0.95, 0.22, 0.13, 1.0)


func _fill_color() -> Color:
	match visual_state:
		VisualState.PURCHASED:
			return Color(0.02, 0.12, 0.04, 0.98)
		VisualState.AVAILABLE:
			return Color(0.08, 0.08, 0.03, 0.98)
		_:
			return Color(0.12, 0.035, 0.02, 0.98)


func _icon_color() -> Color:
	match visual_state:
		VisualState.PURCHASED:
			return Color(0.18, 1.0, 0.38, 1.0)
		VisualState.AVAILABLE:
			return Color(0.1, 0.96, 1.0, 1.0)
		_:
			return Color(1.0, 0.34, 0.22, 1.0)


func _draw_icon(icon_rect: Rect2, color: Color) -> void:
	match icon_key:
		"acid_touch":
			_draw_drop(icon_rect, color)
		"focus_lens":
			_draw_lens(icon_rect, color)
		"long_sweep":
			_draw_slashes(icon_rect, color)
		"greedy_gloves":
			_draw_gem(icon_rect, color)
		"rich_vein":
			_draw_gem(icon_rect, color)
			draw_line(icon_rect.position + Vector2(icon_rect.size.x * 0.62, icon_rect.size.y * 0.18), icon_rect.position + Vector2(icon_rect.size.x * 0.84, icon_rect.size.y * 0.18), color, 3.0)
			draw_line(icon_rect.position + Vector2(icon_rect.size.x * 0.73, icon_rect.size.y * 0.08), icon_rect.position + Vector2(icon_rect.size.x * 0.73, icon_rect.size.y * 0.29), color, 3.0)
		"swarm_call":
			_draw_slime(icon_rect, color)
		"overcharge":
			_draw_bolt(icon_rect, color)
		"boss_hunter":
			_draw_sword(icon_rect, color)
		_:
			_draw_gem(icon_rect, color)


func _draw_drop(rect: Rect2, color: Color) -> void:
	var c := rect.get_center()
	var points := PackedVector2Array([
		c + Vector2(0.0, -rect.size.y * 0.38),
		c + Vector2(rect.size.x * 0.28, 0.0),
		c + Vector2(rect.size.x * 0.18, rect.size.y * 0.31),
		c + Vector2(-rect.size.x * 0.18, rect.size.y * 0.31),
		c + Vector2(-rect.size.x * 0.28, 0.0),
	])
	draw_colored_polygon(points, color)
	draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[3], points[4], points[0]]), color.lightened(0.45), 2.0)


func _draw_lens(rect: Rect2, color: Color) -> void:
	var c := rect.get_center()
	draw_arc(c, rect.size.x * 0.33, 0.0, TAU, 24, color, 4.0)
	draw_circle(c, rect.size.x * 0.1, color)
	draw_line(c + Vector2(rect.size.x * 0.22, rect.size.y * 0.22), c + Vector2(rect.size.x * 0.39, rect.size.y * 0.39), color, 4.0)


func _draw_slashes(rect: Rect2, color: Color) -> void:
	for index in range(3):
		var offset := float(index) * rect.size.x * 0.18
		draw_line(rect.position + Vector2(rect.size.x * 0.18 + offset, rect.size.y * 0.72), rect.position + Vector2(rect.size.x * 0.44 + offset, rect.size.y * 0.28), color, 5.0)


func _draw_gem(rect: Rect2, color: Color) -> void:
	var c := rect.get_center()
	var points := PackedVector2Array([
		c + Vector2(0.0, -rect.size.y * 0.34),
		c + Vector2(rect.size.x * 0.32, -rect.size.y * 0.03),
		c + Vector2(0.0, rect.size.y * 0.36),
		c + Vector2(-rect.size.x * 0.32, -rect.size.y * 0.03),
	])
	draw_colored_polygon(points, color)
	draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[3], points[0]]), color.lightened(0.35), 3.0)


func _draw_slime(rect: Rect2, color: Color) -> void:
	var c := rect.get_center()
	draw_circle(c + Vector2(0.0, rect.size.y * 0.05), rect.size.x * 0.27, color)
	draw_circle(c + Vector2(-rect.size.x * 0.15, -rect.size.y * 0.08), rect.size.x * 0.15, color)
	draw_circle(c + Vector2(rect.size.x * 0.15, -rect.size.y * 0.08), rect.size.x * 0.15, color)
	draw_circle(c + Vector2(-rect.size.x * 0.09, 0.0), 3.0, Color.BLACK)
	draw_circle(c + Vector2(rect.size.x * 0.1, 0.0), 3.0, Color.BLACK)


func _draw_bolt(rect: Rect2, color: Color) -> void:
	var p := rect.position
	var s := rect.size
	var points := PackedVector2Array([
		p + Vector2(s.x * 0.54, s.y * 0.02),
		p + Vector2(s.x * 0.24, s.y * 0.5),
		p + Vector2(s.x * 0.5, s.y * 0.5),
		p + Vector2(s.x * 0.34, s.y * 0.98),
		p + Vector2(s.x * 0.78, s.y * 0.38),
		p + Vector2(s.x * 0.52, s.y * 0.38),
	])
	draw_colored_polygon(points, color)


func _draw_sword(rect: Rect2, color: Color) -> void:
	var p := rect.position
	var s := rect.size
	draw_line(p + Vector2(s.x * 0.28, s.y * 0.78), p + Vector2(s.x * 0.75, s.y * 0.22), color, 6.0)
	draw_line(p + Vector2(s.x * 0.2, s.y * 0.68), p + Vector2(s.x * 0.43, s.y * 0.91), color, 4.0)
	draw_circle(p + Vector2(s.x * 0.27, s.y * 0.78), 5.0, color)
