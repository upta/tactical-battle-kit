class_name EntrenchRule
extends ActionRule

## Spend the action digging in. Halves incoming damage (see the damage model)
## until the unit moves, which the ruleset's on_event hook watches for.


func id() -> String:
	return "entrench"


func ends_activation() -> bool:
	return true


func can_use(_state: BattleState, unit: BattleUnit) -> bool:
	return not unit.def.has_tag("cavalry") and not bool(unit.custom.get("entrenched", false))


func enumerate(_state: BattleState, unit: BattleUnit) -> Array[BattleAction]:
	return [make_action(unit)]


func apply(state: BattleState, engine: BattleEngine, action: BattleAction, _rng: BattleRng) -> void:
	var unit := state.unit(action.unit_id)
	unit.custom["entrenched"] = true
	engine.emit(state, {"type": "entrenched", "unit_id": unit.id, "cell": BattleEvents.cell(unit.cell)})


func describe(_state: BattleState, action: BattleAction) -> String:
	return "%s digs in" % action.unit_id
