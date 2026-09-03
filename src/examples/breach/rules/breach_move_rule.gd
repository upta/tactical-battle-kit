class_name BreachMoveRule
extends MoveRule

## Action-point movement: a move within one point's worth of cells spends
## one point, anything longer is a dash and spends both. Distance accounting
## resets per point, which is why spends() zeroes move_used; the kit's
## budget model is distance-per-activation and this ruleset is points.


func spends(_state: BattleState, unit: BattleUnit, action: BattleAction) -> Array[String]:
	var cost := int(action.params.get("cost", 0))
	var result: Array[String] = []
	var points := 2 if cost > unit.def.move else 1
	for slot: String in ["ap1", "ap2"]:
		if points == 0:
			break
		if not unit.has_spent(slot):
			result.append(slot)
			points -= 1
	unit.move_used = 0
	return result


func describe(_state: BattleState, action: BattleAction) -> String:
	var cell := action.target_cell()
	var dash := " (dash)" if int(action.params.get("cost", 0)) > 4 else ""
	return "%s moves to (%d,%d)%s" % [action.unit_id, cell.x, cell.y, dash]
