@abstract
class_name AiController
extends RefCounted

## A decision source for one faction. Asked once per decision with the turn
## it is deciding for; returns one of engine.legal_actions(state, turn), or
## null to end the turn early. The engine rejects anything else, and three
## rejections in a row end the turn.
##
## Games write their own. The kit ships RandomAi as a smoke driver and a
## balance baseline, nothing smarter. A human player is the same interface
## made asynchronous: the game runner awaits choose_async() when present.


func id() -> String:
	return "ai"


@abstract func choose(state: BattleState, engine: BattleEngine, turn: BattleTurn, rng: BattleRng) -> BattleAction
