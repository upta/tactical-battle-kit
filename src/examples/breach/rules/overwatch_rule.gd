class_name OverwatchRule
extends ActionRule

## Spend the rest of the activation watching: the first enemy to step into
## line of sight before this unit's next turn eats a reaction shot.


func id() -> String:
	return "overwatch"


func ends_activation() -> bool:
	return true


func can_use(_state: BattleState, unit: BattleUnit) -> bool:
	return not bool(unit.custom.get("overwatch", false))


func enumerate(_state: BattleState, unit: BattleUnit) -> Array[BattleAction]:
	return [make_action(unit)]


func apply(state: BattleState, engine: BattleEngine, action: BattleAction, _rng: BattleRng) -> void:
	var unit := state.unit(action.unit_id)
	unit.custom["overwatch"] = true
	unit.custom.erase("hunker")
	engine.emit(state, {"type": "overwatch_set", "unit_id": unit.id})


func describe(_state: BattleState, action: BattleAction) -> String:
	return "%s goes on overwatch" % action.unit_id
