extends Node

const CONTENT_PATH := "res://data/game_content.json"

var raw_data: Dictionary = {}


func _ready() -> void:
	reload()


func reload() -> void:
	raw_data = _load_json(CONTENT_PATH)


func get_balance() -> Dictionary:
	return raw_data.get("balance", {}).duplicate(true)


func get_player_base_stats() -> Dictionary:
	return raw_data.get("balance", {}).get("player_stats", {}).duplicate(true)


func get_round_scaling() -> Dictionary:
	return raw_data.get("balance", {}).get("round_scaling", {}).duplicate(true)


func get_combat_limits() -> Dictionary:
	return raw_data.get("balance", {}).get("combat_limits", {}).duplicate(true)


func get_skills() -> Dictionary:
	var result: Dictionary = {}
	for skill_data in raw_data.get("skills", []):
		result[String(skill_data.get("id", ""))] = (skill_data as Dictionary).duplicate(true)
	return result


func get_slimes() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for slime_data in raw_data.get("slimes", []):
		result.append((slime_data as Dictionary).duplicate(true))
	return result


func get_languages() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for language_data in raw_data.get("languages", []):
		result.append((language_data as Dictionary).duplicate(true))
	return result


func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Unable to open content file: %s" % path)
		return {}

	var json := JSON.new()
	var parse_result := json.parse(file.get_as_text())
	if parse_result != OK:
		push_error("Failed to parse JSON: %s" % path)
		return {}

	var data: Variant = json.data
	if data is Dictionary:
		return (data as Dictionary).duplicate(true)
	return {}
