extends Control
class_name SkillGraphOverlay

var node_centers: Dictionary = {}
var edges: Array[Dictionary] = []
var active_edges: Dictionary = {}


func configure(next_centers: Dictionary, next_edges: Array[Dictionary], next_active_edges: Dictionary) -> void:
	node_centers = next_centers.duplicate(true)
	edges = next_edges.duplicate(true)
	active_edges = next_active_edges.duplicate(true)
	queue_redraw()


func _draw() -> void:
	_draw_background_sparks()
	for edge_data in edges:
		var from_id := String(edge_data.get("from", ""))
		var to_id := String(edge_data.get("to", ""))
		if not node_centers.has(from_id) or not node_centers.has(to_id):
			continue

		var from_point: Vector2 = node_centers[from_id]
		var to_point: Vector2 = node_centers[to_id]
		var edge_key := "%s->%s" % [from_id, to_id]
		var state := String(active_edges.get(edge_key, "locked"))
		var line_color := Color(0.86, 0.9, 0.9, 0.76)
		var line_width := 4.0
		if state == "purchased":
			line_color = Color(1.0, 0.92, 0.18, 0.98)
			line_width = 5.0
		elif state == "available":
			line_color = Color(0.1, 0.95, 1.0, 0.92)
			line_width = 5.0

		draw_line(from_point, to_point, Color(0.0, 0.0, 0.0, 0.55), line_width + 4.0, false)
		draw_line(from_point, to_point, line_color, line_width, true)


func _draw_background_sparks() -> void:
	var points := [
		Vector2(0.06, 0.18),
		Vector2(0.18, 0.67),
		Vector2(0.28, 0.38),
		Vector2(0.43, 0.2),
		Vector2(0.56, 0.58),
		Vector2(0.72, 0.31),
		Vector2(0.86, 0.72),
		Vector2(0.94, 0.16),
	]
	for index in range(points.size()):
		var center: Vector2 = size * points[index]
		var radius := 5.0 + float(index % 3) * 2.0
		var color := Color(0.9, 0.94, 0.45, 0.18)
		draw_line(center + Vector2(-radius, 0.0), center + Vector2(radius, 0.0), color, 2.0)
		draw_line(center + Vector2(0.0, -radius), center + Vector2(0.0, radius), color, 2.0)
