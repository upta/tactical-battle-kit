extends Node

# Composition root for the dev shell: routes to the validation kit's
# bootstrap under --test-mode, otherwise boots the battle viewer. Also
# registers the InputMap actions harnesses and the viewer press, since the
# validation runtime drives InputMap actions.

const VIEWER_SCENE := preload("res://app/battle_viewer.tscn")
const TEST_SCENE_PATH := "res://addons/agentic_godot_validation/runtime/scenes/test_bootstrap.tscn"
const ACTION_KEYS: Dictionary[String, Key] = {
	"sim_step": KEY_SPACE,
	"sim_play": KEY_P,
	"sim_restart": KEY_R,
	"sim_next_battle": KEY_N,
}


func _ready() -> void:
	_ensure_input_actions()
	if _is_test_mode():
		var test_scene: PackedScene = load(TEST_SCENE_PATH)
		if test_scene == null:
			push_error("Validation bootstrap not found at %s (run setup.ps1 to materialize the submodule symlinks)." % TEST_SCENE_PATH)
			return
		add_child(test_scene.instantiate())
		return
	add_child(VIEWER_SCENE.instantiate())


func _is_test_mode() -> bool:
	return OS.get_cmdline_user_args().has("--test-mode")


func _ensure_input_actions() -> void:
	for action_name: String in ACTION_KEYS.keys():
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
		var event := InputEventKey.new()
		event.physical_keycode = ACTION_KEYS[action_name]
		if not InputMap.action_has_event(action_name, event):
			InputMap.action_add_event(action_name, event)
