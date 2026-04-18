extends Control
class_name SkillTreePanel

signal skill_purchased(skill_id: String)
signal next_round_requested

const GRAPH_OVERLAY_SCRIPT := preload("res://scripts/skill_graph_overlay.gd")
const SKILL_NODE_BUTTON_SCRIPT := preload("res://scripts/skill_node_button.gd")
const NODE_SIZE := Vector2(68.0, 68.0)
const GRAPH_PADDING := Vector2(92.0, 78.0)
const MIN_GRAPH_STEP := Vector2(190.0, 104.0)
const MAX_GRAPH_STEP := Vector2(330.0, 152.0)
const NODE_STATE_LOCKED := 0
const NODE_STATE_AVAILABLE := 1
const NODE_STATE_PURCHASED := 2
const MIN_GRAPH_ZOOM := 0.65
const MAX_GRAPH_ZOOM := 1.55
const GRAPH_ZOOM_STEP := 1.12
const GRAPH_PAN_MARGIN := 120.0

var skill_defs: Dictionary = {}
var current_crystals := 0
var purchased_skills: Dictionary = {}
var current_stats: Dictionary = {}
var finished_round := 1
var buttons: Dictionary = {}
var selected_skill_id := ""
var graph_content: Control
var graph_overlay
var line_edges: Array[Dictionary] = []
var tooltip_panel: PanelContainer
var tooltip_title_label: Label
var tooltip_status_label: Label
var tooltip_description_label: Label
var graph_zoom := 1.0
var graph_offset := Vector2.ZERO
var is_panning_graph := false
var last_pan_position := Vector2.ZERO

@onready var panel: PanelContainer = $Backdrop/Panel
@onready var title_label: Label = $Backdrop/Panel/Margin/VBox/Header/TitleLabel
@onready var summary_label: Label = $Backdrop/Panel/Margin/VBox/SummaryLabel
@onready var resources_label: Label = $Backdrop/Panel/Margin/VBox/Header/ResourcesLabel
@onready var tree_area: Control = $Backdrop/Panel/Margin/VBox/TreeArea
@onready var hint_label: Label = $Backdrop/Panel/Margin/VBox/HintLabel
@onready var start_button: Button = $Backdrop/Panel/Margin/VBox/Footer/StartButton


func _ready() -> void:
	tree_area.clip_contents = true
	graph_content = Control.new()
	graph_content.name = "GraphContent"
	graph_content.layout_mode = 1
	graph_content.anchors_preset = PRESET_FULL_RECT
	graph_content.anchor_right = 1.0
	graph_content.anchor_bottom = 1.0
	graph_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tree_area.add_child(graph_content)

	graph_overlay = GRAPH_OVERLAY_SCRIPT.new()
	graph_overlay.name = "GraphOverlay"
	graph_overlay.layout_mode = 1
	graph_overlay.anchors_preset = PRESET_FULL_RECT
	graph_overlay.anchor_right = 1.0
	graph_overlay.anchor_bottom = 1.0
	graph_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	graph_content.add_child(graph_overlay)
	_create_tooltip()
	hint_label.visible = false
	start_button.pressed.connect(_on_start_button_pressed)
	Localization.locale_changed.connect(_on_locale_changed)
	tree_area.gui_input.connect(_on_tree_area_gui_input)
	tree_area.mouse_exited.connect(_on_tree_area_mouse_exited)
	resized.connect(_on_layout_changed)
	tree_area.resized.connect(_on_layout_changed)
	visible = false


func configure(definitions: Dictionary) -> void:
	skill_defs = definitions
	_build_graph()
	_refresh_view()


func show_panel(currency: int, purchased: Dictionary, stats: Dictionary, round_number: int) -> void:
	current_crystals = currency
	purchased_skills = purchased.duplicate(true)
	current_stats = stats.duplicate(true)
	finished_round = round_number
	_reset_graph_view()
	visible = true
	_refresh_view()
	call_deferred("_layout_graph")


func hide_panel() -> void:
	visible = false


func refresh(currency: int, purchased: Dictionary, stats: Dictionary, round_number: int) -> void:
	current_crystals = currency
	purchased_skills = purchased.duplicate(true)
	current_stats = stats.duplicate(true)
	finished_round = round_number
	_refresh_view()
	call_deferred("_layout_graph")


func _refresh_view() -> void:
	if not is_node_ready():
		return

	_refresh_screen_chrome()
	title_label.text = Localization.tr_key("skill_tree.title")
	summary_label.text = Localization.tr_key("skill_tree.summary", {"round": finished_round})
	resources_label.text = Localization.tr_key("skill_tree.resources", {"crystals": current_crystals})
	start_button.text = Localization.tr_key("skill_tree.start_round", {"round": finished_round + 1})
	_layout_panel()

	for skill_id in buttons.keys():
		_refresh_button(skill_id)

	_refresh_tooltip()
	_refresh_edges()


func _refresh_button(skill_id: String) -> void:
	var button: Button = buttons[skill_id]
	var data: Dictionary = skill_defs.get(skill_id, {})
	var title := Localization.tr_key(String(data.get("title_key", skill_id)))
	var description := Localization.tr_key(String(data.get("description_key", "")))
	var is_purchased := purchased_skills.has(skill_id)
	var is_unlocked := _requirements_met(skill_id)
	var can_afford := _is_skill_affordable(skill_id)

	button.tooltip_text = ""
	button.disabled = false
	if is_purchased:
		button.set_visual_state(NODE_STATE_PURCHASED)
	elif is_unlocked and can_afford:
		button.set_visual_state(NODE_STATE_AVAILABLE)
	else:
		button.set_visual_state(NODE_STATE_LOCKED)


func _requirements_met(skill_id: String) -> bool:
	var data: Dictionary = skill_defs.get(skill_id, {})
	var requirements: Array = data.get("requires", [])
	for required_skill in requirements:
		if not purchased_skills.has(String(required_skill)):
			return false
	return true


func _is_skill_affordable(skill_id: String) -> bool:
	var data: Dictionary = skill_defs.get(skill_id, {})
	return current_crystals >= int(data.get("cost", 0))


func _is_skill_available(skill_id: String) -> bool:
	if purchased_skills.has(skill_id):
		return false
	if not _requirements_met(skill_id):
		return false
	return _is_skill_affordable(skill_id)


func _get_skill_status(skill_id: String) -> String:
	var data: Dictionary = skill_defs.get(skill_id, {})
	var cost := int(data.get("cost", 0))
	if purchased_skills.has(skill_id):
		return Localization.tr_key("skill_tree.status.bought")
	if not _requirements_met(skill_id):
		return Localization.tr_key("skill_tree.status.locked")
	if current_crystals < cost:
		return Localization.tr_key("skill_tree.status.cannot_afford")
	return Localization.tr_key("skill_tree.status.cost", {"cost": cost})


func _build_graph() -> void:
	if not is_node_ready():
		return

	for child in graph_content.get_children():
		if child != graph_overlay and child != tooltip_panel:
			child.queue_free()
	buttons.clear()
	line_edges.clear()
	selected_skill_id = ""

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
		var button: Button = SKILL_NODE_BUTTON_SCRIPT.new()
		button.name = "%sButton" % skill_id
		button.custom_minimum_size = NODE_SIZE
		button.size = NODE_SIZE
		button.configure(skill_id, skill_id)
		button.mouse_filter = Control.MOUSE_FILTER_PASS
		button.pressed.connect(_on_skill_button_pressed.bind(skill_id))
		button.mouse_entered.connect(_on_skill_button_hovered.bind(skill_id))
		button.mouse_exited.connect(_on_skill_button_unhovered.bind(skill_id))
		graph_content.add_child(button)
		graph_content.move_child(button, graph_content.get_child_count() - 1)
		buttons[skill_id] = button

		var skill_data: Dictionary = skill_defs.get(skill_id, {})
		for required_skill in skill_data.get("requires", []):
			line_edges.append({"from": String(required_skill), "to": skill_id})

	call_deferred("_layout_graph")


func _layout_graph() -> void:
	if not is_node_ready():
		return

	var area_size := tree_area.size
	if area_size.x <= 1.0 or area_size.y <= 1.0:
		area_size = tree_area.custom_minimum_size
	graph_content.size = area_size
	graph_overlay.size = area_size

	var max_col := 0
	var max_row := 0
	for skill_id in buttons.keys():
		var skill_data: Dictionary = skill_defs.get(skill_id, {})
		var graph_position: Array = skill_data.get("graph_position", [0, 0])
		max_col = maxi(max_col, int(graph_position[0]))
		max_row = maxi(max_row, int(graph_position[1]))

	var graph_step := Vector2(
		clampf(area_size.x / maxf(1.0, float(max_col) + 2.25), MIN_GRAPH_STEP.x, MAX_GRAPH_STEP.x),
		clampf(area_size.y / maxf(1.0, float(max_row) + 1.85), MIN_GRAPH_STEP.y, MAX_GRAPH_STEP.y)
	)
	var node_size := NODE_SIZE
	if area_size.x < 960.0:
		node_size = Vector2(58.0, 58.0)
	var content_size := Vector2(
		float(max_col) * graph_step.x + node_size.x,
		float(max_row) * graph_step.y + node_size.y
	)
	var graph_origin := Vector2(
		maxf(GRAPH_PADDING.x * 0.5, (area_size.x - content_size.x) * 0.46),
		maxf(GRAPH_PADDING.y * 0.5, (area_size.y - content_size.y) * 0.5)
	)

	var node_centers: Dictionary = {}
	for skill_id in buttons.keys():
		var skill_data: Dictionary = skill_defs.get(skill_id, {})
		var graph_position: Array = skill_data.get("graph_position", [0, 0])
		var button: Button = buttons[skill_id]
		button.custom_minimum_size = node_size
		button.size = node_size
		button.position = graph_origin + Vector2(float(graph_position[0]) * graph_step.x, float(graph_position[1]) * graph_step.y)
		node_centers[skill_id] = button.position + node_size * 0.5

	graph_overlay.configure(node_centers, line_edges, _build_edge_state())
	_apply_graph_transform()
	_layout_tooltip()


func _refresh_edges() -> void:
	var node_centers: Dictionary = {}
	for skill_id in buttons.keys():
		var button: Button = buttons[skill_id]
		node_centers[skill_id] = button.position + button.size * 0.5
	graph_overlay.configure(node_centers, line_edges, _build_edge_state())


func _build_edge_state() -> Dictionary:
	var edge_state: Dictionary = {}
	for edge_data in line_edges:
		var from_id := String(edge_data.get("from", ""))
		var to_id := String(edge_data.get("to", ""))
		var edge_key := "%s->%s" % [from_id, to_id]
		if purchased_skills.has(from_id) and purchased_skills.has(to_id):
			edge_state[edge_key] = "purchased"
		elif purchased_skills.has(from_id) and _is_skill_available(to_id):
			edge_state[edge_key] = "available"
		else:
			edge_state[edge_key] = "locked"
	return edge_state


func _create_tooltip() -> void:
	tooltip_panel = PanelContainer.new()
	tooltip_panel.name = "SkillTooltip"
	tooltip_panel.custom_minimum_size = Vector2.ZERO
	tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip_panel.z_index = 30

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.88)
	style.border_color = Color(0.05, 0.05, 0.05, 1.0)
	style.border_width_left = 4
	style.border_width_top = 4
	style.border_width_right = 4
	style.border_width_bottom = 4
	style.content_margin_left = 12
	style.content_margin_top = 10
	style.content_margin_right = 12
	style.content_margin_bottom = 10
	tooltip_panel.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	tooltip_panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	margin.add_child(box)

	tooltip_title_label = Label.new()
	tooltip_title_label.add_theme_font_size_override("font_size", 20)
	tooltip_title_label.add_theme_color_override("font_color", Color(0.95, 0.96, 0.9, 1.0))
	box.add_child(tooltip_title_label)

	tooltip_status_label = Label.new()
	tooltip_status_label.add_theme_font_size_override("font_size", 15)
	tooltip_status_label.add_theme_color_override("font_color", Color(1.0, 0.91, 0.35, 1.0))
	box.add_child(tooltip_status_label)

	tooltip_description_label = Label.new()
	tooltip_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tooltip_description_label.add_theme_font_size_override("font_size", 17)
	tooltip_description_label.add_theme_color_override("font_color", Color(0.92, 0.95, 0.92, 1.0))
	box.add_child(tooltip_description_label)

	tree_area.add_child(tooltip_panel)
	tooltip_panel.visible = false


func _refresh_tooltip() -> void:
	if selected_skill_id.is_empty() or not skill_defs.has(selected_skill_id):
		tooltip_panel.visible = false
		return

	var data: Dictionary = skill_defs.get(selected_skill_id, {})
	tooltip_title_label.text = Localization.tr_key(String(data.get("title_key", selected_skill_id)))
	tooltip_status_label.text = _get_skill_status(selected_skill_id)
	tooltip_description_label.text = Localization.tr_key(String(data.get("description_key", "")))
	_resize_tooltip_to_content()
	tooltip_panel.visible = true
	_layout_tooltip()


func _resize_tooltip_to_content() -> void:
	if tooltip_panel == null:
		return

	tooltip_panel.size = Vector2.ZERO
	tooltip_panel.reset_size()


func _layout_tooltip() -> void:
	if selected_skill_id.is_empty() or not buttons.has(selected_skill_id):
		return

	var button: Control = buttons[selected_skill_id]
	var button_position := graph_content.position + button.position * graph_zoom
	var button_size := button.size * graph_zoom
	var desired := button_position + Vector2(button_size.x + 28.0, button_size.y * 0.25)
	var tooltip_size := tooltip_panel.get_combined_minimum_size()
	if tooltip_size.x <= 1.0 or tooltip_size.y <= 1.0:
		tooltip_size = tooltip_panel.size
	tooltip_panel.size = tooltip_size

	if desired.x + tooltip_size.x > tree_area.size.x - 24.0:
		desired.x = button_position.x - tooltip_size.x - 28.0
	if desired.y + tooltip_size.y > tree_area.size.y - 24.0:
		desired.y = tree_area.size.y - tooltip_size.y - 24.0
	desired.x = maxf(18.0, desired.x)
	desired.y = maxf(18.0, desired.y)
	tooltip_panel.position = desired


func _refresh_screen_chrome() -> void:
	var transparent := StyleBoxFlat.new()
	transparent.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	panel.add_theme_stylebox_override("panel", transparent)

	title_label.add_theme_font_size_override("font_size", 30)
	resources_label.add_theme_font_size_override("font_size", 22)
	resources_label.add_theme_color_override("font_color", Color(0.74, 0.93, 1.0, 1.0))

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.07, 0.20, 0.46, 1.0)
	normal.border_color = Color(0.92, 0.96, 1.0, 1.0)
	normal.border_width_left = 4
	normal.border_width_top = 4
	normal.border_width_right = 4
	normal.border_width_bottom = 4
	normal.content_margin_left = 24
	normal.content_margin_top = 12
	normal.content_margin_right = 24
	normal.content_margin_bottom = 12

	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = Color(0.035, 0.12, 0.32, 1.0)
	start_button.add_theme_stylebox_override("normal", normal)
	start_button.add_theme_stylebox_override("hover", normal)
	start_button.add_theme_stylebox_override("pressed", pressed)
	start_button.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0, 1.0))
	start_button.add_theme_font_size_override("font_size", 20)


func _layout_panel() -> void:
	if not is_node_ready():
		return

	var outer_margin_x := clampf(size.x * 0.035, 14.0, 42.0)
	var outer_margin_y := clampf(size.y * 0.04, 10.0, 30.0)
	panel.offset_left = outer_margin_x
	panel.offset_top = outer_margin_y
	panel.offset_right = -outer_margin_x
	panel.offset_bottom = -outer_margin_y


func _on_skill_button_pressed(skill_id: String) -> void:
	selected_skill_id = skill_id
	_refresh_tooltip()
	if not _is_skill_available(skill_id):
		return
	skill_purchased.emit(skill_id)


func _on_skill_button_hovered(skill_id: String) -> void:
	selected_skill_id = skill_id
	_refresh_tooltip()


func _on_skill_button_unhovered(skill_id: String) -> void:
	if selected_skill_id != skill_id:
		return

	selected_skill_id = ""
	_refresh_tooltip()


func _on_tree_area_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP and mouse_event.pressed:
			_zoom_graph_at(tree_area.get_local_mouse_position(), GRAPH_ZOOM_STEP)
			accept_event()
		elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN and mouse_event.pressed:
			_zoom_graph_at(tree_area.get_local_mouse_position(), 1.0 / GRAPH_ZOOM_STEP)
			accept_event()
		elif _is_graph_pan_button(mouse_event.button_index):
			is_panning_graph = mouse_event.pressed
			last_pan_position = tree_area.get_local_mouse_position()
			if is_panning_graph:
				accept_event()
		elif mouse_event.button_index == MOUSE_BUTTON_LEFT:
			is_panning_graph = mouse_event.pressed and not _is_mouse_over_skill_node()
			last_pan_position = tree_area.get_local_mouse_position()
			if is_panning_graph:
				accept_event()
	elif event is InputEventMouseMotion and is_panning_graph:
		var current_position := tree_area.get_local_mouse_position()
		graph_offset += current_position - last_pan_position
		last_pan_position = current_position
		_apply_graph_transform()
		accept_event()


func _on_tree_area_mouse_exited() -> void:
	is_panning_graph = false
	selected_skill_id = ""
	_refresh_tooltip()


func _is_graph_pan_button(button_index: int) -> bool:
	return button_index == MOUSE_BUTTON_MIDDLE or button_index == MOUSE_BUTTON_RIGHT


func _is_mouse_over_skill_node() -> bool:
	var mouse_position := tree_area.get_local_mouse_position()
	for skill_id in buttons.keys():
		var button: Control = buttons[skill_id]
		var button_rect := Rect2(
			graph_content.position + button.position * graph_zoom,
			button.size * graph_zoom
		)
		if button_rect.has_point(mouse_position):
			return true
	return false


func _zoom_graph_at(mouse_position: Vector2, zoom_factor: float) -> void:
	var previous_zoom := graph_zoom
	graph_zoom = clampf(graph_zoom * zoom_factor, MIN_GRAPH_ZOOM, MAX_GRAPH_ZOOM)
	if is_equal_approx(previous_zoom, graph_zoom):
		return

	graph_offset = mouse_position - (mouse_position - graph_offset) * (graph_zoom / previous_zoom)
	_apply_graph_transform()


func _reset_graph_view() -> void:
	graph_zoom = 1.0
	graph_offset = Vector2.ZERO
	is_panning_graph = false
	if graph_content != null:
		_apply_graph_transform()


func _apply_graph_transform() -> void:
	if graph_content == null or not is_node_ready():
		return

	_clamp_graph_offset()
	graph_content.position = graph_offset
	graph_content.scale = Vector2.ONE * graph_zoom
	_layout_tooltip()


func _clamp_graph_offset() -> void:
	if graph_content == null:
		return

	var area_size := tree_area.size
	var content_size := graph_content.size * graph_zoom
	graph_offset.x = clampf(graph_offset.x, area_size.x - content_size.x - GRAPH_PAN_MARGIN, GRAPH_PAN_MARGIN)
	graph_offset.y = clampf(graph_offset.y, area_size.y - content_size.y - GRAPH_PAN_MARGIN, GRAPH_PAN_MARGIN)


func _on_start_button_pressed() -> void:
	next_round_requested.emit()


func _on_locale_changed(_new_locale: String) -> void:
	_refresh_view()


func _on_layout_changed() -> void:
	_layout_panel()
	_layout_graph()
