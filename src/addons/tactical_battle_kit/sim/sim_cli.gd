extends SceneTree

# Headless entry point for balance suites. No scene, no window, no autoloads
# needed, which is why it runs in CI where the screenshot suite cannot:
#
#   godot --headless --path <project> --script res://addons/tactical_battle_kit/sim/sim_cli.gd -- \
#     (--suite res://sim/suites/<name>.json | --suites res://sim/suites) \
#     [--out res://artifacts/sim] [--runs N] [--seed S] [--trace] \
#     [--register res://path/to/registration.gd]
#
# --suite runs one suite; --suites runs every *.json in a directory, in name
# order, in this one process. Every suite prints "RESULT {json}", an
# "ARTIFACTS <dir>" line and one "FAILED ..." line per failed assertion;
# --suites ends with "SUMMARY {json}" and writes <out>/summary.md. The exit
# code is 0 (pass), 1 (assertion failure) or 2 (runtime error), the worst
# across suites. --register loads a script and calls its static register()
# so a game's AIs are in the AiRegistry before any suite names them; a suite
# can do the same for itself with a "register" list.

const DEFAULT_OUT := "res://artifacts/sim"


func _initialize() -> void:
	var args := _parse_args(OS.get_cmdline_user_args())
	var suite_path := str(args.get("suite", ""))
	var suites_dir := str(args.get("suites", ""))
	if suite_path.is_empty() == suites_dir.is_empty():
		_usage_error("sim_cli: exactly one of --suite <path> or --suites <dir> is required.")
		return

	for registration: String in args.get("register", []):
		var problem := SimSuite.register_pack(registration)
		if not problem.is_empty():
			_usage_error("sim_cli: --register failed: " + problem)
			return

	var out_dir := str(args.get("out", DEFAULT_OUT))
	var paths: Array[String] = []
	if not suite_path.is_empty():
		paths.append(suite_path)
	else:
		paths = _list_suites(suites_dir)
		if paths.is_empty():
			_usage_error("sim_cli: no *.json suites under %s." % suites_dir)
			return

	var reports: Array[Dictionary] = []
	var worst := SimSuite.EXIT_PASS
	for path: String in paths:
		var report := _run_one(path, args, out_dir)
		reports.append(report)
		worst = maxi(worst, int(report.get("exit_code", SimSuite.EXIT_RUNTIME_ERROR)))

	if suites_dir.is_empty():
		_quit(worst)
		return
	var summary := SimReport.summarize(reports, worst)
	SimReport.write_summary(summary, out_dir)
	print("SUMMARY " + JSON.stringify(_summary_line(summary)))
	_quit(worst)


func _run_one(path: String, args: Dictionary, out_dir: String) -> Dictionary:
	var suite := SimSuite.load_file(path)
	var report: Dictionary
	var artifacts := ""
	if suite.is_empty():
		report = {"suite_id": path.get_file().get_basename(), "status": "runtime_error", "exit_code": SimSuite.EXIT_RUNTIME_ERROR, "errors": ["suite did not load: " + path]}
	else:
		var runner := SimSuite.new()
		runner.runs_override = int(args.get("runs", 0))
		runner.seed_override = int(args.get("seed", -1))
		runner.trace = bool(args.get("trace", false))
		report = runner.run(suite)
		artifacts = SimReport.write(report, out_dir)
	report["artifacts"] = artifacts
	_print_result(report, artifacts)
	return report


func _print_result(report: Dictionary, out_dir: String) -> void:
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


static func _summary_line(summary: Dictionary) -> Dictionary:
	return {
		"suites": (summary["suites"] as Array).size(),
		"passed": summary["passed"],
		"failed": summary["failed"],
		"status": summary["status"],
		"exit_code": summary["exit_code"],
		"duration_msec": summary["duration_msec"],
	}


func _usage_error(message: String) -> void:
	push_error(message)
	_print_result({"status": "runtime_error", "exit_code": SimSuite.EXIT_RUNTIME_ERROR, "errors": [message]}, "")
	_quit(SimSuite.EXIT_RUNTIME_ERROR)


func _quit(code: int) -> void:
	AiRegistry.clear()
	quit(code)


static func _list_suites(dir_path: String) -> Array[String]:
	var paths: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return paths
	for name: String in dir.get_files():
		if name.get_extension() == "json":
			paths.append(dir_path.path_join(name))
	paths.sort()
	return paths


static func _parse_args(user_args: PackedStringArray) -> Dictionary:
	var parsed := {"register": []}
	var i := 0
	while i < user_args.size():
		var arg := user_args[i]
		match arg:
			"--suite", "--suites", "--out", "--runs", "--seed":
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
