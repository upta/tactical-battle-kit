extends Node2D

# Harness for the battlefield demo: proves the grid built from the painted
# half-offset-square map, that a two-cell creature occupies two cells and
# moves as one, and that the demo's presentation drives a human decision.
# sim_step starts the game with castle on a HumanController; the first
# castle decision is the griffins' turn (speed 6, ties go to the first
# faction). sim_submit takes the griffins' first move.

const HarnessStateHelpers := preload("res://addons/agentic_godot_validation/runtime/support/harness_state_helpers.gd")

@export var battle_path: String = "res://examples/battlefield/battles/grassland.json"

@onready var _scene: Node2D = %Battlefield

var _load_error: String = ""
var _started: bool = false
var _submitted: int = 0
var _held: Dictionary[String, bool] = {"sim_step": false, "sim_submit": false}


func _ready() -> void:
	reset_harness()


func reset_harness() -> void:
	_started = false
	_submitted = 0
	_load_error = ""
	if not _scene.load_battle(battle_path):
		_load_error = "battle failed to load"
		push_error(_load_error)


func _physics_process(_delta: float) -> void:
	for action: String in _held.keys():
		var pressed := Input.is_action_pressed(action)
		var rising := pressed and not _held[action]
		_held[action] = pressed
		if not rising:
			continue
		match action:
			"sim_step":
				if not _started:
					_started = true
					_scene.start("castle", 5)
			"sim_submit":
				_submit_griffin_move()


func _submit_griffin_move() -> void:
	var human: HumanController = _scene.human()
	if human == null or not human.is_waiting():
		return
	for action: BattleAction in human.pending():
		if action.kind == "move" and action.unit_id == "c_griffins":
			_submitted += 1
			_scene.submit_from_harness(action)
			return


func get_observed_state() -> Dictionary:
	var state: BattleState = _scene.state()
	var human: HumanController = _scene.human()
	var units := {}
	if state != null:
		for unit_id: String in state.sorted_unit_ids():
			var unit := state.units[unit_id]
			var cells: Array[String] = []
			for cell: Vector2i in state.occupied_cells(unit):
				cells.append("%d,%d" % [cell.x, cell.y])
			units[unit_id] = {"cells": ",".join(cells), "cell_count": cells.size(), "count": BattlefieldRuleset.count_of(unit), "status": unit.status}
	var turn_unit := ""
	if state != null and state.current_turn != null and not state.current_turn.unit_ids.is_empty():
		turn_unit = state.current_turn.unit_ids[0]
	return {
		"load_error": _load_error,
		"started": _started,
		"submitted": _submitted,
		"grid_width": state.grid.width if state != null else 0,
		"grid_height": state.grid.height if state != null else 0,
		"topology": state.grid.topology.id() if state != null else "",
		"obstacle_6_1": state.grid.has_tag_at(Vector2i(6, 1), "obstacle") if state != null else false,
		"obstacle_5_1": state.grid.has_tag_at(Vector2i(5, 1), "obstacle") if state != null else false,
		"human_waiting": human != null and human.is_waiting(),
		"pending_count": human.pending().size() if human != null else 0,
		"turn_unit": turn_unit,
		"highlighted_cells": _scene.highlighted_cells(),
		"round": state.round_number if state != null else -1,
		"units": units,
		"signals": {},
		"metrics": {},
		"nodes": HarnessStateHelpers.build_named_node_facts({"battlefield": _scene}),
	}
