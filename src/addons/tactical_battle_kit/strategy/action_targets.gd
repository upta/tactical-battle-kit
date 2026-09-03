class_name ActionTargets
extends RefCounted

## Click semantics for any presentation, derived from action params alone:
## an action with target_unit_id or target_cell points at a cell, an anchor
## away from the actor points at a cell, and anything else is untargeted
## (wait, entrench, a self-centered aura). A view resolves a click to a cell
## its own way (BattleView.cell_at_position, TileMapLayer.local_to_map) and
## asks here what that cell means for the selected unit.


## Cell an action targets on the board, or (-1, -1) for an untargeted one.
static func target_cell_of(state: BattleState, action: BattleAction) -> Vector2i:
	if action.params.has("target_unit_id"):
		var target := state.unit(action.target_unit_id())
		if target != null:
			return target.cell
	if action.params.has("target_cell"):
		return action.target_cell()
	if action.params.has("anchor"):
		var actor := state.unit(action.unit_id)
		var anchor: Vector2i = action.params["anchor"]
		if actor == null or anchor != actor.cell:
			return anchor
	return Vector2i(-1, -1)


static func for_unit(actions: Array[BattleAction], unit_id: String) -> Array[BattleAction]:
	var result: Array[BattleAction] = []
	for action: BattleAction in actions:
		if action.unit_id == unit_id:
			result.append(action)
	return result


## Units with at least one legal action, in first-seen order.
static func actionable_unit_ids(actions: Array[BattleAction]) -> Array[String]:
	var ids: Array[String] = []
	for action: BattleAction in actions:
		if not ids.has(action.unit_id):
			ids.append(action.unit_id)
	return ids


## The selected unit's actions that target [param cell].
static func matches_at(state: BattleState, actions: Array[BattleAction], unit_id: String, cell: Vector2i) -> Array[BattleAction]:
	var result: Array[BattleAction] = []
	for action: BattleAction in for_unit(actions, unit_id):
		if target_cell_of(state, action) == cell:
			result.append(action)
	return result


## The selected unit's untargeted actions, one per kind (button material).
static func untargeted(state: BattleState, actions: Array[BattleAction], unit_id: String) -> Array[BattleAction]:
	var result: Array[BattleAction] = []
	var seen: Dictionary[String, bool] = {}
	for action: BattleAction in for_unit(actions, unit_id):
		if target_cell_of(state, action).x >= 0 or seen.has(action.kind):
			continue
		seen[action.kind] = true
		result.append(action)
	return result
