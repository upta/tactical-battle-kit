class_name SimSuite
extends RefCounted

## A balance suite: one battle, N seeded runs per matchup (AI per faction),
## optionally swept across values of one override path, with assertions on
## the aggregates. Same exit-code contract as the validation kit: 0 pass,
## 1 assertion_failure, 2 runtime_error.
##
## Suite shape:
##   suite_id, description, battle (path | dict), runs, seed,
##   overrides {battle|ruleset|unit_defs|terrain_defs: ...},
##   matchups [{id, ai: {faction: ai_id}}],
##   sweep {path: "unit_defs.cavalry.attack", values: [...]},
##   assertions [{metric, comparator, expected, matchup?, sweep_value?}]
##
## Metric paths resolve against a matchup aggregate: win_rate.<faction>,
## draw_rate, mean_rounds, min_rounds, max_rounds, mean_decisions,
## reason.<reason>, metrics.<...>, custom.<...>.

const EXIT_PASS := 0
const EXIT_ASSERTION_FAILURE := 1
const EXIT_RUNTIME_ERROR := 2

var runs_override: int = 0
var seed_override: int = -1
var trace: bool = false


static func load_file(path: String) -> Dictionary:
	return BattleLoader.read_json(path)


func run(suite: Dictionary) -> Dictionary:
	var started := Time.get_ticks_msec()
	var suite_id := str(suite.get("suite_id", "suite"))
	var runs := runs_override if runs_override > 0 else int(suite.get("runs", 100))
	var base_seed := seed_override if seed_override >= 0 else int(suite.get("seed", 1))
	var report := {
		"suite_id": suite_id,
		"description": str(suite.get("description", "")),
		"runs": runs,
		"seed": base_seed,
		"battle": suite.get("battle", ""),
		"sweep": suite.get("sweep", {}),
		"matchups": [],
		"verifications": [],
		"failed": [],
		"errors": [],
		"status": "pass",
		"exit_code": EXIT_PASS,
		"timestamp": Time.get_datetime_string_from_system(true, true),
	}

	var battle_data := _resolve_battle(suite)
	if battle_data.is_empty():
		return _fail_runtime(report, "Suite '%s' has no loadable battle." % suite_id, started)

	var base_overrides: Dictionary = suite.get("overrides", {})
	var matchups := _resolve_matchups(suite, battle_data)
	var sweep_points := _resolve_sweep(suite)
	var trace_kept := false

	for matchup: Dictionary in matchups:
		for point: Dictionary in sweep_points:
			var overrides: Dictionary = BattleLoader.deep_merge(base_overrides, point["overrides"])
			var results: Array[Dictionary] = []
			for i: int in runs:
				var state := BattleLoader.build(battle_data, overrides)
				if state == null:
					return _fail_runtime(report, "Battle failed to build for matchup '%s'." % str(matchup["id"]), started)
				var ais: Dictionary[String, AiController] = {}
				var ai_map: Dictionary = matchup["ai"]
				for faction: String in state.factions:
					var ai_id := str(ai_map.get(faction, state.faction_ai.get(faction, "random")))
					var ai := AiRegistry.create(ai_id)
					if ai == null:
						return _fail_runtime(report, "Unknown AI '%s' for faction '%s'." % [ai_id, faction], started)
					ais[faction] = ai
				var simulator := BattleSimulator.new()
				simulator.trace = trace and not trace_kept
				var result := simulator.run(state, ais, BattleRng.new(base_seed + i))
				result["seed"] = base_seed + i
				if simulator.trace:
					report["trace"] = {
						"matchup": matchup["id"],
						"sweep_value": point["value"],
						"seed": result["seed"],
						"events": result["events"],
						"final_state": result["final_state"],
					}
					result.erase("events")
					result.erase("final_state")
					trace_kept = true
				results.append(result)
			var aggregate := aggregate_results(results, state_factions(battle_data))
			report["matchups"].append({
				"id": matchup["id"],
				"ai": matchup["ai"],
				"sweep_value": point["value"],
				"aggregate": aggregate,
				"runs": _run_summaries(results),
			})

	_evaluate_assertions(suite, report)
	report["duration_msec"] = Time.get_ticks_msec() - started
	return report


func _fail_runtime(report: Dictionary, message: String, started: int) -> Dictionary:
	push_error(message)
	report["errors"].append(message)
	report["status"] = "runtime_error"
	report["exit_code"] = EXIT_RUNTIME_ERROR
	report["duration_msec"] = Time.get_ticks_msec() - started
	return report


func _resolve_battle(suite: Dictionary) -> Dictionary:
	var battle: Variant = suite.get("battle")
	if battle is Dictionary:
		return battle
	if battle is String:
		return BattleLoader.read_json(str(battle))
	return {}


static func state_factions(battle_data: Dictionary) -> Array[String]:
	var factions: Array[String] = []
	for entry: Variant in battle_data.get("factions", []):
		factions.append(str(entry.get("id")) if entry is Dictionary else str(entry))
	if factions.is_empty():
		for unit: Dictionary in battle_data.get("units", []):
			var faction := str(unit.get("faction"))
			if not factions.has(faction):
				factions.append(faction)
	return factions


func _resolve_matchups(suite: Dictionary, battle_data: Dictionary) -> Array[Dictionary]:
	var matchups: Array[Dictionary] = []
	for entry: Dictionary in suite.get("matchups", []):
		matchups.append({"id": str(entry.get("id", "matchup_%d" % matchups.size())), "ai": entry.get("ai", {})})
	if matchups.is_empty():
		var ai := {}
		for entry: Variant in battle_data.get("factions", []):
			if entry is Dictionary and entry.has("ai"):
				ai[str(entry["id"])] = str(entry["ai"])
		matchups.append({"id": "default", "ai": ai})
	return matchups


func _resolve_sweep(suite: Dictionary) -> Array[Dictionary]:
	var points: Array[Dictionary] = []
	var sweep: Dictionary = suite.get("sweep", {})
	var path := str(sweep.get("path", ""))
	var values: Array = sweep.get("values", [])
	if path.is_empty() or values.is_empty():
		points.append({"value": null, "overrides": {}})
		return points
	for value: Variant in values:
		var overrides := {}
		BattleLoader.set_dotted_path(overrides, path, value)
		points.append({"value": value, "overrides": overrides})
	return points


static func _run_summaries(results: Array[Dictionary]) -> Array:
	var summaries: Array = []
	for result: Dictionary in results:
		summaries.append({
			"seed": result["seed"],
			"winner": result["winner"],
			"reason": result["reason"],
			"rounds": result["rounds"],
		})
	return summaries


# --- Aggregation ---


static func aggregate_results(results: Array[Dictionary], factions: Array[String]) -> Dictionary:
	var count := results.size()
	var wins := {}
	var reasons := {}
	var draws := 0
	var rounds_total := 0
	var decisions_total := 0
	var min_rounds := -1
	var max_rounds := 0
	for faction: String in factions:
		wins[faction] = 0
	var metric_sums := {}
	var custom_sums := {}
	for result: Dictionary in results:
		var winner := str(result["winner"])
		if winner.is_empty():
			draws += 1
		else:
			wins[winner] = int(wins.get(winner, 0)) + 1
		var reason := str(result["reason"])
		reasons[reason] = int(reasons.get(reason, 0)) + 1
		var rounds := int(result["rounds"])
		rounds_total += rounds
		decisions_total += int(result["decisions"])
		min_rounds = rounds if min_rounds < 0 else mini(min_rounds, rounds)
		max_rounds = maxi(max_rounds, rounds)
		_accumulate(metric_sums, result["metrics"])
		_accumulate(custom_sums, result["custom"])

	var win_rate := {}
	for faction: String in wins.keys():
		win_rate[faction] = float(wins[faction]) / float(maxi(count, 1))
	var reason_rate := {}
	for reason: String in reasons.keys():
		reason_rate[reason] = float(reasons[reason]) / float(maxi(count, 1))
	return {
		"runs": count,
		"win_rate": win_rate,
		"draw_rate": float(draws) / float(maxi(count, 1)),
		"mean_rounds": float(rounds_total) / float(maxi(count, 1)),
		"min_rounds": maxi(min_rounds, 0),
		"max_rounds": max_rounds,
		"mean_decisions": float(decisions_total) / float(maxi(count, 1)),
		"reason": reason_rate,
		"metrics": _divide(metric_sums, count),
		"custom": _divide(custom_sums, count),
	}


static func _accumulate(sums: Dictionary, values: Variant) -> void:
	if not (values is Dictionary):
		return
	for key: Variant in values.keys():
		var value: Variant = values[key]
		if value is Dictionary:
			if not sums.has(key) or not (sums[key] is Dictionary):
				sums[key] = {}
			_accumulate(sums[key], value)
		elif value is int or value is float or value is bool:
			sums[key] = float(sums.get(key, 0.0)) + float(value)


static func _divide(sums: Dictionary, count: int) -> Dictionary:
	var result := {}
	for key: Variant in sums.keys():
		if sums[key] is Dictionary:
			result[key] = _divide(sums[key], count)
		else:
			result[key] = float(sums[key]) / float(maxi(count, 1))
	return result


# --- Assertions ---


func _evaluate_assertions(suite: Dictionary, report: Dictionary) -> void:
	for assertion: Dictionary in suite.get("assertions", []):
		var metric := str(assertion.get("metric", ""))
		var comparator := str(assertion.get("comparator", "eq"))
		var expected: Variant = assertion.get("expected")
		var matched_any := false
		for matchup: Dictionary in report["matchups"]:
			if assertion.has("matchup") and str(assertion["matchup"]) != str(matchup["id"]):
				continue
			if assertion.has("sweep_value") and assertion["sweep_value"] != matchup["sweep_value"]:
				continue
			matched_any = true
			var actual: Variant = resolve_metric(matchup["aggregate"], metric)
			var passed := actual != null and compare(actual, comparator, expected)
			var verification := {
				"metric": metric,
				"comparator": comparator,
				"expected": expected,
				"actual": actual,
				"matchup": matchup["id"],
				"sweep_value": matchup["sweep_value"],
				"passed": passed,
			}
			report["verifications"].append(verification)
			if not passed:
				report["failed"].append(verification)
		if not matched_any:
			var orphan := {"metric": metric, "comparator": comparator, "expected": expected, "actual": null, "matchup": assertion.get("matchup", "*"), "sweep_value": assertion.get("sweep_value"), "passed": false, "message": "no matchup matched this assertion"}
			report["verifications"].append(orphan)
			report["failed"].append(orphan)
	if not report["failed"].is_empty() and report["exit_code"] == EXIT_PASS:
		report["status"] = "assertion_failure"
		report["exit_code"] = EXIT_ASSERTION_FAILURE


## A leaf missing from an existing table of rates or counts reads as 0.0
## (no run ended by that reason, nobody of that faction won). A missing
## table is null and fails the assertion.
static func resolve_metric(aggregate: Dictionary, path: String) -> Variant:
	var cursor: Variant = aggregate
	var keys := path.split(".")
	for i: int in keys.size():
		var key := keys[i]
		if not (cursor is Dictionary):
			return null
		var table: Dictionary = cursor
		if table.has(key):
			cursor = table[key]
		elif i == keys.size() - 1:
			return 0.0
		else:
			return null
	return cursor


static func compare(actual: Variant, comparator: String, expected: Variant) -> bool:
	match comparator:
		"eq", "==":
			return is_equal_approx(float(actual), float(expected)) if _numeric(actual) and _numeric(expected) else actual == expected
		"neq", "!=":
			return not compare(actual, "eq", expected)
		"gt", ">":
			return float(actual) > float(expected)
		"gte", ">=":
			return float(actual) >= float(expected)
		"lt", "<":
			return float(actual) < float(expected)
		"lte", "<=":
			return float(actual) <= float(expected)
	push_error("Unknown comparator '%s'." % comparator)
	return false


static func _numeric(value: Variant) -> bool:
	return value is int or value is float or value is bool
