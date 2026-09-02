class_name FrontierAi
extends AiController

## Shoot what you can, close to musket range otherwise, dig in when the
## enemy is near and nothing is in range, hold cannon back. One ply, no
## lookahead; an example of scoring a ruleset with an unusual action set.


func id() -> String:
	return "frontier"


func choose(state: BattleState, engine: BattleEngine, turn: BattleTurn, _rng: BattleRng) -> BattleAction:
	var best: BattleAction = null
	var best_score := -INF
	for action: BattleAction in engine.legal_actions(state, turn):
		var score := _score(state, action)
		if score > best_score:
			best_score = score
			best = action
	return best


func _score(state: BattleState, action: BattleAction) -> float:
	var unit := state.unit(action.unit_id)
	var nearest_now := _nearest_enemy_distance(state, unit, unit.cell)
	match action.kind:
		"attack":
			var target := state.unit(action.target_unit_id())
			var rear_bonus := 10.0 if _hits_rear(state, unit, target) else 0.0
			return 100.0 + rear_bonus - float(target.hp) + (15.0 if target.def.has_tag("artillery") else 0.0)
		"move":
			var there := _nearest_enemy_distance(state, unit, action.target_cell())
			var wanted := unit.def.range_max
			var gap := absi(there - wanted)
			var cover := state.grid.terrain_at(action.target_cell()).defense_bonus * 6.0
			if unit.def.has_tag("artillery") and there < unit.def.range_min:
				return -10.0
			return 40.0 - float(gap) * 4.0 + cover - (float(nearest_now - there) if there > wanted else 0.0)
		"entrench":
			# Dig in only when a volley is coming next turn; a starving army
			# that waits loses, so it never digs in.
			var rules := state.ruleset as FrontierRuleset
			if rules.is_starving(state, unit.faction):
				return 1.0
			return 45.0 if nearest_now <= 2 else 5.0
	return 0.0


## Walking distance to the nearest enemy over terrain this unit can enter,
## so a river with two fords is a detour, not an invisible wall. Multi-source
## breadth-first search from every enemy, cached per decision by event count.
var _field_key: String = ""
var _field: Dictionary[Vector2i, int] = {}


func _nearest_enemy_distance(state: BattleState, unit: BattleUnit, from: Vector2i) -> int:
	var key := "%d:%d:%s" % [state.get_instance_id(), state.events.size(), unit.id]
	if key != _field_key:
		_field_key = key
		_field = _enemy_distance_field(state, unit)
	return _field.get(from, 99)


func _enemy_distance_field(state: BattleState, unit: BattleUnit) -> Dictionary[Vector2i, int]:
	var field: Dictionary[Vector2i, int] = {}
	var frontier: Array[Vector2i] = []
	for enemy: BattleUnit in state.enemies_on_field_of(unit.faction):
		field[enemy.cell] = 0
		frontier.append(enemy.cell)
	while not frontier.is_empty():
		var current: Vector2i = frontier.pop_front()
		var next_distance: int = field[current] + 1
		for neighbor: Vector2i in state.grid.neighbors(current):
			if field.has(neighbor):
				continue
			if state.ruleset.movement_cost(state, unit, neighbor) < 0:
				continue
			field[neighbor] = next_distance
			frontier.append(neighbor)
	return field


func _hits_rear(state: BattleState, attacker: BattleUnit, defender: BattleUnit) -> bool:
	var topology := state.grid.topology
	if defender.facing < 0:
		return false
	var incoming := topology.direction_to(defender.cell, attacker.cell)
	return topology.arc(defender.facing, incoming) >= topology.direction_count() / 2
