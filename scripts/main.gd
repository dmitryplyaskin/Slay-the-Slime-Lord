extends Node2D

const SLIME_SCENE := preload("res://scenes/slime.tscn")
const CRYSTAL_SCENE := preload("res://scenes/crystal.tscn")
const RUN_STATE_SCRIPT := preload("res://scripts/core/run_state.gd")
const MIN_ARENA_SIZE := Vector2(760.0, 340.0)
const VIEWPORT_SAFE_MARGIN := Vector2(54.0, 132.0)

enum GameState {
	BATTLE,
	RESULT,
	UPGRADES,
}

var rng := RandomNumberGenerator.new()
var run_state
var state: int = GameState.BATTLE
var arena_rect := Rect2(Vector2(280.0, 210.0), Vector2(720.0, 320.0))
var round_time_left := 0.0
var pulse_charge := 0.0
var round_end_reason_key := ""
var round_start_crystals := 0
var round_defeated_count := 0
var round_spawn_count := 0
var active_hint_key := "hint.battle_idle"
var active_hint_params: Dictionary = {}

@onready var arena: Node2D = $Arena
@onready var backdrop: Polygon2D = $Arena/Backdrop
@onready var ground_shadow: Polygon2D = $Arena/GroundShadow
@onready var ground: Polygon2D = $Arena/Ground
@onready var ground_inset: Polygon2D = $Arena/GroundInset
@onready var ridge_a: Line2D = $Arena/RidgeA
@onready var ridge_b: Line2D = $Arena/RidgeB
@onready var arena_glow: Line2D = $Arena/ArenaGlow
@onready var slimes_layer: Node2D = $Arena/Slimes
@onready var crystals_layer: Node2D = $Arena/Crystals
@onready var cursor_pulse = $Arena/CursorPulse
@onready var camera: Camera2D = $Camera2D
@onready var hud: Control = $CanvasLayer/HUD
@onready var top_bar: PanelContainer = $CanvasLayer/HUD/TopBar
@onready var bottom_hint: PanelContainer = $CanvasLayer/HUD/BottomHint
@onready var title_label: Label = $CanvasLayer/HUD/TopBar/Row/TitleLabel
@onready var phase_label: Label = $CanvasLayer/HUD/BottomHint/HintRow/PhaseLabel
@onready var round_label: Label = $CanvasLayer/HUD/TopBar/Row/RoundBadge/RoundLabel
@onready var timer_label: Label = $CanvasLayer/HUD/TopBar/Row/TimerBadge/TimerLabel
@onready var crystal_label: Label = $CanvasLayer/HUD/TopBar/Row/CrystalBadge/CrystalLabel
@onready var slime_label: Label = $CanvasLayer/HUD/TopBar/Row/SlimeBadge/SlimeLabel
@onready var hint_label: Label = $CanvasLayer/HUD/BottomHint/HintRow/HintLabel
@onready var language_selector: OptionButton = $CanvasLayer/HUD/TopBar/Row/LanguageSelector
@onready var result_overlay: Control = $CanvasLayer/ResultOverlay
@onready var result_panel: PanelContainer = $CanvasLayer/ResultOverlay/Backdrop/Panel
@onready var result_title_label: Label = $CanvasLayer/ResultOverlay/Backdrop/Panel/VBox/ResultTitleLabel
@onready var result_reason_label: Label = $CanvasLayer/ResultOverlay/Backdrop/Panel/VBox/ResultReasonLabel
@onready var result_stats_label: Label = $CanvasLayer/ResultOverlay/Backdrop/Panel/VBox/ResultStatsLabel
@onready var result_continue_button: Button = $CanvasLayer/ResultOverlay/Backdrop/Panel/VBox/ContinueButton
@onready var skill_tree: SkillTreePanel = $CanvasLayer/SkillTree


func _ready() -> void:
	rng.randomize()
	run_state = RUN_STATE_SCRIPT.new()
	run_state.setup({
		"base_stats": ContentDB.get_player_base_stats(),
		"round_scaling": ContentDB.get_round_scaling(),
		"combat_limits": ContentDB.get_combat_limits(),
		"skill_defs": ContentDB.get_skills(),
		"slime_defs": ContentDB.get_slimes(),
	})
	skill_tree.configure(run_state.get_skill_defs())
	skill_tree.skill_purchased.connect(_on_skill_purchased)
	skill_tree.next_round_requested.connect(_on_next_round_requested)
	Localization.locale_changed.connect(_on_locale_changed)
	result_continue_button.pressed.connect(_on_result_continue_requested)
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_setup_language_selector()
	_refresh_language_selector()
	_layout_for_viewport()
	cursor_pulse.configure(float(run_state.get_effective_stats()["attack_radius"]))
	_start_round()


func _process(delta: float) -> void:
	cursor_pulse.global_position = get_global_mouse_position()
	if state == GameState.BATTLE:
		cursor_pulse.visible = true
		_update_targeted_slimes()
		_update_pulse_attack(delta)
		round_time_left = maxf(0.0, round_time_left - delta)
		if round_time_left <= 0.0:
			_finish_round("round.end.timeout")
		elif slimes_layer.get_child_count() == 0:
			_finish_round("round.end.cleared")
	else:
		cursor_pulse.visible = false
		_clear_targeted_slimes()

	_update_hud()


func _start_round() -> void:
	state = GameState.BATTLE
	run_state.start_next_round()
	round_time_left = run_state.get_round_duration()
	pulse_charge = 0.0
	round_end_reason_key = ""
	round_start_crystals = run_state.crystal_bank
	round_defeated_count = 0
	round_spawn_count = 0
	active_hint_key = "hint.battle_idle"
	active_hint_params = {}
	hud.visible = true
	result_overlay.visible = false
	skill_tree.hide_panel()
	_clear_children(slimes_layer)
	_clear_children(crystals_layer)
	cursor_pulse.configure(float(run_state.get_effective_stats()["attack_radius"]))
	cursor_pulse.set_progress(0.0)
	_spawn_slimes()
	_update_hud()


func _spawn_slimes() -> void:
	var spawn_profile: Dictionary = run_state.get_spawn_profile()
	var spawn_count: int = int(spawn_profile["slime_count"])
	round_spawn_count = spawn_count
	var slime_hp: float = float(spawn_profile["slime_hp"])
	var slime_speed: float = float(spawn_profile["slime_speed"])
	var slime_defs: Array[Dictionary] = run_state.get_slime_defs()

	for index in range(spawn_count):
		var slime: Slime = SLIME_SCENE.instantiate()
		var slime_data: Dictionary = slime_defs[rng.randi_range(0, slime_defs.size() - 1)]
		var spawn_position := Vector2(
			rng.randf_range(arena_rect.position.x + 40.0, arena_rect.end.x - 40.0),
			rng.randf_range(arena_rect.position.y + 40.0, arena_rect.end.y - 40.0)
		)
		slime.setup(
			arena_rect,
			spawn_position,
			slime_speed,
			Color.html(String(slime_data["color"])),
			slime_hp,
			String(slime_data["name_key"]),
			index + 1
		)
		slime.defeated.connect(_on_slime_defeated)
		slimes_layer.add_child(slime)


func _update_targeted_slimes() -> void:
	var targeted_count := 0
	var mouse_position := get_global_mouse_position()
	var attack_radius := float(run_state.get_effective_stats()["attack_radius"])
	for child in slimes_layer.get_children():
		var slime := child as Slime
		if slime == null:
			continue
		var is_inside := _is_slime_in_attack_range(slime, mouse_position, attack_radius)
		slime.set_targeted(is_inside)
		if is_inside:
			targeted_count += 1

	if targeted_count == 0:
		active_hint_key = "hint.battle_idle"
		active_hint_params = {}
	else:
		active_hint_key = "hint.battle_targeted"
		active_hint_params = {"count": targeted_count}


func _update_pulse_attack(delta: float) -> void:
	var attack_interval := float(run_state.get_effective_stats()["attack_interval"])
	pulse_charge += delta
	cursor_pulse.set_progress(pulse_charge / attack_interval)
	if pulse_charge < attack_interval:
		return

	pulse_charge = 0.0
	cursor_pulse.set_progress(0.0)
	cursor_pulse.trigger_flash()
	_fire_pulse()


func _fire_pulse() -> void:
	var mouse_position := get_global_mouse_position()
	var effective_stats: Dictionary = run_state.get_effective_stats()
	var attack_radius := float(effective_stats["attack_radius"])
	var pulse_damage := float(effective_stats["pulse_damage"])
	for child in slimes_layer.get_children():
		var slime := child as Slime
		if slime == null:
			continue
		if _is_slime_in_attack_range(slime, mouse_position, attack_radius):
			slime.take_damage(pulse_damage)


func _is_slime_in_attack_range(slime: Slime, attack_origin: Vector2, attack_radius: float) -> bool:
	var overlap_radius := attack_radius + slime.get_hit_radius()
	return slime.global_position.distance_squared_to(attack_origin) <= overlap_radius * overlap_radius


func _finish_round(reason: String) -> void:
	if state != GameState.BATTLE:
		return

	state = GameState.UPGRADES
	round_end_reason_key = reason
	pulse_charge = 0.0
	cursor_pulse.set_progress(0.0)
	_clear_children(slimes_layer)
	_clear_targeted_slimes()
	_show_result_screen()
	_update_hud()


func _on_slime_defeated(world_position: Vector2, slime_color: Color) -> void:
	var crystal_value := int(run_state.get_effective_stats()["crystal_value"])
	run_state.earn_crystals(crystal_value)
	round_defeated_count += 1

	var crystal: Crystal = CRYSTAL_SCENE.instantiate()
	crystal.position = world_position
	crystal.setup(slime_color)
	crystals_layer.add_child(crystal)


func _on_skill_purchased(skill_id: String) -> void:
	if not run_state.purchase_skill(skill_id):
		return

	cursor_pulse.configure(float(run_state.get_effective_stats()["attack_radius"]))
	skill_tree.refresh(run_state.crystal_bank, run_state.get_purchased_skills(), run_state.get_effective_stats(), run_state.round_number)
	_update_hud()


func _on_next_round_requested() -> void:
	if state != GameState.UPGRADES:
		return
	_start_round()


func _update_hud() -> void:
	var effective_stats: Dictionary = run_state.get_effective_stats()
	title_label.text = Localization.tr_key("title.game")
	if state == GameState.BATTLE:
		hud.visible = true
		phase_label.text = Localization.tr_key("phase.battle")
		timer_label.text = Localization.tr_key("hud.time_left.short", {"seconds": "%.1f" % round_time_left})
	else:
		hud.visible = false

	round_label.text = Localization.tr_key("hud.round.short", {"round": run_state.round_number})
	crystal_label.text = Localization.tr_key("hud.crystals.short", {
		"current": run_state.crystal_bank,
		"total": run_state.total_crystals_earned,
	})
	slime_label.text = Localization.tr_key("hud.slimes.short", {
		"current": slimes_layer.get_child_count(),
		"total": round_spawn_count,
	})
	var hint_params := {
		"damage": int(round(float(effective_stats["pulse_damage"]))),
		"interval": "%.2f" % float(effective_stats["attack_interval"]),
		"radius": int(round(float(effective_stats["attack_radius"]))),
	}
	for key in active_hint_params.keys():
		hint_params[key] = active_hint_params[key]
	hint_label.text = Localization.tr_key(active_hint_key, hint_params)


func _show_result_screen() -> void:
	state = GameState.RESULT
	hud.visible = false
	result_overlay.visible = true
	_refresh_result_screen()


func _refresh_result_screen() -> void:
	var earned_this_round: int = int(run_state.crystal_bank) - round_start_crystals
	result_title_label.text = Localization.tr_key("result.title", {"round": run_state.round_number})
	result_reason_label.text = Localization.tr_key(round_end_reason_key)
	result_stats_label.text = Localization.tr_key("result.stats", {
		"crystals": earned_this_round,
		"defeated": round_defeated_count,
		"total": round_spawn_count,
		"bank": run_state.crystal_bank,
	})
	result_continue_button.text = Localization.tr_key("result.continue")


func _on_result_continue_requested() -> void:
	if state != GameState.RESULT:
		return

	state = GameState.UPGRADES
	result_overlay.visible = false
	skill_tree.show_panel(run_state.crystal_bank, run_state.get_purchased_skills(), run_state.get_effective_stats(), run_state.round_number)
	_update_hud()


func _layout_for_viewport() -> void:
	if not is_node_ready():
		return

	var viewport_size := get_viewport_rect().size
	camera.position = viewport_size * 0.5
	_layout_hud(viewport_size)
	backdrop.polygon = PackedVector2Array([
		Vector2.ZERO,
		Vector2(viewport_size.x, 0.0),
		viewport_size,
		Vector2(0.0, viewport_size.y),
	])

	var usable_width := maxf(MIN_ARENA_SIZE.x, viewport_size.x - VIEWPORT_SAFE_MARGIN.x * 2.0)
	var usable_height := maxf(MIN_ARENA_SIZE.y, viewport_size.y - VIEWPORT_SAFE_MARGIN.y * 2.0)
	var arena_width := minf(usable_width, viewport_size.x * 0.82)
	var arena_height := minf(usable_height, viewport_size.y * 0.58)
	var center := Vector2(viewport_size.x * 0.5, viewport_size.y * 0.53)
	var half := Vector2(arena_width * 0.5, arena_height * 0.5)
	var diamond := PackedVector2Array([
		center + Vector2(0.0, -half.y),
		center + Vector2(half.x, 0.0),
		center + Vector2(0.0, half.y),
		center + Vector2(-half.x, 0.0),
	])
	var inset_half := half * 0.82
	var inset := PackedVector2Array([
		center + Vector2(0.0, -inset_half.y),
		center + Vector2(inset_half.x, 0.0),
		center + Vector2(0.0, inset_half.y),
		center + Vector2(-inset_half.x, 0.0),
	])

	ground_shadow.polygon = PackedVector2Array([
		diamond[0] + Vector2(0.0, 18.0),
		diamond[1] + Vector2(22.0, 20.0),
		diamond[2] + Vector2(0.0, 28.0),
		diamond[3] + Vector2(-22.0, 20.0),
	])
	ground.polygon = diamond
	ground_inset.polygon = inset
	ridge_a.points = PackedVector2Array([inset[3], inset[0], inset[1]])
	ridge_b.points = PackedVector2Array([inset[3], inset[2], inset[1]])
	arena_glow.points = inset

	var spawn_width := arena_width * 0.68
	var spawn_height := arena_height * 0.52
	arena_rect = Rect2(center - Vector2(spawn_width, spawn_height) * 0.5, Vector2(spawn_width, spawn_height))
	for slime in slimes_layer.get_children():
		if slime is Slime:
			slime.arena_rect = arena_rect

	_layout_result_panel(viewport_size)


func _layout_hud(viewport_size: Vector2) -> void:
	var compact := viewport_size.x < 760.0
	title_label.visible = not compact
	language_selector.visible = viewport_size.x >= 640.0
	phase_label.custom_minimum_size = Vector2(86.0 if compact else 160.0, 0.0)
	top_bar.offset_bottom = 64.0 if compact else 72.0

	var side_margin := clampf(viewport_size.x * 0.025, 14.0, 28.0)
	bottom_hint.offset_left = side_margin
	bottom_hint.offset_right = -side_margin
	bottom_hint.offset_top = -66.0 if compact else -74.0
	bottom_hint.offset_bottom = -14.0 if compact else -22.0


func _layout_result_panel(viewport_size: Vector2) -> void:
	var panel_width := clampf(viewport_size.x * 0.44, 360.0, 560.0)
	var panel_height := clampf(viewport_size.y * 0.46, 300.0, 390.0)
	result_panel.offset_left = -panel_width * 0.5
	result_panel.offset_right = panel_width * 0.5
	result_panel.offset_top = -panel_height * 0.5
	result_panel.offset_bottom = panel_height * 0.5


func _on_viewport_size_changed() -> void:
	_layout_for_viewport()


func _clear_children(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()


func _clear_targeted_slimes() -> void:
	for slime in slimes_layer.get_children():
		slime.set_targeted(false)


func _setup_language_selector() -> void:
	language_selector.clear()
	for language_data in ContentDB.get_languages():
		var locale_id := String(language_data.get("id", ""))
		language_selector.add_item(Localization.get_language_label(locale_id))
		language_selector.set_item_metadata(language_selector.item_count - 1, locale_id)
	if not language_selector.item_selected.is_connected(_on_language_selected):
		language_selector.item_selected.connect(_on_language_selected)


func _refresh_language_selector() -> void:
	for index in range(language_selector.item_count):
		var locale_id := String(language_selector.get_item_metadata(index))
		language_selector.set_item_text(index, Localization.get_language_label(locale_id))
		if locale_id == Localization.get_locale():
			language_selector.select(index)


func _on_language_selected(index: int) -> void:
	var locale_id := String(language_selector.get_item_metadata(index))
	Localization.set_locale(locale_id)


func _on_locale_changed(_new_locale: String) -> void:
	_refresh_language_selector()
	if state == GameState.UPGRADES:
		skill_tree.refresh(run_state.crystal_bank, run_state.get_purchased_skills(), run_state.get_effective_stats(), run_state.round_number)
	elif state == GameState.RESULT:
		_refresh_result_screen()
	_update_hud()
