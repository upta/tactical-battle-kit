extends SceneTree

# Headless entry point for balance suites. No scene, no window, no autoloads
# needed, which is why it runs in CI where the screenshot suite cannot:
#
#   godot --headless --path <project> --script res://addons/tactical_battle_kit/sim/sim_cli.gd -- \
#     --suite res://sim/suites/<name>.json [--out res://artifacts/sim] [--runs N] [--seed S] \
#     [--trace] [--register res://path/to/registration.gd]
#
# --register loads a script and calls its static register() so a game's AIs
# are in the AiRegistry before the suite names them. Prints "RESULT {json}"
# and exits 0 (pass), 1 (assertion failure) or 2 (runtime error).

const DEFAULT_OUT := "res://artifacts/sim"


func _initialize() -> void:
	var args := _parse_args(OS.get_cmdline_user_args())
	var suite_path := str(args.get("suite", ""))
	if suite_path.is_empty():
		push_error("sim_cli: --suite <path> is required.")
		_finish({"status": "runtime_error", "exit_code": SimSuite.EXIT_RUNTIME_ERROR, "errors": ["--suite missing"]}, "")
		return

	for registration: String in args.get("register", []):
		var script: GDScript = load(registration)
		if script == null or not script.has_method("register"):
			push_error("sim_cli: --register script has no static register(): %s" % registration)
			_finish({"status": "runtime_error", "exit_code": SimSuite.EXIT_RUNTIME_ERROR, "errors": ["bad --register " + registration]}, "")
			return
		script.call("register")

	var suite := SimSuite.load_file(suite_path)
	if suite.is_empty():
		_finish({"status": "runtime_error", "exit_code": SimSuite.EXIT_RUNTIME_ERROR, "errors": ["suite did not load: " + suite_path]}, "")
		return

	var runner := SimSuite.new()
	runner.runs_override = int(args.get("runs", 0))
	runner.seed_override = int(args.get("seed", -1))
	runner.trace = bool(args.get("trace", false))
	var report := runner.run(suite)
	var out_dir := SimReport.write(report, str(args.get("out", DEFAULT_OUT)))
	_finish(report, out_dir)


func _finish(report: Dictionary, out_dir: String) -> void:
	var summary := {
		"suite_id": report.get("suite_id", ""),
		"status": report.get("status", "runtime_error"),
		"exit_code": report.get("exit_code", SimSuite.EXIT_RUNTIME_ERROR),
		"runs": report.get("runs", 0),
		"matchups": (report.get("matchups", []) as Array).size(),
		"failed": (report.get("failed", []) as Array).size(),
		"errors": report.get("errors", []),
		"duration_msec": report.get("duration_msec", 0),
	}
	print("RESULT " + JSON.stringify(summary))
	if not out_dir.is_empty():
		print("ARTIFACTS " + out_dir)
	for failure: Dictionary in report.get("failed", []):
		print("FAILED %s %s %s: actual %s, expected %s %s" % [
			str(failure.get("metric")), str(failure.get("matchup")),
			"" if failure.get("sweep_value") == null else "@ " + str(failure.get("sweep_value")),
			str(failure.get("actual")), str(failure.get("comparator")), str(failure.get("expected")),
		])
	AiRegistry.clear()
	quit(int(summary["exit_code"]))


static func _parse_args(user_args: PackedStringArray) -> Dictionary:
	var parsed := {"register": []}
	var i := 0
	while i < user_args.size():
		var arg := user_args[i]
		match arg:
			"--suite", "--out", "--runs", "--seed":
				if i + 1 < user_args.size():
					parsed[arg.trim_prefix("--")] = user_args[i + 1]
					i += 1
			"--register":
				if i + 1 < user_args.size():
					parsed["register"].append(user_args[i + 1])
					i += 1
			"--trace":
				parsed["trace"] = true
		i += 1
	return parsed
