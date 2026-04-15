extends Node2D

const SLIME_SCENE := preload("res://scenes/slime.tscn")
const CRYSTAL_SCENE := preload("res://scenes/crystal.tscn")
const RUN_STATE_SCRIPT := preload("res://scripts/core/run_state.gd")
const ARENA_RECT := Rect2(Vector2(280.0, 210.0), Vector2(720.0, 320.0))

enum GameState {
	BATTLE,
	UPGRADES,
}

var rng := RandomNumberGenerator.new()
var run_state
var state: int = GameState.BATTLE
var round_time_left := 0.0
var pulse_charge := 0.0
var round_end_reason_key := ""
var active_hint_key := "hint.battle_idle"
var active_hint_params: Dictionary = {}

@onready var slimes_layer: Node2D = $Arena/Slimes
@onready var crystals_layer: Node2D = $Arena/Crystals
@onready var cursor_pulse = $Arena/CursorPulse
@onready var title_label: Label = $CanvasLayer/HUD/TopPanel/Margin/VBox/TitleLabel
@onready var phase_label: Label = $CanvasLayer/HUD/TopPanel/Margin/VBox/PhaseLabel
@onready var round_label: Label = $CanvasLayer/HUD/TopPanel/Margin/VBox/RoundLabel
@onready var timer_label: Label = $CanvasLayer/HUD/TopPanel/Margin/VBox/TimerLabel
@onready var crystal_label: Label = $CanvasLayer/HUD/TopPanel/Margin/VBox/CrystalLabel
@onready var slime_label: Label = $CanvasLayer/HUD/TopPanel/Margin/VBox/SlimeLabel
@onready var stat_label: Label = $CanvasLayer/HUD/TopPanel/Margin/VBox/StatLabel
@onready var hint_label: Label = $CanvasLayer/HUD/TopPanel/Margin/VBox/HintLabel
@onready var language_selector: OptionButton = $CanvasLayer/HUD/TopPanel/Margin/VBox/LanguageSelector
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
	_setup_language_selector()
	_refresh_language_selector()
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
	active_hint_key = "hint.battle_idle"
	active_hint_params = {}
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
	var slime_hp: float = float(spawn_profile["slime_hp"])
	var slime_speed: float = float(spawn_profile["slime_speed"])
	var slime_defs: Array[Dictionary] = run_state.get_slime_defs()

	for index in range(spawn_count):
		var slime: Slime = SLIME_SCENE.instantiate()
		var slime_data: Dictionary = slime_defs[rng.randi_range(0, slime_defs.size() - 1)]
		var spawn_position := Vector2(
			rng.randf_range(ARENA_RECT.position.x + 40.0, ARENA_RECT.end.x - 40.0),
			rng.randf_range(ARENA_RECT.position.y + 40.0, ARENA_RECT.end.y - 40.0)
		)
		var direction := Vector2.from_angle(rng.randf_range(0.0, TAU))
		slime.setup(
			ARENA_RECT,
			spawn_position,
			direction * slime_speed,
			Color.html(String(slime_data["color"])),
			slime_hp,
			String(slime_data["name_key"]),
			index + 1
		)
		slime.defeated.connect(_on_slime_defeated)
		slimes_layer.add_child(slime)


func _update_targeted_slimes() -> void:
	var hovered_names: Array[String] = []
	var mouse_position := get_global_mouse_position()
	var attack_radius := float(run_state.get_effective_stats()["attack_radius"])
	for slime in slimes_layer.get_children():
		var is_inside: bool = slime.global_position.distance_to(mouse_position) <= attack_radius
		slime.set_targeted(is_inside)
		if is_inside:
			hovered_names.append(slime.get_display_name())

	if hovered_names.is_empty():
		active_hint_key = "hint.battle_idle"
		active_hint_params = {}
	else:
		active_hint_key = "hint.battle_targeted"
		active_hint_params = {"targets": ", ".join(hovered_names)}


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
	for slime in slimes_layer.get_children():
		if slime.global_position.distance_to(mouse_position) <= attack_radius:
			slime.take_damage(pulse_damage)


func _finish_round(reason: String) -> void:
	if state != GameState.BATTLE:
		return

	state = GameState.UPGRADES
	round_end_reason_key = reason
	pulse_charge = 0.0
	cursor_pulse.set_progress(0.0)
	_clear_children(slimes_layer)
	_clear_targeted_slimes()
	skill_tree.show_panel(run_state.crystal_bank, run_state.get_purchased_skills(), run_state.get_effective_stats(), run_state.round_number)
	_update_hud()


func _on_slime_defeated(world_position: Vector2, slime_color: Color) -> void:
	var crystal_value := int(run_state.get_effective_stats()["crystal_value"])
	run_state.earn_crystals(crystal_value)

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
	var next_spawn_profile: Dictionary = run_state.get_next_spawn_profile()
	title_label.text = Localization.tr_key("title.game")
	if state == GameState.BATTLE:
		phase_label.text = Localization.tr_key("phase.battle")
		timer_label.text = Localization.tr_key("hud.time_left", {"seconds": "%.1f" % round_time_left})
	else:
		phase_label.text = Localization.tr_key("phase.upgrades")
		timer_label.text = Localization.tr_key(round_end_reason_key)

	round_label.text = Localization.tr_key("hud.round", {"round": run_state.round_number})
	crystal_label.text = Localization.tr_key("hud.crystals", {
		"current": run_state.crystal_bank,
		"total": run_state.total_crystals_earned,
	})
	slime_label.text = Localization.tr_key("hud.slimes", {
		"current": slimes_layer.get_child_count(),
		"next": int(next_spawn_profile["slime_count"]),
	})
	stat_label.text = Localization.tr_key("hud.stats", {
		"damage": int(round(float(effective_stats["pulse_damage"]))),
		"interval": "%.2f" % float(effective_stats["attack_interval"]),
		"radius": int(round(float(effective_stats["attack_radius"]))),
		"duration": int(round(float(effective_stats["round_duration"]))),
	})
	hint_label.text = Localization.tr_key(active_hint_key, active_hint_params)


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
	_update_hud()
