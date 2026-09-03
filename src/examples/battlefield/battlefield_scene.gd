extends Node2D

# The battlefield demo's presentation on half-offset-square TileMapLayers:
# Godot's brick rows are the kit's odd-r hex coordinates, so map_to_local
# and local_to_map are the whole mapping. Stacks show their creature count,
# two-cell creatures are drawn across both cells and their move targets
# highlight both cells, and hovering a target shows the damage and kill
# range the ruleset predicts. Same viewer contract as breach.

const HL_MOVE := Vector2i(3, 0)
const HL_TARGET := Vector2i(4, 0)
const HL_ANCHOR := Vector2i(5, 0)
const HL_BODY := Vector2i(6, 0)

@onready var _map: Node2D = %Map
@onready var _ground: TileMapLayer = %Map.get_node("Ground")
@onready var _highlight: TileMapLayer = %Highlight
@onready var _overlay: Node2D = %Overlay
@onready var _runner: BattleRunner = %BattleRunner
@onready var _status: Label = %Status
@onready var _hint: Label = %Hint
@onready var _action_bar: HBoxContainer = %ActionBar

var battle_id: String = ""
var _battle_path: String = ""
var _origin: Vector2i = Vector2i.ZERO
var _human: HumanController = null
var _human_faction: String = ""
var _seed: int = 1
var _stepping: bool = false
var _paused: bool = false
var _choices: Array[BattleAction] = []
var _selected: String = ""
var _cell_choices: Array[BattleAction] = []
var _timer: Timer


func _ready() -> void:
	_timer = Timer.new()
	_timer.wait_time = 0.6
	_timer.timeout.connect(step)
	add_child(_timer)
	_runner.state_changed.connect(_on_state_changed)
	_runner.action_applied.connect(_on_action_applied)
	_runner.battle_ended.connect(_on_battle_ended)
	_origin = TileMapGridSource.origin(_ground)
	_overlay.setup(self)


# --- Viewer contract ---


func load_battle(path: String) -> bool:
	stop()
	var state := BattleLoader.load_file(path)
	if state == null:
		_status.text = "Battle failed to load: %s" % path
		return false
	_battle_path = path
	battle_id = state.battle_id
	_runner.setup(state, {}, _seed)
	_overlay.state = state
	_overlay.queue_redraw()
	_status.text = "%s · pick a mode to start" % battle_id
	return true


func factions() -> Array[String]:
	return _runner.state.factions if _runner.state != null else []


func start(human_faction: String, seed_value: int) -> void:
	if _runner.state == null:
		return
	_seed = seed_value
	_paused = false
	stop()
	_human_faction = human_faction if _runner.state.factions.has(human_faction) else ""
	if not _human_faction.is_empty():
		_human = HumanController.new()
		_human.decision_requested.connect(_on_decision_requested)
		_runner.set_controller(_human_faction, _human)
	_hint.text = _controls_text()
	_timer.start()
	_on_state_changed(_runner.state)
	if _human != null:
		step()


func restart() -> void:
	_seed += 1
	load_battle(_battle_path)
	start(_human_faction, _seed)


func stop() -> void:
	_timer.stop()
	_clear_action_bar()
	_highlight.clear()
	_runner.abort()
	if _human != null and _human.is_waiting():
		_human.submit(null)
	_human = null
	_stepping = false


func set_paused(paused: bool) -> void:
	_paused = paused
	if _paused:
		_timer.stop()
	elif _runner.is_running():
		_timer.start()
	_hint.text = _controls_text() + ("   (AI paused)" if _paused else "")


func step() -> void:
	if _stepping or not _runner.is_running():
		return
	_stepping = true
	await _runner.step()
	_stepping = false


# --- Mapping ---


func cell_to_world(cell: Vector2i) -> Vector2:
	return _map.to_global(_ground.map_to_local(cell + _origin))


func cell_at_mouse() -> Vector2i:
	var cell := _ground.local_to_map(_ground.get_local_mouse_position()) - _origin
	var state := _runner.state
	return cell if state != null and state.grid.in_bounds(cell) else Vector2i(-1, -1)


func _controls_text() -> String:
	var mode := "watching AI vs AI" if _human == null else "you are %s: click a ringed stack, then a highlighted cell or enemy" % _human_faction
	return "%s   ·   Space: step AI   P: pause AI   R: restart   Esc/M: menu" % mode


# --- Runner signals ---


func _on_state_changed(state: BattleState) -> void:
	_overlay.queue_redraw()
	var turn := state.current_turn
	var turn_text := "%s to act" % turn.faction if turn != null else "between turns"
	var counts: Array[String] = []
	for faction: String in state.factions:
		var creatures := 0
		for unit: BattleUnit in state.units_on_field_of(faction):
			creatures += BattlefieldRuleset.count_of(unit)
		counts.append("%s %d creatures" % [faction, creatures])
	_status.text = "%s · seed %d · round %d · %s · %s" % [battle_id, _seed, state.round_number, turn_text, " · ".join(counts)]


func _on_action_applied(_action: BattleAction, events: Array[Dictionary]) -> void:
	_overlay.show_events(events)


func _on_battle_ended(outcome: BattleOutcome) -> void:
	_timer.stop()
	_clear_action_bar()
	_highlight.clear()
	var verdict := "draw" if outcome.is_draw() else "%s wins" % outcome.winner
	_status.text += "  ·  %s (%s)" % [verdict, outcome.reason]
	_hint.text = "Battle over.   R: play again   Esc/M: menu"


# --- Human play ---


func _on_decision_requested(_turn: BattleTurn, legal: Array[BattleAction]) -> void:
	_choices = legal
	_cell_choices = []
	_overlay.ringed = ActionTargets.actionable_unit_ids(legal)
	# A Heroes turn belongs to one stack: preselect it.
	_selected = _overlay.ringed[0] if _overlay.ringed.size() == 1 else ""
	_overlay.selected = _selected
	_overlay.queue_redraw()
	_refresh_highlights()
	_rebuild_action_bar()
	_on_state_changed(_runner.state)
	_status.text += "  ·  YOUR MOVE: %d choices" % legal.size()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_click(cell_at_mouse())
	elif event is InputEventMouseMotion:
		_update_hover(cell_at_mouse())


func _handle_click(cell: Vector2i) -> void:
	if _human == null or not _human.is_waiting() or cell.x < 0:
		return
	var state := _runner.state
	if not _selected.is_empty():
		var matches := ActionTargets.matches_at(state, _choices, _selected, cell)
		if matches.size() == 1:
			_submit(matches[0])
			return
		if matches.size() > 1:
			_cell_choices = matches
			_rebuild_action_bar()
			return
	var unit_here := state.unit_at(cell)
	_selected = unit_here.id if unit_here != null and not _human.pending_for(unit_here.id).is_empty() else ""
	_overlay.selected = _selected
	_overlay.queue_redraw()
	_cell_choices = []
	_refresh_highlights()
	_rebuild_action_bar()


## Hovering an enemy shows the damage and kills this attack would do.
func _update_hover(cell: Vector2i) -> void:
	var lines: Array[String] = []
	if _human != null and _human.is_waiting() and not _selected.is_empty() and cell.x >= 0:
		var state := _runner.state
		var attacker := state.unit(_selected)
		var target := state.unit_at(cell)
		for action: BattleAction in ActionTargets.matches_at(state, _choices, _selected, cell):
			if target == null or attacker == null:
				break
			if action.kind == "melee" or action.kind == "volley":
				var rules := state.ruleset as BattlefieldRuleset
				var expected: Dictionary = rules.expected_damage(state, attacker, target, action.kind == "volley")
				lines.append("%d-%d damage" % [int(expected["min"]), int(expected["max"])])
				lines.append("kills %d-%d of %d" % [int(expected["kills_min"]), int(expected["kills_max"]), BattlefieldRuleset.count_of(target)])
				break
			if action.kind == "death_cloud":
				lines.append("death cloud")
				lines.append("hits all around")
				break
	_overlay.set_hover(cell, lines)


func _submit(action: BattleAction) -> void:
	_choices = []
	_selected = ""
	var none: Array[String] = []
	_overlay.ringed = none
	_overlay.selected = ""
	_overlay.set_hover(Vector2i(-1, -1), none)
	_highlight.clear()
	_clear_action_bar()
	_human.submit(action)


func _refresh_highlights() -> void:
	_highlight.clear()
	if _selected.is_empty():
		return
	var state := _runner.state
	var mover := state.unit(_selected)
	for action: BattleAction in ActionTargets.for_unit(_choices, _selected):
		var cell := ActionTargets.target_cell_of(state, action)
		if cell.x < 0:
			continue
		var occupant := state.unit_at(cell)
		var tile := HL_MOVE
		if occupant != null and occupant.id != _selected:
			tile = HL_TARGET
		elif action.params.has("anchor"):
			tile = HL_ANCHOR
		_highlight.set_cell(cell + _origin, 0, tile)
		# A two-cell creature's move also claims the cell beside the anchor.
		if tile == HL_MOVE and mover != null and mover.def.footprint.size() > 1:
			for offset: Vector2i in mover.def.footprint:
				if offset != Vector2i.ZERO:
					var body := state.grid.topology.offset_cell(cell, offset)
					if _highlight.get_cell_source_id(body + _origin) < 0:
						_highlight.set_cell(body + _origin, 0, HL_BODY)


func _rebuild_action_bar() -> void:
	_clear_action_bar()
	if _human == null or not _human.is_waiting():
		return
	var state := _runner.state
	if not _cell_choices.is_empty():
		for action: BattleAction in _cell_choices:
			_add_button(_describe(state, action), action)
	elif not _selected.is_empty():
		for action: BattleAction in ActionTargets.untargeted(state, _choices, _selected):
			_add_button(_describe(state, action), action)
	var end_turn := Button.new()
	end_turn.text = "End turn"
	end_turn.pressed.connect(func() -> void: _submit(null))
	_action_bar.add_child(end_turn)


func _describe(state: BattleState, action: BattleAction) -> String:
	var rule := _runner.engine.rule(action.kind)
	return rule.describe(state, action) if rule != null else action.kind


func _add_button(text: String, action: BattleAction) -> void:
	var button := Button.new()
	button.text = text
	button.pressed.connect(func() -> void: _submit(action))
	_action_bar.add_child(button)


func _clear_action_bar() -> void:
	for child: Node in _action_bar.get_children():
		child.queue_free()


# --- Harness access ---


func state() -> BattleState:
	return _runner.state


func human() -> HumanController:
	return _human


func select_from_harness(unit_id: String) -> void:
	if _human == null or not _human.is_waiting():
		return
	var unit := _runner.state.unit(unit_id)
	if unit != null:
		_handle_click(unit.cell)


func submit_from_harness(action: BattleAction) -> void:
	if _human != null and _human.is_waiting():
		_submit(action)


func highlighted_cells() -> int:
	return _highlight.get_used_cells().size()
