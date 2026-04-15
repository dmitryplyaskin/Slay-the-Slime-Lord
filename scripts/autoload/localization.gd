extends Node

signal locale_changed(new_locale: String)

const DEFAULT_LOCALE := "ru"
const LOCALE_PATHS := {
	"ru": "res://data/localization/ru.json",
	"en": "res://data/localization/en.json",
}

var current_locale := DEFAULT_LOCALE
var dictionaries: Dictionary = {}


func _ready() -> void:
	for locale in LOCALE_PATHS.keys():
		dictionaries[locale] = _load_json(String(LOCALE_PATHS[locale]))
	set_locale(DEFAULT_LOCALE)


func set_locale(locale: String) -> void:
	var next_locale := locale
	if not dictionaries.has(next_locale):
		next_locale = DEFAULT_LOCALE
	if current_locale == next_locale and not dictionaries.is_empty():
		return

	current_locale = next_locale
	TranslationServer.set_locale(current_locale)
	locale_changed.emit(current_locale)


func get_locale() -> String:
	return current_locale


func get_language_label(locale: String) -> String:
	return tr_key("language.%s" % locale)


func tr_key(key: String, params: Dictionary = {}) -> String:
	var locale_dict: Dictionary = dictionaries.get(current_locale, {})
	var fallback_dict: Dictionary = dictionaries.get(DEFAULT_LOCALE, {})
	var text := String(locale_dict.get(key, fallback_dict.get(key, key)))
	for param_key in params.keys():
		text = text.replace("{%s}" % String(param_key), str(params[param_key]))
	return text


func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Unable to open localization file: %s" % path)
		return {}

	var json := JSON.new()
	var parse_result := json.parse(file.get_as_text())
	if parse_result != OK:
		push_error("Failed to parse localization JSON: %s" % path)
		return {}

	var data: Variant = json.data
	if data is Dictionary:
		return (data as Dictionary).duplicate(true)
	return {}
