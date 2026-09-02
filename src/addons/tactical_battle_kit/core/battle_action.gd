class_name BattleAction
extends RefCounted

## What a unit does with one decision. Built by an [ActionRule]'s enumerate()
## and handed back by an AI; the engine validates it against the legal list
## before applying, so an AI that invents an action gets a rejection, not a
## corrupted battle. [member kind] is the rule id; [member params] is whatever
## that rule needs (target_cell, target_unit_id, path, direction, ...).

var kind: String = ""
var unit_id: String = ""
var params: Dictionary = {}


func _init(action_kind: String = "", actor_id: String = "", action_params: Dictionary = {}) -> void:
	kind = action_kind
	unit_id = actor_id
	params = action_params


func target_cell() -> Vector2i:
	return params.get("target_cell", Vector2i.ZERO)


func target_unit_id() -> String:
	return str(params.get("target_unit_id", ""))


func path() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if params.has("path"):
		result.assign(params["path"])
	return result


## Two actions are the same decision when kind, actor and params match.
func equals(other: BattleAction) -> bool:
	return other != null and kind == other.kind and unit_id == other.unit_id and params == other.params


func to_dict() -> Dictionary:
	return {
		"kind": kind,
		"unit_id": unit_id,
		"params": DefOverrides.jsonify(params),
	}
