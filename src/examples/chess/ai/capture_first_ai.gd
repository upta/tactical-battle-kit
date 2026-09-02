class_name CaptureFirstAi
extends AiController

## Takes the most valuable capture available, otherwise a random move. Enough
## to beat random play and to show a chess AI needs nothing from the kit but
## legal_actions().


func id() -> String:
	return "capture_first"


func choose(state: BattleState, engine: BattleEngine, turn: BattleTurn, rng: BattleRng) -> BattleAction:
	var actions := engine.legal_actions(state, turn)
	if actions.is_empty():
		return null
	var best: BattleAction = null
	var best_value := 0
	for action: BattleAction in actions:
		var victim_id := str(action.params.get("captures", ""))
		if victim_id.is_empty():
			continue
		var victim := state.unit(victim_id)
		var value: int = ChessRuleset.PIECE_VALUES.get(ChessRuleset.piece_kind(victim), 0)
		if value > best_value:
			best_value = value
			best = action
	if best != null:
		return best
	return rng.pick(actions)
