class_name BattleRunner
extends Node

## Drives a battle inside a scene one decision at a time, walking the same
## engine primitives as BattleSimulator. A controller with choose_async() is
## awaited, which is the seam a human player plugs into; everything else is
## a plain AiController. step() advances through round and turn boundaries
## on its own so one call is one applied action (or the end of the battle).

signal state_changed(state: BattleState)
signal action_applied(action: BattleAction, events: Array[Dictionary])
signal battle_ended(outcome: BattleOutcome)

var state: BattleState = null
var engine: BattleEngine = null
var controllers: Dictionary[String, AiController] = {}

var _engine_rng: BattleRng
var _ai_rngs: Dictionary[String, BattleRng] = {}
var _turn: BattleTurn = null
var _started: bool = false
var _in_round: bool = false
var _stepping: bool = false
# Bumped by setup() and abort(): a step suspended on a human decision that
# resumes after a restart sees a stale generation and returns without
# touching the new battle.
var _generation: int = 0


## [param ai_ids] overrides the battle file's faction AI ids; anything left
## unresolved falls back to "random".
func setup(battle_state: BattleState, ai_ids: Dictionary[String, String] = {}, seed_value: int = 1) -> void:
	state = battle_state
	engine = BattleEngine.new(state.ruleset)
	var rng := BattleRng.new(seed_value)
	_engine_rng = rng.fork("engine")
	engine.rng = _engine_rng
	controllers.clear()
	_ai_rngs.clear()
	for faction: String in state.factions:
		var ai_id := str(ai_ids.get(faction, state.faction_ai.get(faction, "random")))
		var controller := AiRegistry.create(ai_id)
		controllers[faction] = controller if controller != null else RandomAi.new()
		_ai_rngs[faction] = rng.fork("ai:" + faction)
	_turn = null
	_started = false
	_in_round = false
	_stepping = false
	_generation += 1
	state_changed.emit(state)


## Invalidate a step suspended on a human decision before replacing the
## battle. The caller then resolves the human (submit(null)) so the coroutine
## unwinds; it returns false without acting on the new state.
func abort() -> void:
	_generation += 1
	_stepping = false


func set_controller(faction: String, controller: AiController) -> void:
	controllers[faction] = controller


func is_running() -> bool:
	return state != null and not state.ended


## Advance until one action is applied or the battle ends. Returns true while
## the battle is still running afterwards.
func step() -> bool:
	if state == null or state.ended or _stepping:
		return false
	_stepping = true
	var generation := _generation
	var applied := false
	while not applied and not state.ended:
		if not _started:
			engine.start_battle(state)
			_started = true
			continue
		if not _in_round:
			engine.begin_round(state)
			_in_round = true
			continue
		if _turn == null:
			_turn = engine.next_turn(state)
			if _turn == null:
				engine.end_round(state)
				_in_round = false
			continue
		if engine.is_turn_over(state, _turn):
			engine.end_turn(state, _turn)
			_turn = null
			continue
		var controller: AiController = controllers.get(_turn.faction)
		var action: BattleAction = null
		if controller != null and controller.has_method("choose_async"):
			action = await controller.call("choose_async", state, engine, _turn, _ai_rngs[_turn.faction])
			if generation != _generation:
				return false
		elif controller != null:
			action = controller.choose(state, engine, _turn, _ai_rngs[_turn.faction])
		if action == null:
			engine.end_turn(state, _turn)
			_turn = null
			continue
		var events := engine.apply(state, action, _engine_rng)
		applied = true
		action_applied.emit(action, events)
	_stepping = false
	state_changed.emit(state)
	if state.ended:
		battle_ended.emit(state.outcome)
	return not state.ended


func play_to_end(max_steps: int = 10000) -> void:
	var steps := 0
	while steps < max_steps and await step():
		steps += 1
