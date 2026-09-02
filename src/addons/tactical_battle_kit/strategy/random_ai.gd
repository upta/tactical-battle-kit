class_name RandomAi
extends AiController

## Picks a uniformly random legal action, preferring anything over waiting.
## Works against any ruleset because it never looks at what an action means,
## which is exactly what makes it the smoke driver for a new ruleset and the
## baseline every balance suite compares against.


func id() -> String:
	return "random"


func choose(state: BattleState, engine: BattleEngine, turn: BattleTurn, rng: BattleRng) -> BattleAction:
	var actions := engine.legal_actions(state, turn)
	if actions.is_empty():
		return null
	var eager: Array[BattleAction] = []
	for action: BattleAction in actions:
		if action.kind != "wait":
			eager.append(action)
	if eager.is_empty():
		return rng.pick(actions)
	return rng.pick(eager)
