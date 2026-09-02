class_name BattleEngine
extends RefCounted

## The only thing that mutates a [BattleState], and it holds no game logic:
## it dispatches actions to the ruleset's [ActionRule]s, keeps slot and turn
## bookkeeping, logs events, runs hooks, and polls the outcome after every
## applied action. Hooks may call back into apply(), remove_from_field(),
## interrupt_move() and end_battle(); apply is re-entrant.
##
## The battle loop itself is composed by the caller from the primitives
## start_battle / begin_round / next_turn / is_turn_over / end_turn /
## end_round, so a synchronous simulator and an awaiting game runner share
## the same sequence.

var ruleset: BattleRuleset
var rules: Array[ActionRule] = []
var damage_model: DamageModel
## Safety cap so a broken AI or ruleset cannot spin a turn forever.
var max_actions_per_turn: int = 200
## Consecutive rejections before the engine ends the turn on the AI's behalf.
var max_consecutive_rejections: int = 3

var _rules_by_kind: Dictionary[String, ActionRule] = {}
var _interrupts: Dictionary[String, bool] = {}
var _consecutive_rejections: int = 0
# Legal actions per unit, keyed by state instance and event count. Every
# mutation the engine makes emits at least one event, so the key changes
# whenever the answer could; a cloned state has its own instance id.
var _legal_cache: Dictionary[String, Array] = {}
const _LEGAL_CACHE_LIMIT := 256


func _init(battle_ruleset: BattleRuleset) -> void:
	ruleset = battle_ruleset
	rules = ruleset.action_rules()
	for rule: ActionRule in rules:
		if _rules_by_kind.has(rule.id()):
			push_error("Ruleset '%s' declares two action rules with id '%s'." % [ruleset.id(), rule.id()])
		_rules_by_kind[rule.id()] = rule
	damage_model = ruleset.damage_model()


func rule(kind: String) -> ActionRule:
	return _rules_by_kind.get(kind)


# --- Legality ---


## Every action available to the units in [param turn] that can still act.
func legal_actions(state: BattleState, turn: BattleTurn) -> Array[BattleAction]:
	var actions: Array[BattleAction] = []
	for unit_id: String in turn.unit_ids:
		var unit := state.unit(unit_id)
		if unit == null:
			continue
		actions.append_array(legal_actions_for_unit(state, unit))
	return actions


func legal_actions_for_unit(state: BattleState, unit: BattleUnit) -> Array[BattleAction]:
	var key := "%d:%d:%s" % [state.get_instance_id(), state.events.size(), unit.id]
	if _legal_cache.has(key):
		var cached: Array[BattleAction] = []
		cached.assign(_legal_cache[key])
		return cached
	var actions: Array[BattleAction] = []
	if not state.ended and ruleset.unit_can_act(state, unit):
		for action_rule: ActionRule in rules:
			var slot := action_rule.slot()
			if slot != "" and unit.has_spent(slot):
				continue
			if not action_rule.can_use(state, unit):
				continue
			actions.append_array(action_rule.enumerate(state, unit))
	if _legal_cache.size() >= _LEGAL_CACHE_LIMIT:
		_legal_cache.clear()
	_legal_cache[key] = actions.duplicate()
	return actions


# --- Apply ---


## Validate and apply one action. Returns the events it produced (also
## appended to state.events). An illegal action produces one "rejected" event
## and changes nothing else.
func apply(state: BattleState, action: BattleAction, rng: BattleRng) -> Array[Dictionary]:
	var first_event := state.events.size()
	var rejection := _rejection_reason(state, action)
	if rejection != "":
		_consecutive_rejections += 1
		emit(state, {
			"type": BattleEvents.REJECTED,
			"unit_id": action.unit_id if action != null else "",
			"action": action.to_dict() if action != null else {},
			"reason": rejection,
		})
		return _events_since(state, first_event)

	_consecutive_rejections = 0
	var unit := state.unit(action.unit_id)
	var action_rule := rule(action.kind)
	action_rule.apply(state, self, action, rng)

	for slot: String in action_rule.spends(state, unit, action):
		unit.spend(slot)
	if action_rule.ends_activation():
		for slot: String in ruleset.activation_slots():
			unit.spend(slot)
	if state.current_turn != null:
		state.current_turn.actions.append(action)

	poll_outcome(state)
	return _events_since(state, first_event)


func _rejection_reason(state: BattleState, action: BattleAction) -> String:
	if action == null:
		return "no_action"
	if state.ended:
		return "battle_ended"
	var unit := state.unit(action.unit_id)
	if unit == null:
		return "unknown_unit"
	if not unit.is_on_field():
		return "unit_off_field"
	if state.current_turn != null and not state.current_turn.includes(unit.id):
		return "not_in_turn"
	if rule(action.kind) == null:
		return "unknown_kind"
	for legal: BattleAction in legal_actions_for_unit(state, unit):
		if legal.equals(action):
			return ""
	return "illegal"


func _events_since(state: BattleState, first_event: int) -> Array[Dictionary]:
	var produced: Array[Dictionary] = []
	produced.assign(state.events.slice(first_event))
	return produced


## Log an event and run the ruleset's on_event hook for it.
func emit(state: BattleState, event: Dictionary) -> void:
	state.log_event(event)
	ruleset.on_event(state, self, event)


# --- Battle loop primitives ---


func start_battle(state: BattleState) -> void:
	state.round_number = 0
	state.ended = false
	state.outcome = null
	_interrupts.clear()
	_consecutive_rejections = 0
	emit(state, {"type": BattleEvents.BATTLE_STARTED})
	ruleset.on_battle_started(state, self)
	poll_outcome(state)


func begin_round(state: BattleState) -> void:
	state.round_number += 1
	state.current_turn = null
	ruleset.begin_round(state)
	emit(state, {"type": BattleEvents.ROUND_STARTED})
	ruleset.on_round_started(state, self)


## The next turn this round, or null when the round is over.
func next_turn(state: BattleState) -> BattleTurn:
	if state.ended:
		return null
	var turn := ruleset.next_turn(state)
	state.current_turn = turn
	if turn == null:
		return null
	_consecutive_rejections = 0
	emit(state, {
		"type": BattleEvents.TURN_STARTED,
		"faction": turn.faction,
		"phase": turn.phase,
		"unit_ids": turn.unit_ids.duplicate(),
	})
	ruleset.on_turn_started(state, self, turn)
	return turn


func is_turn_over(state: BattleState, turn: BattleTurn) -> bool:
	if state.ended:
		return true
	if turn.actions.size() >= max_actions_per_turn:
		return true
	if _consecutive_rejections >= max_consecutive_rejections:
		return true
	return ruleset.is_turn_over(state, self, turn)


func end_turn(state: BattleState, turn: BattleTurn) -> void:
	ruleset.on_turn_ended(state, self, turn)
	emit(state, {
		"type": BattleEvents.TURN_ENDED,
		"faction": turn.faction,
		"phase": turn.phase,
		"action_count": turn.actions.size(),
	})
	state.current_turn = null
	poll_outcome(state)


func end_round(state: BattleState) -> void:
	emit(state, {"type": BattleEvents.ROUND_ENDED})
	poll_outcome(state)
	if not state.ended and state.round_number >= ruleset.max_rounds():
		end_battle(state, "", "max_rounds")


# --- State transitions available to rules and hooks ---


## Ask the ruleset whether the battle is decided; end it if so.
func poll_outcome(state: BattleState) -> bool:
	if state.ended:
		return true
	var outcome := ruleset.check_outcome(state)
	if outcome == null:
		return false
	end_battle(state, outcome.winner, outcome.reason)
	return true


func end_battle(state: BattleState, winner: String, reason: String) -> void:
	if state.ended:
		return
	state.ended = true
	state.outcome = BattleOutcome.new(winner, reason)
	emit(state, {"type": BattleEvents.BATTLE_ENDED, "winner": winner, "reason": reason})


## Kill a unit: status dead, unit_died event. hp is left as the rule set it.
func kill(state: BattleState, unit: BattleUnit, killer_id: String) -> void:
	if not unit.is_alive():
		return
	unit.status = BattleUnit.STATUS_DEAD
	emit(state, {"type": BattleEvents.UNIT_DIED, "unit_id": unit.id, "killer_id": killer_id})


## Take a living unit off the field with a game-defined status (routed,
## captured, dissolved, dormant).
func remove_from_field(state: BattleState, unit: BattleUnit, status: String, by_id: String = "") -> void:
	if not unit.is_on_field():
		return
	unit.status = status
	emit(state, {"type": BattleEvents.LEFT_FIELD, "unit_id": unit.id, "status": status, "by": by_id})


## Put a unit on the field mid-battle (summons, reinforcements, revived units).
func spawn(state: BattleState, unit: BattleUnit) -> void:
	if not state.units.has(unit.id):
		state.add_unit(unit)
	unit.status = BattleUnit.STATUS_ACTIVE
	emit(state, {
		"type": BattleEvents.UNIT_SPAWNED,
		"unit_id": unit.id,
		"faction": unit.faction,
		"cell": BattleEvents.cell(unit.cell),
	})


## Request that a move in progress stop after the current step. Checked by
## MoveRule between steps; a no-op when the unit is not moving.
func interrupt_move(unit_id: String) -> void:
	_interrupts[unit_id] = true


func consume_interrupt(unit_id: String) -> bool:
	if _interrupts.get(unit_id, false):
		_interrupts.erase(unit_id)
		return true
	return false
