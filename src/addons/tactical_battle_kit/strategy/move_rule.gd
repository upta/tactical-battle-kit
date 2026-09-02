class_name MoveRule
extends ActionRule

## Default movement: budget-based through the ruleset's movement_cost,
## applied one step at a time so hooks can interrupt it (overwatch,
## opportunity attacks), updating facing when the ruleset uses it. With
## single_move() false a unit keeps moving until its budget is spent.


func id() -> String:
	return "move"


func slot() -> String:
	return "move"


func spends(state: BattleState, unit: BattleUnit, _action: BattleAction) -> Array[String]:
	var result: Array[String] = []
	if state.ruleset.single_move() or remaining_budget(state, unit) <= 0:
		result.append("move")
	return result


func remaining_budget(state: BattleState, unit: BattleUnit) -> int:
	return state.ruleset.move_budget(state, unit) - unit.move_used


func enumerate(state: BattleState, unit: BattleUnit) -> Array[BattleAction]:
	var actions: Array[BattleAction] = []
	var budget := remaining_budget(state, unit)
	if budget <= 0:
		return actions
	var reach := Pathfinder.reachable(state, unit, budget)
	for cell: Vector2i in reach.keys():
		var info: Dictionary = reach[cell]
		actions.append(make_action(unit, {
			"target_cell": cell,
			"path": info["path"],
			"cost": info["cost"],
		}))
	return actions


func apply(state: BattleState, engine: BattleEngine, action: BattleAction, _rng: BattleRng) -> void:
	var unit := state.unit(action.unit_id)
	var origin := unit.cell
	var traversed: Array[Vector2i] = []
	var cost := 0
	var interrupted := false
	var topology := state.grid.topology
	for step: Vector2i in action.path():
		var previous := unit.cell
		cost += maxi(Pathfinder.step_cost(state, unit, step), 0)
		unit.cell = step
		traversed.append(step)
		if state.ruleset.uses_facing():
			unit.facing = topology.direction_to(previous, step)
		engine.emit(state, {
			"type": BattleEvents.STEPPED,
			"unit_id": unit.id,
			"from": BattleEvents.cell(previous),
			"to": BattleEvents.cell(step),
		})
		if engine.consume_interrupt(unit.id) or not unit.is_on_field():
			interrupted = true
			break
	unit.move_used += cost
	engine.emit(state, {
		"type": BattleEvents.MOVED,
		"unit_id": unit.id,
		"from": BattleEvents.cell(origin),
		"to": BattleEvents.cell(unit.cell),
		"path": BattleEvents.cells(traversed),
		"cost": cost,
		"interrupted": interrupted,
	})


func describe(_state: BattleState, action: BattleAction) -> String:
	var cell := action.target_cell()
	return "%s moves to (%d,%d)" % [action.unit_id, cell.x, cell.y]
