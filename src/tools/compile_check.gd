extends SceneTree

# The compile gate's engine half — driven by src/tools/check_scripts.ps1, not
# run by hand. Loads every project-owned .gd and .tscn through the runtime
# resource loader, which is the only pass that compiles GDScript bodies: an
# --editor pass just registers global class names from a parse that discards
# errors, so it reports a file of pure garbage as clean.
#
# Three traps this walks around, all found the hard way:
#   - A script that fails to compile still loads non-null; the loader hands back
#     a placeholder. can_instantiate() is the signal, never the null check.
#   - A scene whose script failed to compile also loads fine, silently dropping
#     the script — which is why every .gd is checked directly, not just reached
#     through the scene that uses it.
#   - Loading this file re-enters the running main loop and segfaults, so the
#     walk skips itself.

const _SKIP_DIRS: Array[String] = ["res://addons/agentic_godot_validation", "res://artifacts", "res://.godot"]
const _SELF := "res://tools/compile_check.gd"
const _MARKER := "COMPILE CHECK COMPLETE"

var _failures: Array[String] = []


func _initialize() -> void:
	var scripts: Array[String] = []
	var scenes: Array[String] = []
	_walk("res://", scripts, scenes)

	for path: String in scripts:
		_check_script(path)

	for path: String in scenes:
		_check_scene(path)

	for failure: String in _failures:
		print("COMPILE FAIL: ", failure)

	# The marker and its counts are the pass's positive signal: check_scripts.ps1
	# fails when it is missing or reports no scripts, so a crash or a hang
	# partway through the walk cannot read as a clean run.
	var counts := [scripts.size(), scenes.size(), _failures.size()]
	print(_MARKER, ": %d scripts, %d scenes, %d failures" % counts)

	quit(0 if _failures.is_empty() else 1)


func _check_script(path: String) -> void:
	var script := ResourceLoader.load(path) as Script
	if script == null:
		_failures.append("%s (did not load as a Script)" % path)
		return

	# Abstract scripts are legitimately non-instantiable; a failed compile is not.
	if not script.can_instantiate() and not script.is_abstract():
		_failures.append("%s (failed to compile)" % path)


func _check_scene(path: String) -> void:
	var scene := ResourceLoader.load(path) as PackedScene
	if scene == null:
		_failures.append("%s (did not load as a PackedScene)" % path)
		return

	if not scene.can_instantiate():
		_failures.append("%s (cannot instantiate)" % path)


func _walk(dir_path: String, scripts: Array[String], scenes: Array[String]) -> void:
	for skip: String in _SKIP_DIRS:
		if dir_path.begins_with(skip):
			return

	var dir := DirAccess.open(dir_path)
	if dir == null:
		return

	for file_name: String in dir.get_files():
		var path := dir_path.path_join(file_name)
		if path == _SELF:
			continue

		if file_name.ends_with(".gd"):
			scripts.append(path)
		elif file_name.ends_with(".tscn"):
			scenes.append(path)

	for sub_dir: String in dir.get_directories():
		_walk(dir_path.path_join(sub_dir), scripts, scenes)
