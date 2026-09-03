class_name DelayRule
extends ActionRule

## Heroes' Wait: give up this turn and act again at the end of the round.
## The scheduler drains the delayed queue after the initiative order.


func id() -> String:
	return "wait"


func ends_activation() -> bool:
	return true


func can_use(_state: BattleState, unit: BattleUnit) -> bool:
	return not bool(unit.custom.get("delayed", false))


func enumerate(_state: BattleState, unit: BattleUnit) -> Array[BattleAction]:
	return [make_action(unit)]


func apply(state: BattleState, engine: BattleEngine, action: BattleAction, _rng: BattleRng) -> void:
	var unit := state.unit(action.unit_id)
	unit.custom["delayed"] = true
	var queue: Array = state.custom.get(BattlefieldRuleset.DELAYED_KEY, [])
	queue.append(unit.id)
	state.custom[BattlefieldRuleset.DELAYED_KEY] = queue
	engine.emit(state, {"type": BattleEvents.WAITED, "unit_id": unit.id})


func describe(_state: BattleState, _action: BattleAction) -> String:
	return "Wait (act at the end of the round)"
