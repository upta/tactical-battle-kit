extends Node2D

# Harness for the view and runner: loads the duel fixture, steps the battle
# on synthetic InputMap actions (sim_step = one decision, sim_play = run to
# the end), and exposes semantic state for the scenario to assert against.
# The kit's scenario runtime presses InputMap actions, which is why the
# bridge watches Input rather than taking calls.

const HarnessStateHelpers := preload("res://addons/agentic_godot_validation/runtime/support/harness_state_helpers.gd")
const FIXTURE_PATH := "res://validation/fixtures/duel.json"
const SEED := 7

@onready var _view: BattleView = %BattleView
@onready var _runner: BattleRunner = %BattleRunner

## Which faction a HumanController drives; "" keeps every side on its AI.
## Scenarios cannot set this, so the harness reads it from its own scene:
## battle_view_harness.tscn leaves it "", human_play_harness.tscn sets red.
@export var human_faction: String = ""

var _step_count: int = 0
var _load_error: String = ""
var _busy: bool = false
var _human: HumanController = null
var _decisions_requested: int = 0
var _submitted: int = 0


func _ready() -> void:
	_runner.state_changed.connect(func(_state: BattleState) -> void: _view.refresh())
	_runner.action_applied.connect(func(_action: BattleAction, events: Array[Dictionary]) -> void: _view.show_events(events))
	reset_harness()


func reset_harness() -> void:
	_step_count = 0
	_load_error = ""
	_decisions_requested = 0
	_submitted = 0
	var state := BattleLoader.load_file(FIXTURE_PATH)
	if state == null:
		_load_error = "fixture failed to load: " + FIXTURE_PATH
		push_error(_load_error)
		return
	_runner.setup(state, {}, SEED)
	_human = null
	if not human_faction.is_empty():
		_human = HumanController.new()
		_human.decision_requested.connect(_on_decision_requested)
		_runner.set_controller(human_faction, _human)
	_view.state = state
	_view.clear_choices()
	_view.position = Vector2(200, 120)
	_view.cell_size = 96


func _on_decision_requested(turn: BattleTurn, legal: Array[BattleAction]) -> void:
	_decisions_requested += 1
	_view.set_choices(legal)
	if not turn.unit_ids.is_empty():
		_view.select_unit(turn.unit_ids[0])


## sim_submit: pick the first pending attack, else the first pending action,
## the way a person clicking the obvious target would.
func _submit_obvious() -> void:
	if _human == null or not _human.is_waiting():
		return
	var choice: BattleAction = null
	for action: BattleAction in _human.pending():
		if action.kind == "attack":
			choice = action
			break
	if choice == null and not _human.pending().is_empty():
		choice = _human.pending()[0]
	_submitted += 1
	_view.clear_choices()
	_human.submit(choice)


# Rising-edge detection on the held level, not is_action_just_pressed: the
# validation runtime re-asserts a held action every physics frame, which
# reads as a fresh press each frame and stepped the battle twice per press.
var _held: Dictionary[String, bool] = {"sim_step": false, "sim_play": false, "sim_submit": false}


func _physics_process(_delta: float) -> void:
	for action: String in _held.keys():
		var pressed := Input.is_action_pressed(action)
		var rising := pressed and not _held[action]
		_held[action] = pressed
		if not rising:
			continue
		match action:
			"sim_step":
				_step()
			"sim_play":
				_play()
			"sim_submit":
				_submit_obvious()


func _step() -> void:
	if _busy or not _runner.is_running():
		return
	_busy = true
	await _runner.step()
	_step_count += 1
	_busy = false


func _play() -> void:
	if _busy or not _runner.is_running():
		return
	_busy = true
	while await _runner.step():
		_step_count += 1
	_step_count += 1
	_busy = false


func get_observed_state() -> Dictionary:
	var state := _runner.state
	var units := {}
	if state != null:
		for unit_id: String in state.sorted_unit_ids():
			var unit := state.units[unit_id]
			units[unit_id] = {
				"hp": unit.hp,
				"cell": [unit.cell.x, unit.cell.y],
				"status": unit.status,
				"facing": unit.facing,
			}
	return {
		"load_error": _load_error,
		"step_count": _step_count,
		"busy": _busy,
		"human_faction": human_faction,
		"human_waiting": _human != null and _human.is_waiting(),
		"pending_count": _human.pending().size() if _human != null else 0,
		"pending_attacks": _human.pending().filter(func(a: BattleAction) -> bool: return a.kind == "attack").size() if _human != null else 0,
		"decisions_requested": _decisions_requested,
		"submitted": _submitted,
		"round": state.round_number if state != null else -1,
		"turn_faction": state.current_turn.faction if state != null and state.current_turn != null else "",
		"ended": state.ended if state != null else false,
		"winner": state.outcome.winner if state != null and state.outcome != null else "",
		"end_reason": state.outcome.reason if state != null and state.outcome != null else "",
		"event_count": state.events.size() if state != null else 0,
		"units": units,
		"view": _view.describe_ui(),
		"metrics": {
			"red_hp_share": state.hp_share("red") if state != null else 0.0,
			"blue_hp_share": state.hp_share("blue") if state != null else 0.0,
		},
		"signals": {},
		"nodes": HarnessStateHelpers.build_named_node_facts({
			"view": _view,
			"runner": _runner,
		}),
	}
