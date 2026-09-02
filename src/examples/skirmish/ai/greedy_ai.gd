class_name GreedyAi
extends AiController

## One-ply scoring: finish weak enemies, otherwise close distance, heal when
## someone nearby is hurt, wait last. Knows the skirmish action kinds and
## scores anything else at zero. An example, not a recommendation.


func id() -> String:
	return "greedy"


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
	match action.kind:
		"attack":
			var target := state.unit(action.target_unit_id())
			var kill_bonus := 50.0 if target.hp <= unit.def.attack else 0.0
			return 100.0 + kill_bonus - float(target.hp)
		"move":
			var nearest := 99
			for enemy: BattleUnit in state.enemies_on_field_of(unit.faction):
				nearest = mini(nearest, state.grid.distance(action.target_cell(), enemy.cell))
			var terrain := state.grid.terrain_at(action.target_cell())
			return 50.0 - float(nearest) + terrain.defense_bonus * 4.0
		"heal_aura":
			var hurt := 0
			for ally: BattleUnit in state.units_on_field_of(unit.faction):
				if ally != unit and ally.hp < ally.def.max_hp and state.distance_between(unit, ally) <= 2:
					hurt += 1
			return 60.0 + float(hurt) * 5.0 if hurt > 0 else -1.0
	return 0.0
