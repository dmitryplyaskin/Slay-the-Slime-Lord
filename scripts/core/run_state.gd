extends RefCounted
class_name RunState

const STAT_ADD := "add"
const STAT_MULTIPLY := "mul"
const STAT_OVERRIDE := "override"

var base_stats: Dictionary = {}
var round_scaling: Dictionary = {}
var combat_limits: Dictionary = {}
var skill_defs: Dictionary = {}
var slime_defs: Array[Dictionary] = []

var round_number := 0
var crystal_bank := 0
var total_crystals_earned := 0
var purchased_skills: Dictionary = {}


func setup(config: Dictionary) -> void:
	base_stats = config.get("base_stats", {}).duplicate(true)
	round_scaling = config.get("round_scaling", {}).duplicate(true)
	combat_limits = config.get("combat_limits", {}).duplicate(true)
	skill_defs = config.get("skill_defs", {}).duplicate(true)
	slime_defs = config.get("slime_defs", []).duplicate(true)


func start_next_round() -> void:
	round_number += 1


func get_effective_stats() -> Dictionary:
	var resolved := base_stats.duplicate(true)
	var additive: Dictionary = {}
	var multiplicative: Dictionary = {}
	var overrides: Dictionary = {}

	for skill_id in purchased_skills.keys():
		var skill_rank := _get_skill_rank(String(skill_id))
		if skill_rank <= 0:
			continue

		var skill_data: Dictionary = skill_defs.get(skill_id, {})
		for modifier_data in skill_data.get("modifiers", []):
			var modifier: Dictionary = modifier_data
			var stat_key := String(modifier.get("stat", ""))
			var mode := String(modifier.get("mode", STAT_ADD))
			var value := float(modifier.get("value", 0.0))
			match mode:
				STAT_ADD:
					additive[stat_key] = float(additive.get(stat_key, 0.0)) + value * float(skill_rank)
				STAT_MULTIPLY:
					multiplicative[stat_key] = float(multiplicative.get(stat_key, 1.0)) * pow(value, skill_rank)
				STAT_OVERRIDE:
					overrides[stat_key] = value

	for stat_key in additive.keys():
		resolved[stat_key] = float(resolved.get(stat_key, 0.0)) + float(additive[stat_key])

	for stat_key in multiplicative.keys():
		resolved[stat_key] = float(resolved.get(stat_key, 0.0)) * float(multiplicative[stat_key])

	for stat_key in overrides.keys():
		resolved[stat_key] = overrides[stat_key]

	var min_attack_interval := float(combat_limits.get("min_attack_interval", 0.0))
	if min_attack_interval > 0.0:
		resolved["attack_interval"] = maxf(min_attack_interval, float(resolved.get("attack_interval", min_attack_interval)))

	return resolved


func get_spawn_profile() -> Dictionary:
	return get_spawn_profile_for_round(round_number)


func get_spawn_profile_for_round(target_round: int) -> Dictionary:
	var stats: Dictionary = get_effective_stats()
	var round_index: int = maxi(target_round - 1, 0)
	var slime_count: int = int(stats.get("slime_count", 0.0))
	var bonus_slimes_per_round := int(round_scaling.get("bonus_slimes_per_round", 0))
	var bonus_slime_round_cap := int(round_scaling.get("bonus_slime_round_cap", 0))
	var capped_rounds: int = mini(round_index, bonus_slime_round_cap)

	return {
		"slime_count": slime_count + capped_rounds * bonus_slimes_per_round,
		"slime_hp": float(stats.get("slime_hp", 0.0)) + float(round_index) * float(round_scaling.get("slime_hp_per_round", 0.0)),
		"slime_speed": float(stats.get("slime_speed", 0.0)) + float(round_index) * float(round_scaling.get("slime_speed_per_round", 0.0)),
	}


func get_next_spawn_profile() -> Dictionary:
	return get_spawn_profile_for_round(round_number + 1)


func get_skill_defs() -> Dictionary:
	return skill_defs.duplicate(true)


func get_slime_defs() -> Array[Dictionary]:
	return slime_defs.duplicate(true)


func get_round_duration() -> float:
	return float(get_effective_stats().get("round_duration", 0.0))


func earn_crystals(amount: int) -> void:
	crystal_bank += amount
	total_crystals_earned += amount


func can_purchase(skill_id: String) -> bool:
	var skill_data: Dictionary = skill_defs.get(skill_id, {})
	if skill_data.is_empty():
		return false

	if _get_skill_rank(skill_id) >= _get_skill_max_rank(skill_data):
		return false

	for required_skill in skill_data.get("requires", []):
		if _get_skill_rank(String(required_skill)) <= 0:
			return false

	return crystal_bank >= get_skill_cost(skill_id)


func purchase_skill(skill_id: String) -> bool:
	if not can_purchase(skill_id):
		return false

	crystal_bank -= get_skill_cost(skill_id)
	purchased_skills[skill_id] = _get_skill_rank(skill_id) + 1
	return true


func get_purchased_skills() -> Dictionary:
	return purchased_skills.duplicate(true)


func get_skill_cost(skill_id: String) -> int:
	var skill_data: Dictionary = skill_defs.get(skill_id, {})
	if skill_data.is_empty():
		return 0

	var next_rank := _get_skill_rank(skill_id) + 1
	var rank_costs: Array = skill_data.get("rank_costs", [])
	if next_rank > 0 and next_rank <= rank_costs.size():
		return int(rank_costs[next_rank - 1])

	var base_cost := int(skill_data.get("cost", 0))
	var cost_per_rank := int(skill_data.get("cost_per_rank", 0))
	return base_cost + maxi(next_rank - 1, 0) * cost_per_rank


func get_skill_rank(skill_id: String) -> int:
	return _get_skill_rank(skill_id)


func get_skill_max_rank(skill_id: String) -> int:
	return _get_skill_max_rank(skill_defs.get(skill_id, {}))


func _get_skill_rank(skill_id: String) -> int:
	return int(purchased_skills.get(skill_id, 0))


func _get_skill_max_rank(skill_data: Dictionary) -> int:
	return maxi(1, int(skill_data.get("max_rank", 1)))
