class_name WaitRule
extends ActionRule

## End a unit's activation without doing anything. Always legal for a unit
## that can act, which is what guarantees a turn eventually runs out of
## actions under the default scheduler.


func id() -> String:
	return "wait"


func slot() -> String:
	return ""


func ends_activation() -> bool:
	return true


func enumerate(_state: BattleState, unit: BattleUnit) -> Array[BattleAction]:
	return [make_action(unit)]


func apply(state: BattleState, engine: BattleEngine, action: BattleAction, _rng: BattleRng) -> void:
	engine.emit(state, {"type": BattleEvents.WAITED, "unit_id": action.unit_id})


func describe(_state: BattleState, action: BattleAction) -> String:
	return "%s waits" % action.unit_id
