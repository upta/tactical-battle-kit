class_name HumanController
extends AiController

## A decision source that waits for a person. BattleRunner awaits
## choose_async(); this emits decision_requested with the legal actions and
## suspends until submit() is called with one of them (or null to end the
## turn). Lives in view/ because it only makes sense next to a UI: choose()
## returns null, so a sim that is handed one ends every turn immediately.

signal decision_requested(turn: BattleTurn, legal: Array[BattleAction])
signal decided(action: BattleAction)

var _pending: Array[BattleAction] = []
var _turn: BattleTurn = null
var _waiting: bool = false


func id() -> String:
	return "human"


func choose(_state: BattleState, _engine: BattleEngine, _turn: BattleTurn, _rng: BattleRng) -> BattleAction:
	push_warning("HumanController.choose() called synchronously; a human cannot answer a sim. Ending the turn.")
	return null


func choose_async(state: BattleState, engine: BattleEngine, turn: BattleTurn, _rng: BattleRng) -> BattleAction:
	_pending = engine.legal_actions(state, turn)
	_turn = turn
	_waiting = true
	decision_requested.emit(turn, _pending)
	var action: BattleAction = await decided
	_waiting = false
	_pending = []
	_turn = null
	return action


## Resolve the pending decision. null ends the turn. An action that is not
## in the pending list is refused so the engine never sees an invented one.
func submit(action: BattleAction) -> void:
	if not _waiting:
		return
	if action != null and not _is_pending(action):
		push_warning("HumanController.submit(): action is not among the legal choices.")
		return
	decided.emit(action)


func is_waiting() -> bool:
	return _waiting


func pending() -> Array[BattleAction]:
	return _pending.duplicate()


func pending_for(unit_id: String) -> Array[BattleAction]:
	var result: Array[BattleAction] = []
	for action: BattleAction in _pending:
		if action.unit_id == unit_id:
			result.append(action)
	return result


func turn() -> BattleTurn:
	return _turn


func _is_pending(action: BattleAction) -> bool:
	for candidate: BattleAction in _pending:
		if candidate.equals(action):
			return true
	return false
