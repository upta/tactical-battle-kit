class_name AiRegistry
extends RefCounted

## Names AIs so battle files and sim suites can refer to them by id. A
## ruleset registers its own through ai_scripts() when a battle loads; an
## external pack registers through the sim CLI's --register script.
##
## Holds scripts, never closures: a static dictionary of lambdas keeps script
## instances alive past engine shutdown and crashes the process at exit.

static var _scripts: Dictionary[String, GDScript] = {}


static func register(ai_id: String, script: GDScript) -> void:
	_scripts[ai_id] = script


static func create(ai_id: String) -> AiController:
	_ensure_builtins()
	var script: GDScript = _scripts.get(ai_id)
	if script == null:
		push_error("No AI registered with id '%s'. Known: %s" % [ai_id, ", ".join(ids())])
		return null
	var instance: Variant = script.new()
	if not (instance is AiController):
		push_error("AI '%s' is not an AiController." % ai_id)
		return null
	return instance


static func has(ai_id: String) -> bool:
	_ensure_builtins()
	return _scripts.has(ai_id)


static func ids() -> Array[String]:
	_ensure_builtins()
	var result: Array[String] = []
	result.assign(_scripts.keys())
	result.sort()
	return result


## Drop every registration. Call before quitting a headless run so nothing
## static outlives the scripts it references.
static func clear() -> void:
	_scripts.clear()


static func _ensure_builtins() -> void:
	if not _scripts.has("random"):
		_scripts["random"] = RandomAi
