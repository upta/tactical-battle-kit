extends Node2D

# Harness for the TileMap-backed breach demo: proves the grid built from the
# painted TileMapLayers has the terrain the map shows, and that the demo's
# own presentation drives a human decision through the same runner seam.
# sim_step starts the game with the squad on a HumanController; sim_submit
# picks the first move for the first squad unit, the way a click would.

const HarnessStateHelpers := preload("res://addons/agentic_godot_validation/runtime/support/harness_state_helpers.gd")
## Battle the harness loads; the readout harness scene points at a fixture.
@export var battle_path: String = "res://examples/breach/battles/warehouse.json"

@onready var _scene: Node2D = %Breach

var _load_error: String = ""
var _started: bool = false
var _submitted: int = 0
var _last_attack: Dictionary = {}
var _held: Dictionary[String, bool] = {"sim_step": false, "sim_submit": false, "sim_play": false}


func _ready() -> void:
	_scene.get_node("%BattleRunner").action_applied.connect(_on_action_applied)
	reset_harness()


func _on_action_applied(_action: BattleAction, events: Array[Dictionary]) -> void:
	for event: Dictionary in events:
		# The first shot only: the alien answers within the AI tick and would
		# overwrite what the scenario is asserting about the trooper's shot.
		if str(event.get("type")) == BattleEvents.ATTACKED and _last_attack.is_empty():
			_last_attack = {"chance": int(event.get("chance", -1)), "cover": str(event.get("cover", "")), "hit": bool(event.get("hit", false)), "damage": int(event.get("damage", 0))}


func reset_harness() -> void:
	_started = false
	_submitted = 0
	_load_error = ""
	_last_attack = {}
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
					_scene.start("squad", 11)
			"sim_submit":
				_submit_first_move()
			"sim_play":
				# Select the first squad unit and hover the first alien, as a
				# person lining up a shot would.
				_scene.select_from_harness("s_trooper1")
				var target: BattleState = _scene.state()
				var alien := target.unit("a_sectoid1")
				if alien != null:
					_scene.hover_from_harness(alien.cell)


func _submit_first_move() -> void:
	var human: HumanController = _scene.human()
	if human == null or not human.is_waiting():
		return
	# A shot if one is legal, else the first move: the readout fixture
	# starts in range, the warehouse battle does not.
	for kind: String in ["shoot", "move"]:
		for action: BattleAction in human.pending():
			if action.kind == kind and action.unit_id == "s_trooper1":
				_submitted += 1
				_scene.submit_from_harness(action)
				return


func get_observed_state() -> Dictionary:
	var state: BattleState = _scene.state()
	var human: HumanController = _scene.human()
	var terrain := {}
	var overlays := {}
	var units := {}
	if state != null:
		for probe: Vector2i in [Vector2i(0, 0), Vector2i(1, 1), Vector2i(9, 3), Vector2i(5, 3), Vector2i(13, 2)]:
			var key := "%d_%d" % [probe.x, probe.y]
			var top := state.grid.terrain_at(probe)
			terrain[key] = top.id if top != null else ""
			overlays[key] = state.grid.overlays_at(probe).size()
		for unit_id: String in state.sorted_unit_ids():
			var unit := state.units[unit_id]
			# Cells as "x,y" strings: the scenario comparator sees JSON arrays as
			# floats and never equals an int Vector2i pair.
			units[unit_id] = {"cell": "%d,%d" % [unit.cell.x, unit.cell.y], "hp": unit.hp, "status": unit.status}
	return {
		"load_error": _load_error,
		"started": _started,
		"submitted": _submitted,
		"grid_width": state.grid.width if state != null else 0,
		"grid_height": state.grid.height if state != null else 0,
		"terrain": terrain,
		"overlay_count": overlays,
		"spawn_13_2": bool(state.grid.get_layer_value("spawn", Vector2i(13, 2), false)) if state != null else false,
		"human_waiting": human != null and human.is_waiting(),
		"hover_lines": _scene.hover_lines(),
		"last_attack": _last_attack,
		"pending_count": human.pending().size() if human != null else 0,
		"round": state.round_number if state != null else -1,
		"event_count": state.events.size() if state != null else 0,
		"units": units,
		"signals": {},
		"metrics": {},
		"nodes": HarnessStateHelpers.build_named_node_facts({"breach": _scene}),
	}
