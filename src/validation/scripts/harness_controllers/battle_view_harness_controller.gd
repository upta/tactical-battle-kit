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

var _step_count: int = 0
var _load_error: String = ""
var _busy: bool = false


func _ready() -> void:
	_runner.state_changed.connect(func(_state: BattleState) -> void: _view.refresh())
	reset_harness()


func reset_harness() -> void:
	_step_count = 0
	_load_error = ""
	var state := BattleLoader.load_file(FIXTURE_PATH)
	if state == null:
		_load_error = "fixture failed to load: " + FIXTURE_PATH
		push_error(_load_error)
		return
	_runner.setup(state, {}, SEED)
	_view.state = state
	_view.position = Vector2(200, 120)
	_view.cell_size = 96


# Rising-edge detection on the held level, not is_action_just_pressed: the
# validation runtime re-asserts a held action every physics frame, which
# reads as a fresh press each frame and stepped the battle twice per press.
var _held: Dictionary[String, bool] = {"sim_step": false, "sim_play": false}


func _physics_process(_delta: float) -> void:
	for action: String in _held.keys():
		var pressed := Input.is_action_pressed(action)
		var rising := pressed and not _held[action]
		_held[action] = pressed
		if not rising:
			continue
		if action == "sim_step":
			_step()
		else:
			_play()


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
