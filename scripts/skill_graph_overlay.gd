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
	for edge_data in edges:
		var from_id := String(edge_data.get("from", ""))
		var to_id := String(edge_data.get("to", ""))
		if not node_centers.has(from_id) or not node_centers.has(to_id):
			continue

		var from_point: Vector2 = node_centers[from_id]
		var to_point: Vector2 = node_centers[to_id]
		var edge_key := "%s->%s" % [from_id, to_id]
		var is_active := bool(active_edges.get(edge_key, false))
		var line_color := Color(0.42, 0.46, 0.54, 0.75)
		var line_width := 3.0
		if is_active:
			line_color = Color(0.94, 0.9, 0.62, 0.95)
			line_width = 4.0

		draw_line(from_point, to_point, line_color, line_width, true)
