extends Node2D

# The dev shell's battle viewer: loads an example battle, plays its declared
# AIs against each other on a timer, or hands one faction to a person, and
# prints the boot marker the run-game skill greps for. Any battle JSON works:
# pass `-- --battle res://path.json`, or cycle the bundled examples with N.
# `-- --human <faction>` or H gives that side to the mouse.
#
# Space steps one decision, P toggles autoplay, R restarts with a new seed.
# Playing: click one of your ringed units, then a highlighted cell or enemy;
# actions with no target (wait, entrench, self heals) are buttons in the bar.
# Click mapping is generic over action params (target_cell, target_unit_id,
# anchor), so every ruleset is playable with no per-game code here.

const BATTLES: Array[String] = [
	"res://examples/skirmish/battles/open_field.json",
	"res://examples/frontier/battles/river_crossing.json",
	"res://examples/chess/battles/standard.json",
]
const BOOT_MARKER := "[Kit] Battle ready: "

@export var autoplay: bool = true
@export var step_interval: float = 0.5

@onready var _view: BattleView = %BattleView
@onready var _runner: BattleRunner = %BattleRunner
@onready var _status: Label = %Status
@onready var _hint: Label = %Hint
@onready var _timer: Timer = %StepTimer
@onready var _action_bar: HBoxContainer = %ActionBar

var _battle_index: int = 0
var _battle_path: String = ""
var _seed: int = 1
var _stepping: bool = false
var _human_faction: String = ""
var _human: HumanController = null
var _cell_choices: Array[BattleAction] = []


func _ready() -> void:
	_seed = int(Time.get_unix_time_from_system()) % 100000
	_battle_path = _arg_after("--battle", BATTLES[0])
	_human_faction = _arg_after("--human", "")
	_timer.wait_time = step_interval
	_timer.timeout.connect(_on_step_timer)
	_runner.state_changed.connect(_on_state_changed)
	_runner.action_applied.connect(_on_action_applied)
	_runner.battle_ended.connect(_on_battle_ended)
	_restart()


func _arg_after(flag: String, default: String) -> String:
	var args := OS.get_cmdline_user_args()
	var index := args.find(flag)
	if index >= 0 and index + 1 < args.size():
		return args[index + 1]
	return default


func _restart() -> void:
	_timer.stop()
	_clear_action_bar()
	var state := BattleLoader.load_file(_battle_path)
	if state == null:
		_status.text = "Battle failed to load: %s (see the log)" % _battle_path
		return
	_runner.setup(state, {}, _seed)
	_human = null
	if not _human_faction.is_empty() and state.factions.has(_human_faction):
		_human = HumanController.new()
		_human.decision_requested.connect(_on_decision_requested)
		_runner.set_controller(_human_faction, _human)
	_view.state = state
	_view.clear_choices()
	_view.cell_size = _fit_cell_size(state)
	_view.position = Vector2(48, 56)
	_hint.text = _controls_text()
	if autoplay:
		_timer.start()
	print(BOOT_MARKER + state.battle_id)


func _fit_cell_size(state: BattleState) -> int:
	var usable := Vector2(1280 - 96, 720 - 150)
	var per_cell := minf(usable.x / float(state.grid.width + 1), usable.y / float(state.grid.height + 1))
	return clampi(int(per_cell), 24, 96)


func _controls_text() -> String:
	var you := "H: play a side" if _human == null else "you are %s (H cycles)" % _human_faction
	return "Space: step   P: autoplay   R: reseed   N: next battle   %s   Click a ringed unit, then a highlighted cell or enemy" % you


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_click(_view.cell_at_position(_view.get_local_mouse_position()))
		return
	if event.is_action_pressed("sim_step"):
		_step()
	elif event.is_action_pressed("sim_play"):
		autoplay = not autoplay
		if autoplay and _runner.is_running():
			_timer.start()
		else:
			_timer.stop()
	elif event.is_action_pressed("sim_restart"):
		_seed += 1
		_restart()
	elif event.is_action_pressed("sim_next_battle"):
		_battle_index = (_battle_index + 1) % BATTLES.size()
		_battle_path = BATTLES[_battle_index]
		_restart()
	elif event.is_action_pressed("sim_toggle_human"):
		_cycle_human()
		_restart()


func _cycle_human() -> void:
	var factions := _runner.state.factions if _runner.state != null else []
	var index := factions.find(_human_faction)
	index += 1
	_human_faction = factions[index] if index < factions.size() else ""


# --- Stepping ---


func _on_step_timer() -> void:
	_step()


func _step() -> void:
	if _stepping or not _runner.is_running():
		return
	_stepping = true
	await _runner.step()
	_stepping = false


func _on_action_applied(_action: BattleAction, events: Array[Dictionary]) -> void:
	_view.show_events(events)


func _on_state_changed(state: BattleState) -> void:
	_view.refresh()
	var turn := state.current_turn
	var turn_text := "%s to act" % turn.faction if turn != null else "between turns"
	var shares: Array[String] = []
	for faction: String in state.factions:
		shares.append("%s %.0f%% hp" % [faction, state.hp_share(faction) * 100.0])
	_status.text = "%s · seed %d · round %d · %s · %s" % [
		state.battle_id, _seed, state.round_number, turn_text, " · ".join(shares),
	]


func _on_battle_ended(outcome: BattleOutcome) -> void:
	_timer.stop()
	_clear_action_bar()
	_view.clear_choices()
	var verdict := "draw" if outcome.is_draw() else "%s wins" % outcome.winner
	_status.text += "  ·  %s (%s). R restarts, N next battle." % [verdict, outcome.reason]


# --- Human play ---


func _on_decision_requested(_turn: BattleTurn, legal: Array[BattleAction]) -> void:
	_view.set_choices(legal)
	_cell_choices = []
	_rebuild_action_bar()


func _handle_click(cell: Vector2i) -> void:
	if _human == null or not _human.is_waiting() or cell.x < 0:
		return
	var state := _runner.state
	var unit_here := state.unit_at(cell)
	var selected := _view.selected_unit_id()

	if not selected.is_empty():
		var matches: Array[BattleAction] = []
		for action: BattleAction in _view.choices_for(selected):
			if _view.target_cell_of(action) == cell:
				matches.append(action)
		if matches.size() == 1:
			_submit(matches[0])
			return
		if matches.size() > 1:
			_cell_choices = matches
			_rebuild_action_bar()
			return

	if unit_here != null and not _human.pending_for(unit_here.id).is_empty():
		_view.select_unit(unit_here.id)
	else:
		_view.select_unit("")
	_cell_choices = []
	_rebuild_action_bar()


func _submit(action: BattleAction) -> void:
	_view.clear_choices()
	_clear_action_bar()
	_human.submit(action)


func _rebuild_action_bar() -> void:
	_clear_action_bar()
	if _human == null or not _human.is_waiting():
		return
	var state := _runner.state
	var selected := _view.selected_unit_id()
	if not _cell_choices.is_empty():
		for action: BattleAction in _cell_choices:
			_add_button(_describe(state, action), action)
	elif not selected.is_empty():
		var seen: Dictionary[String, bool] = {}
		for action: BattleAction in _view.choices_for(selected):
			if _view.target_cell_of(action).x >= 0 or seen.has(action.kind):
				continue
			seen[action.kind] = true
			_add_button(action.kind.capitalize(), action)
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
