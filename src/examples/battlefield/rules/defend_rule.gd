class_name DefendRule
extends ActionRule

## Brace until this stack's next turn: extra defense through the damage model.


func id() -> String:
	return "defend"


func ends_activation() -> bool:
	return true


func can_use(_state: BattleState, unit: BattleUnit) -> bool:
	return not bool(unit.custom.get("defending", false))


func enumerate(_state: BattleState, unit: BattleUnit) -> Array[BattleAction]:
	return [make_action(unit)]


func apply(state: BattleState, engine: BattleEngine, action: BattleAction, _rng: BattleRng) -> void:
	var unit := state.unit(action.unit_id)
	unit.custom["defending"] = true
	engine.emit(state, {"type": "defended", "unit_id": unit.id})


func describe(_state: BattleState, _action: BattleAction) -> String:
	return "Defend"
