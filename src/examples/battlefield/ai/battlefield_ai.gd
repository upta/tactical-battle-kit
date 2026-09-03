class_name BattlefieldAi
extends AiController

## Kill what you can: shoot or cloud the target with the most expected kills
## (the cloud counts friends against it), melee the weakest reachable stack,
## otherwise close in, defend when cornered. One ply, an example.


func id() -> String:
	return "battlefield"


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
	var rules := state.ruleset as BattlefieldRuleset
	var unit := state.unit(action.unit_id)
	var enemies := state.enemies_on_field_of(unit.faction)
	match action.kind:
		"melee", "volley":
			var target := state.unit(action.target_unit_id())
			var expected: Dictionary = rules.expected_damage(state, unit, target, action.kind == "volley")
			var kills := float(expected["kills_min"] + expected["kills_max"]) * 0.5
			var finishing := 40.0 if int(expected["kills_min"]) >= BattlefieldRuleset.count_of(target) else 0.0
			return 100.0 + kills * 10.0 + float(expected["max"]) * 0.05 + finishing
		"death_cloud":
			var anchor: Vector2i = action.params.get("anchor", Vector2i.ZERO)
			var value := 0.0
			for cell: Vector2i in state.grid.bounded(state.grid.topology.cells_within(anchor, 1)):
				for hit: BattleUnit in state.units_at(cell):
					if hit == unit:
						continue
					var expected: Dictionary = rules.expected_damage(state, unit, hit, true)
					var kills := float(expected["kills_min"] + expected["kills_max"]) * 0.5
					value += (kills * 10.0 + 8.0) * (-2.0 if hit.faction == unit.faction else 1.0)
			return 100.0 + value
		"move":
			var cell := action.target_cell()
			var nearest := 99
			for enemy: BattleUnit in enemies:
				for enemy_cell: Vector2i in state.occupied_cells(enemy):
					nearest = mini(nearest, state.grid.distance(cell, enemy_cell))
			if BattlefieldRuleset.shots_left(unit) > 0:
				return 30.0 - absf(float(nearest) - 4.0) * 2.0
			return 50.0 - float(nearest) * 4.0
		"defend":
			return 20.0 if rules.has_adjacent_enemy(state, unit) else 5.0
		"wait":
			return 3.0
	return 0.0
