extends Node2D
class_name CursorPulse

var radius := 92.0
var progress := 0.0
var flash_strength := 0.0


func configure(new_radius: float) -> void:
	radius = new_radius
	queue_redraw()


func set_progress(value: float) -> void:
	progress = clampf(value, 0.0, 1.0)
	queue_redraw()


func trigger_flash() -> void:
	flash_strength = 1.0
	queue_redraw()


func _process(delta: float) -> void:
	if flash_strength > 0.0:
		flash_strength = maxf(0.0, flash_strength - delta * 3.6)
		queue_redraw()


func _draw() -> void:
	var base_color := Color(0.70, 0.95, 0.79, 0.10)
	var rim_color := Color(0.78, 0.98, 0.84, 0.78)
	var charge_color := Color(1.0, 0.96, 0.66, 0.30)
	var core_color := Color(1.0, 0.99, 0.88, 0.90)
	var flash_color := Color(1.0, 0.98, 0.82, 0.15 + flash_strength * 0.24)
	var charge_radius := maxf(5.0, radius * progress)

	if flash_strength > 0.0:
		draw_circle(Vector2.ZERO, radius + 8.0 * flash_strength, flash_color)

	draw_circle(Vector2.ZERO, radius, base_color)
	draw_circle(Vector2.ZERO, charge_radius, charge_color)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, rim_color, 2.0, true)
	draw_circle(Vector2.ZERO, 5.0 + flash_strength * 2.0, core_color)
