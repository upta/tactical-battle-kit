class_name RushAi
extends AiController

## The raiders' experimental opponent: attack whatever is in reach, else
## close on the nearest garrison unit, ignoring cover. Not shipped through
## OutpostRuleset.ai_scripts(); raider_pack.gd registers it for the suites
## that want to try it, which is how an AI outside the ruleset gets a name.


func id() -> String:
	return "rush"


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
			return 100.0 - float(target.hp) if target != null else 0.0
		"move":
			var nearest := 99
			for enemy: BattleUnit in state.enemies_on_field_of(unit.faction):
				nearest = mini(nearest, state.grid.distance(action.target_cell(), enemy.cell))
			return 50.0 - float(nearest)
	return 0.0
