extends Node

const BALANCE_PATH := "res://data/balance.json"
const SKILLS_PATH := "res://data/skills.json"
const SLIMES_PATH := "res://data/slimes.json"
const LANGUAGES_PATH := "res://data/languages.json"

var balance_data: Dictionary = {}
var skills_data: Array[Dictionary] = []
var slimes_data: Array[Dictionary] = []
var languages_data: Array[Dictionary] = []


func _ready() -> void:
	reload()


func reload() -> void:
	balance_data = _load_json(BALANCE_PATH)
	skills_data = _load_dictionary_array(SKILLS_PATH, "skills")
	slimes_data = _load_dictionary_array(SLIMES_PATH, "slimes")
	languages_data = _load_dictionary_array(LANGUAGES_PATH, "languages")


func get_balance() -> Dictionary:
	return balance_data.duplicate(true)


func get_player_base_stats() -> Dictionary:
	return balance_data.get("player_stats", {}).duplicate(true)


func get_round_scaling() -> Dictionary:
	return balance_data.get("round_scaling", {}).duplicate(true)


func get_combat_limits() -> Dictionary:
	return balance_data.get("combat_limits", {}).duplicate(true)


func get_skills() -> Dictionary:
	var result: Dictionary = {}
	for skill_data in skills_data:
		result[String(skill_data.get("id", ""))] = (skill_data as Dictionary).duplicate(true)
	return result


func get_slimes() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for slime_data in slimes_data:
		result.append((slime_data as Dictionary).duplicate(true))
	return result


func get_languages() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for language_data in languages_data:
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


func _load_dictionary_array(path: String, key: String) -> Array[Dictionary]:
	var file_data := _load_json(path)
	var result: Array[Dictionary] = []
	for item in file_data.get(key, []):
		if item is Dictionary:
			result.append((item as Dictionary).duplicate(true))
	return result
