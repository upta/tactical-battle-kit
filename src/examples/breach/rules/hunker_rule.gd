class_name HunkerRule
extends ActionRule

## Spend the rest of the activation ducking: harder to hit until this unit's
## next turn or until it moves.


func id() -> String:
	return "hunker"


func ends_activation() -> bool:
	return true


func can_use(_state: BattleState, unit: BattleUnit) -> bool:
	return not bool(unit.custom.get("hunker", false))


func enumerate(_state: BattleState, unit: BattleUnit) -> Array[BattleAction]:
	return [make_action(unit)]


func apply(state: BattleState, engine: BattleEngine, action: BattleAction, _rng: BattleRng) -> void:
	var unit := state.unit(action.unit_id)
	unit.custom["hunker"] = true
	unit.custom.erase("overwatch")
	engine.emit(state, {"type": "hunkered", "unit_id": unit.id})


func describe(_state: BattleState, action: BattleAction) -> String:
	return "%s hunkers down" % action.unit_id
