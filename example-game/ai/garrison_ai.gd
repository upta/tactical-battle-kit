class_name GarrisonAi
extends AiController

## One-ply scorer for the outpost's defenders: finish a kill if one is on
## offer, otherwise hit the weakest enemy in reach, otherwise step toward
## the nearest raider while preferring cover, and wait only when nothing
## else is legal. Registered by OutpostRuleset.ai_scripts() as "garrison".


func id() -> String:
	return "garrison"


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
			if target == null:
				return 0.0
			var kill_bonus := 50.0 if target.hp <= unit.def.attack else 0.0
			return 100.0 + kill_bonus - float(target.hp)
		"move":
			var nearest := 99
			for enemy: BattleUnit in state.enemies_on_field_of(unit.faction):
				nearest = mini(nearest, state.grid.distance(action.target_cell(), enemy.cell))
			var terrain := state.grid.terrain_at(action.target_cell())
			return 50.0 - float(nearest) + terrain.defense_bonus * 10.0
	return 0.0
