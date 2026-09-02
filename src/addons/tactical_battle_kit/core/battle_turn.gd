class_name BattleTurn
extends RefCounted

## One decision window produced by the ruleset's scheduler: which faction
## decides, for which units, in which phase. Everything else a scheduler wants
## to remember about the turn goes in [member custom].

var faction: String = ""
var unit_ids: Array[String] = []
## Optional phase label ("movement", "fight", "card_select"); "" when unused.
var phase: String = ""
## Actions applied during this turn, in order.
var actions: Array[BattleAction] = []
var custom: Dictionary = {}


func _init(turn_faction: String = "", turn_unit_ids: Array[String] = [], turn_phase: String = "") -> void:
	faction = turn_faction
	unit_ids = turn_unit_ids.duplicate()
	phase = turn_phase


func includes(unit_id: String) -> bool:
	return unit_ids.has(unit_id)


func clone() -> BattleTurn:
	var copy := BattleTurn.new(faction, unit_ids, phase)
	copy.actions = actions.duplicate()
	copy.custom = custom.duplicate(true)
	return copy


func to_dict() -> Dictionary:
	return {
		"faction": faction,
		"unit_ids": unit_ids.duplicate(),
		"phase": phase,
		"action_count": actions.size(),
		"custom": DefOverrides.jsonify(custom),
	}
