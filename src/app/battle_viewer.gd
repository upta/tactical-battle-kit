extends Node2D

# The dev shell's battle viewer. Opens on a start menu: pick a battle, then
# play a faction against its AI or watch AI vs AI. Prints the boot marker
# the run-game skill greps for as soon as a battle is loaded.
#
# Playing: click one of your ringed units, then a highlighted cell or enemy;
# actions with no target (wait, entrench, self heals) are buttons in the bar.
# Click mapping is generic over action params (target_cell, target_unit_id,
# anchor), so every ruleset is playable with no per-game code here.
#
# Launch flags skip the menu: `-- --battle res://path.json` picks the
# battle, `-- --human <faction>` or `-- --watch` picks the mode.
# Keys: Space steps one AI decision, P pauses the AI, R restarts the same
# setup with a new seed, Escape or M returns to the menu.

const BATTLES: Array[Dictionary] = [
	{"label": "Skirmish (square)", "path": "res://examples/skirmish/battles/open_field.json"},
	{"label": "Frontier (hex)", "path": "res://examples/frontier/battles/river_crossing.json"},
	{"label": "Chess", "path": "res://examples/chess/battles/standard.json"},
	{"label": "Breach (TileMap)", "path": "res://examples/breach/battles/warehouse.json", "scene": "res://examples/breach/breach.tscn"},
	{"label": "Battlefield (hex stacks)", "path": "res://examples/battlefield/battles/grassland.json", "scene": "res://examples/battlefield/battlefield.tscn"},
]
const BOOT_MARKER := "[Kit] Battle ready: "

@export var step_interval: float = 0.5

@onready var _view: BattleView = %BattleView
@onready var _runner: BattleRunner = %BattleRunner
@onready var _status: Label = %Status
@onready var _hint: Label = %Hint
@onready var _timer: Timer = %StepTimer
@onready var _action_bar: HBoxContainer = %ActionBar
@onready var _menu: PanelContainer = %StartMenu
@onready var _battle_buttons: HBoxContainer = %BattleButtons
@onready var _mode_buttons: HBoxContainer = %ModeButtons
@onready var _menu_button: Button = %MenuButton
@onready var _custom_holder: Node2D = %Custom

var _battle_path: String = ""
var _human_faction: String = ""
var _seed: int = 1
var _stepping: bool = false
var _human: HumanController = null
var _paused: bool = false
var _cell_choices: Array[BattleAction] = []
# An example that owns its presentation (breach): instantiated from the
# BATTLES entry's "scene" and driven through load_battle / factions / start /
# stop / step / set_paused / restart instead of BattleView and the runner.
var _custom: Node2D = null
var _custom_scene_path: String = ""


func _ready() -> void:
	_seed = int(Time.get_unix_time_from_system()) % 100000
	_timer.wait_time = step_interval
	_timer.timeout.connect(_on_step_timer)
	_runner.state_changed.connect(_on_state_changed)
	_runner.action_applied.connect(_on_action_applied)
	_runner.battle_ended.connect(_on_battle_ended)
	_menu_button.pressed.connect(_open_menu)
	_build_battle_buttons()

	_battle_path = _arg_after("--battle", BATTLES[0]["path"])
	_load_battle(_battle_path)
	var args := OS.get_cmdline_user_args()
	if args.has("--watch"):
		_start("")
	elif args.has("--human"):
		_start(_arg_after("--human", ""))
	else:
		_open_menu()


func _arg_after(flag: String, default: String) -> String:
	var args := OS.get_cmdline_user_args()
	var index := args.find(flag)
	if index >= 0 and index + 1 < args.size():
		return args[index + 1]
	return default


# --- Menu ---


func _build_battle_buttons() -> void:
	for entry: Dictionary in BATTLES:
		var button := Button.new()
		button.text = str(entry["label"])
		button.toggle_mode = true
		button.pressed.connect(func() -> void: _pick_battle(str(entry["path"])))
		_battle_buttons.add_child(button)


func _open_menu() -> void:
	_stop_game()
	_menu.visible = true
	_menu_button.visible = false
	_refresh_menu()


func _pick_battle(path: String) -> void:
	_battle_path = path
	_load_battle(path)
	_refresh_menu()


func _refresh_menu() -> void:
	for i: int in _battle_buttons.get_child_count():
		var button: Button = _battle_buttons.get_child(i)
		button.button_pressed = str(BATTLES[i]["path"]) == _battle_path
	for child: Node in _mode_buttons.get_children():
		child.queue_free()
	var names: Array[String] = _custom.factions() if _custom != null else (_runner.state.factions if _runner.state != null else [])
	for faction: String in names:
		var play := Button.new()
		play.text = "Play %s" % faction
		play.pressed.connect(func() -> void: _start(faction))
		_mode_buttons.add_child(play)
	var watch := Button.new()
	watch.text = "Watch AI vs AI"
	watch.pressed.connect(func() -> void: _start(""))
	_mode_buttons.add_child(watch)


# --- Game lifecycle ---


## Load and show a battle without starting it.
func _load_battle(path: String) -> void:
	_stop_game()
	var scene_path := _scene_for(path)
	if scene_path != _custom_scene_path:
		if _custom != null:
			_custom.queue_free()
			_custom = null
		_custom_scene_path = scene_path
		if not scene_path.is_empty():
			var packed: PackedScene = load(scene_path)
			_custom = packed.instantiate()
			_custom_holder.add_child(_custom)
	var custom_active := _custom != null
	_view.visible = not custom_active
	_status.visible = not custom_active
	_hint.visible = not custom_active
	_action_bar.visible = not custom_active
	if custom_active:
		if _custom.load_battle(path):
			print(BOOT_MARKER + str(_custom.battle_id))
		return
	var state := BattleLoader.load_file(path)
	if state == null:
		_status.text = "Battle failed to load: %s (see the log)" % path
		return
	_runner.setup(state, {}, _seed)
	_view.state = state
	_view.clear_choices()
	_view.cell_size = _fit_cell_size(state)
	_view.position = Vector2(48, 56)
	_status.text = "%s · pick a mode to start" % state.battle_id
	print(BOOT_MARKER + state.battle_id)


## Unwind a step suspended on a human decision and stop the AI timer, so the
## battle can be replaced or restarted safely.
func _stop_game() -> void:
	if _custom != null:
		_custom.stop()
	_timer.stop()
	_clear_action_bar()
	_runner.abort()
	if _human != null and _human.is_waiting():
		_human.submit(null)
	_human = null
	_stepping = false


## Start the loaded battle: [param human_faction] on the mouse, "" to watch.
func _start(human_faction: String) -> void:
	if _custom != null:
		_human_faction = human_faction
		_menu.visible = false
		_menu_button.visible = true
		_paused = false
		_custom.start(human_faction, _seed)
		return
	if _runner.state == null:
		return
	_human_faction = human_faction if _runner.state.factions.has(human_faction) else ""
	_menu.visible = false
	_menu_button.visible = true
	_paused = false
	_stop_game()
	if not _human_faction.is_empty():
		_human = HumanController.new()
		_human.decision_requested.connect(_on_decision_requested)
		_runner.set_controller(_human_faction, _human)
	_hint.text = _controls_text()
	_timer.start()
	_on_state_changed(_runner.state)
	if _human != null:
		_step()


func _restart_same() -> void:
	_seed += 1
	if _custom != null:
		_custom.restart()
		return
	_load_battle(_battle_path)
	_start(_human_faction)


func _fit_cell_size(state: BattleState) -> int:
	var usable := Vector2(1280 - 96, 720 - 150)
	var per_cell := minf(usable.x / float(state.grid.width + 1), usable.y / float(state.grid.height + 1))
	return clampi(int(per_cell), 24, 96)


func _controls_text() -> String:
	var mode := "watching AI vs AI" if _human == null else "you are %s: click a ringed unit, then a highlighted cell or enemy" % _human_faction
	return "%s   ·   Space: step AI   P: pause AI   R: restart   Esc/M: menu" % mode


func _unhandled_input(event: InputEvent) -> void:
	if _menu.visible:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_click(_view.cell_at_position(_view.get_local_mouse_position()))
		return
	if event.is_action_pressed("sim_step"):
		if _custom != null:
			_custom.step()
		else:
			_step()
	elif event.is_action_pressed("sim_play"):
		_paused = not _paused
		if _custom != null:
			_custom.set_paused(_paused)
		elif _paused:
			_timer.stop()
		elif _runner.is_running():
			_timer.start()
		_hint.text = _controls_text() + ("   (AI paused)" if _paused else "")
	elif event.is_action_pressed("sim_restart"):
		_restart_same()
	elif event.is_action_pressed("sim_menu") or event.is_action_pressed("ui_cancel"):
		_open_menu()


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
	if _menu.visible:
		return
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
	_status.text += "  ·  %s (%s)" % [verdict, outcome.reason]
	_hint.text = "Battle over.   R: play again   Esc/M: menu"


# --- Human play ---


func _on_decision_requested(_turn: BattleTurn, legal: Array[BattleAction]) -> void:
	_view.set_choices(legal)
	_cell_choices = []
	_rebuild_action_bar()
	_on_state_changed(_runner.state)
	_status.text += "  ·  YOUR MOVE: %d choices" % legal.size()


func _handle_click(cell: Vector2i) -> void:
	if _human == null or not _human.is_waiting() or cell.x < 0:
		return
	var state := _runner.state
	var unit_here := state.unit_at(cell)
	var selected := _view.selected_unit_id()

	if not selected.is_empty():
		var matches := ActionTargets.matches_at(state, _view.choices(), selected, cell)
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
		for action: BattleAction in ActionTargets.untargeted(state, _view.choices(), selected):
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


func _scene_for(path: String) -> String:
	for entry: Dictionary in BATTLES:
		if str(entry["path"]) == path:
			return str(entry.get("scene", ""))
	return ""
