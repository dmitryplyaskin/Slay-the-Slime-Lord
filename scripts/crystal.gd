extends Node2D
class_name Crystal

var crystal_color: Color = Color(0.8, 0.95, 1.0, 1.0)
var lifetime := 0.9
var age := 0.0
var drift := Vector2(0.0, -34.0)


func setup(color: Color) -> void:
	crystal_color = color.lightened(0.08)
	queue_redraw()


func _process(delta: float) -> void:
	age += delta
	position += drift * delta
	rotation += delta * 1.3
	scale = Vector2.ONE * lerpf(1.0, 0.35, age / lifetime)
	modulate.a = clampf(1.0 - age / lifetime, 0.0, 1.0)
	if age >= lifetime:
		queue_free()


func _draw() -> void:
	var points := PackedVector2Array([
		Vector2(0.0, -13.0),
		Vector2(9.5, 0.0),
		Vector2(0.0, 13.0),
		Vector2(-9.5, 0.0),
	])
	draw_colored_polygon(points, crystal_color)
	draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[3], points[0]]), crystal_color.lightened(0.35), 2.0, true)
