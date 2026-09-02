extends Node2D

# The dev shell's battle viewer: loads an example battle, plays its declared
# AIs against each other on a timer, and prints the boot marker the run-game
# skill greps for. Any battle JSON works: pass `-- --battle res://path.json`
# or cycle the bundled examples with N.
# Space steps one decision, P toggles autoplay, R restarts with a new seed.

const BATTLES: Array[String] = [
	"res://examples/skirmish/battles/open_field.json",
	"res://examples/frontier/battles/river_crossing.json",
	"res://examples/chess/battles/standard.json",
]
const BOOT_MARKER := "[Kit] Battle ready: "

@export var autoplay: bool = true
@export var step_interval: float = 0.25

@onready var _view: BattleView = %BattleView
@onready var _runner: BattleRunner = %BattleRunner
@onready var _status: Label = %Status
@onready var _timer: Timer = %StepTimer

var _battle_index: int = 0
var _battle_path: String = ""
var _seed: int = 1
var _stepping: bool = false


func _ready() -> void:
	_seed = int(Time.get_unix_time_from_system()) % 100000
	_battle_path = _battle_from_args()
	_timer.wait_time = step_interval
	_timer.timeout.connect(_on_step_timer)
	_runner.state_changed.connect(_on_state_changed)
	_runner.battle_ended.connect(_on_battle_ended)
	_restart()


func _battle_from_args() -> String:
	var args := OS.get_cmdline_user_args()
	var index := args.find("--battle")
	if index >= 0 and index + 1 < args.size():
		return args[index + 1]
	return BATTLES[0]


func _restart() -> void:
	_timer.stop()
	var state := BattleLoader.load_file(_battle_path)
	if state == null:
		_status.text = "Battle failed to load: %s (see the log)" % _battle_path
		return
	_runner.setup(state, {}, _seed)
	_view.state = state
	_view.cell_size = _fit_cell_size(state)
	_view.position = Vector2(48, 56)
	if autoplay:
		_timer.start()
	print(BOOT_MARKER + state.battle_id)


func _fit_cell_size(state: BattleState) -> int:
	var usable := Vector2(1280 - 96, 720 - 120)
	var per_cell := minf(usable.x / float(state.grid.width + 1), usable.y / float(state.grid.height + 1))
	return clampi(int(per_cell), 24, 96)


func _unhandled_input(event: InputEvent) -> void:
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


func _on_step_timer() -> void:
	_step()


func _step() -> void:
	if _stepping or not _runner.is_running():
		return
	_stepping = true
	await _runner.step()
	_stepping = false


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
	var verdict := "draw" if outcome.is_draw() else "%s wins" % outcome.winner
	_status.text += "  ·  %s (%s). R restarts, N next battle." % [verdict, outcome.reason]
