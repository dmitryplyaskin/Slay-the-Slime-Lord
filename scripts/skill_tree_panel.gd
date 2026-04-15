extends Control
class_name SkillTreePanel

signal skill_purchased(skill_id: String)
signal next_round_requested

const GRAPH_OVERLAY_SCRIPT := preload("res://scripts/skill_graph_overlay.gd")
const NODE_SIZE := Vector2(92.0, 92.0)
const GRAPH_PADDING := Vector2(36.0, 28.0)
const GRAPH_STEP := Vector2(170.0, 72.0)

var skill_defs: Dictionary = {}
var current_crystals := 0
var purchased_skills: Dictionary = {}
var current_stats: Dictionary = {}
var finished_round := 1
var buttons: Dictionary = {}
var selected_skill_id := ""
var graph_overlay
var line_edges: Array[Dictionary] = []

@onready var title_label: Label = $Backdrop/Panel/Margin/VBox/TitleLabel
@onready var summary_label: Label = $Backdrop/Panel/Margin/VBox/SummaryLabel
@onready var resources_label: Label = $Backdrop/Panel/Margin/VBox/ResourcesLabel
@onready var tree_area: Control = $Backdrop/Panel/Margin/VBox/TreeArea
@onready var hint_label: Label = $Backdrop/Panel/Margin/VBox/HintLabel
@onready var start_button: Button = $Backdrop/Panel/Margin/VBox/Footer/StartButton


func _ready() -> void:
	graph_overlay = GRAPH_OVERLAY_SCRIPT.new()
	graph_overlay.name = "GraphOverlay"
	graph_overlay.layout_mode = 1
	graph_overlay.anchors_preset = PRESET_FULL_RECT
	graph_overlay.anchor_right = 1.0
	graph_overlay.anchor_bottom = 1.0
	graph_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tree_area.add_child(graph_overlay)
	start_button.pressed.connect(_on_start_button_pressed)
	Localization.locale_changed.connect(_on_locale_changed)
	visible = false


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if not (event is InputEventMouseButton):
		return

	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return

	var mouse_position := mouse_event.position
	if start_button.get_global_rect().has_point(mouse_position) and not start_button.disabled:
		next_round_requested.emit()
		get_viewport().set_input_as_handled()
		return

	for skill_id in buttons.keys():
		var button: Button = buttons[skill_id]
		if button.disabled:
			continue
		if button.get_global_rect().has_point(mouse_position):
			skill_purchased.emit(skill_id)
			get_viewport().set_input_as_handled()
			return


func configure(definitions: Dictionary) -> void:
	skill_defs = definitions
	_build_graph()
	_refresh_view()


func show_panel(currency: int, purchased: Dictionary, stats: Dictionary, round_number: int) -> void:
	current_crystals = currency
	purchased_skills = purchased.duplicate(true)
	current_stats = stats.duplicate(true)
	finished_round = round_number
	visible = true
	_refresh_view()


func hide_panel() -> void:
	visible = false


func refresh(currency: int, purchased: Dictionary, stats: Dictionary, round_number: int) -> void:
	current_crystals = currency
	purchased_skills = purchased.duplicate(true)
	current_stats = stats.duplicate(true)
	finished_round = round_number
	_refresh_view()


func _refresh_view() -> void:
	if not is_node_ready():
		return

	title_label.text = Localization.tr_key("skill_tree.title")
	summary_label.text = Localization.tr_key("skill_tree.summary", {"round": finished_round})
	resources_label.text = Localization.tr_key("skill_tree.resources", {
		"crystals": current_crystals,
		"damage": int(round(float(current_stats.get("pulse_damage", 0.0)))),
		"interval": "%.2f" % float(current_stats.get("attack_interval", 0.0)),
		"slimes": int(current_stats.get("slime_count", 0.0)),
		"drop": int(current_stats.get("crystal_value", 0.0)),
	})
	start_button.text = Localization.tr_key("skill_tree.start_round", {"round": finished_round + 1})

	for skill_id in buttons.keys():
		_refresh_button(skill_id)

	_refresh_detail_text()
	_refresh_edges()


func _refresh_button(skill_id: String) -> void:
	var button: Button = buttons[skill_id]
	var data: Dictionary = skill_defs.get(skill_id, {})
	var title := Localization.tr_key(String(data.get("title_key", skill_id)))
	var description := Localization.tr_key(String(data.get("description_key", "")))
	var cost := int(data.get("cost", 0))
	var is_purchased := purchased_skills.has(skill_id)
	var is_unlocked := _requirements_met(skill_id)
	var can_afford := current_crystals >= cost
	var status := Localization.tr_key("skill_tree.status.cost", {"cost": cost})

	if is_purchased:
		status = Localization.tr_key("skill_tree.status.bought")
	elif not is_unlocked:
		status = Localization.tr_key("skill_tree.status.locked")
	elif not can_afford:
		status = Localization.tr_key("skill_tree.status.cannot_afford")

	button.text = String(data.get("icon_text", title.left(3)))
	button.tooltip_text = "%s\n%s" % [title, description]
	button.add_theme_font_size_override("font_size", 18)

	if is_purchased:
		button.disabled = true
		button.modulate = Color(0.74, 1.0, 0.78, 1.0)
		button.add_theme_stylebox_override("normal", _make_node_style(Color(0.15, 0.25, 0.16, 1.0), Color(0.42, 1.0, 0.55, 1.0)))
	elif is_unlocked and can_afford:
		button.disabled = false
		button.modulate = Color(1.0, 1.0, 1.0, 1.0)
		button.add_theme_stylebox_override("normal", _make_node_style(Color(0.28, 0.18, 0.08, 1.0), Color(1.0, 0.87, 0.25, 1.0)))
	else:
		button.disabled = true
		button.modulate = Color(0.72, 0.72, 0.76, 0.9)
		button.add_theme_stylebox_override("normal", _make_node_style(Color(0.10, 0.10, 0.13, 1.0), Color(0.44, 0.47, 0.54, 1.0)))

	button.add_theme_stylebox_override("hover", button.get_theme_stylebox("normal"))
	button.add_theme_stylebox_override("pressed", button.get_theme_stylebox("normal"))
	button.add_theme_stylebox_override("disabled", button.get_theme_stylebox("normal"))


func _requirements_met(skill_id: String) -> bool:
	var data: Dictionary = skill_defs.get(skill_id, {})
	var requirements: Array = data.get("requires", [])
	for required_skill in requirements:
		if not purchased_skills.has(String(required_skill)):
			return false
	return true


func _on_skill_button_pressed(skill_id: String) -> void:
	selected_skill_id = skill_id
	skill_purchased.emit(skill_id)


func _on_start_button_pressed() -> void:
	next_round_requested.emit()


func _on_locale_changed(_new_locale: String) -> void:
	_refresh_view()


func _build_graph() -> void:
	if not is_node_ready():
		return

	for child in tree_area.get_children():
		if child != graph_overlay:
			child.queue_free()
	buttons.clear()
	line_edges.clear()

	var skill_ids := skill_defs.keys()
	skill_ids.sort_custom(func(a: Variant, b: Variant) -> bool:
		var a_pos: Array = skill_defs[String(a)].get("graph_position", [0, 0])
		var b_pos: Array = skill_defs[String(b)].get("graph_position", [0, 0])
		if int(a_pos[0]) == int(b_pos[0]):
			return int(a_pos[1]) < int(b_pos[1])
		return int(a_pos[0]) < int(b_pos[0])
	)

	for skill_variant in skill_ids:
		var skill_id := String(skill_variant)
		var button := Button.new()
		button.name = "%sButton" % skill_id
		button.custom_minimum_size = NODE_SIZE
		button.size = NODE_SIZE
		button.flat = true
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.clip_text = true
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		button.pressed.connect(_on_skill_button_pressed.bind(skill_id))
		button.mouse_entered.connect(_on_skill_button_hovered.bind(skill_id))
		tree_area.add_child(button)
		tree_area.move_child(button, tree_area.get_child_count() - 1)
		buttons[skill_id] = button

		var skill_data: Dictionary = skill_defs.get(skill_id, {})
		for required_skill in skill_data.get("requires", []):
			line_edges.append({"from": String(required_skill), "to": skill_id})

	if selected_skill_id.is_empty() and not skill_ids.is_empty():
		selected_skill_id = String(skill_ids[0])

	_layout_graph()


func _layout_graph() -> void:
	var node_centers: Dictionary = {}
	for skill_id in buttons.keys():
		var skill_data: Dictionary = skill_defs.get(skill_id, {})
		var graph_position: Array = skill_data.get("graph_position", [0, 0])
		var x := GRAPH_PADDING.x + float(graph_position[0]) * GRAPH_STEP.x
		var y := GRAPH_PADDING.y + float(graph_position[1]) * GRAPH_STEP.y
		var button: Button = buttons[skill_id]
		button.position = Vector2(x, y)
		node_centers[skill_id] = button.position + NODE_SIZE * 0.5

	graph_overlay.configure(node_centers, line_edges, {})


func _refresh_edges() -> void:
	var node_centers: Dictionary = {}
	var active_edges: Dictionary = {}
	for skill_id in buttons.keys():
		var button: Button = buttons[skill_id]
		node_centers[skill_id] = button.position + NODE_SIZE * 0.5
		if purchased_skills.has(skill_id):
			var skill_data: Dictionary = skill_defs.get(skill_id, {})
			for required_skill in skill_data.get("requires", []):
				active_edges["%s->%s" % [String(required_skill), skill_id]] = true

	graph_overlay.configure(node_centers, line_edges, active_edges)


func _refresh_detail_text() -> void:
	if selected_skill_id.is_empty() or not skill_defs.has(selected_skill_id):
		hint_label.text = Localization.tr_key("skill_tree.hint")
		return

	var skill_data: Dictionary = skill_defs.get(selected_skill_id, {})
	var title := Localization.tr_key(String(skill_data.get("title_key", selected_skill_id)))
	var description := Localization.tr_key(String(skill_data.get("description_key", "")))
	var cost := int(skill_data.get("cost", 0))
	var status := Localization.tr_key("skill_tree.status.cost", {"cost": cost})
	if purchased_skills.has(selected_skill_id):
		status = Localization.tr_key("skill_tree.status.bought")
	elif not _requirements_met(selected_skill_id):
		status = Localization.tr_key("skill_tree.status.locked")
	elif current_crystals < cost:
		status = Localization.tr_key("skill_tree.status.cannot_afford")

	hint_label.text = "%s\n%s\n%s" % [title, description, status]


func _make_node_style(bg_color: Color, border_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.border_width_left = 4
	style.border_width_top = 4
	style.border_width_right = 4
	style.border_width_bottom = 4
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	return style


func _on_skill_button_hovered(skill_id: String) -> void:
	selected_skill_id = skill_id
	_refresh_detail_text()
