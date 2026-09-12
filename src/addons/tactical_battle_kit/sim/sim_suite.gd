class_name SimSuite
extends RefCounted

## A balance suite: one battle, N seeded runs per matchup (AI per faction),
## optionally swept across values of one override path, with assertions on
## the aggregates. Same exit-code contract as the validation kit: 0 pass,
## 1 assertion_failure, 2 runtime_error.
##
## Suite shape:
##   suite_id, description, battle (path | dict), runs, seed,
##   register [script paths with a static register()],
##   overrides {battle|ruleset|unit_defs|terrain_defs: ...},
##   matchups [{id, ai: {faction: ai_id}}],
##   tournament {ais: [...], battles: [...], swap_sides}  (replaces battle + matchups),
##   sweep {path: "unit_defs.cavalry.attack", values: [...]},
##   baseline {sweep_value?, matchup?}  (the cell every other cell is compared to),
##   assertions [{metric, comparator, expected, matchup?, sweep_value?}
##               | {metric, within, of: "baseline", matchup?, sweep_value?}]
##
## Metric paths resolve against a matchup aggregate: win_rate.<faction>,
## draw_rate, mean_rounds, min_rounds, max_rounds, mean_decisions,
## reason.<reason>, metrics.<...>, custom.<...>, and ci95.<any of those>
## for the 95% half-width. In a tournament, standings.<ai>.<field> and
## matrix.<a>.<b> resolve once against the folded tables. A "within"
## assertion resolves against the cell's delta from its baseline.

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

	for registration: Variant in suite.get("register", []):
		var problem := register_pack(str(registration))
		if not problem.is_empty():
			return _fail_runtime(report, problem, started)

	var matchups: Array[Dictionary] = []
	if suite.has("tournament"):
		var expansion := expand_tournament(suite)
		if expansion.has("error"):
			return _fail_runtime(report, str(expansion["error"]), started)
		matchups = expansion["cells"]
		report["battle"] = expansion["battles"]
		report["tournament"] = suite["tournament"]
	else:
		var battle_data := _resolve_battle(suite.get("battle"))
		if battle_data.is_empty():
			return _fail_runtime(report, "Suite '%s' has no loadable battle." % suite_id, started)
		matchups = _resolve_matchups(suite, battle_data)

	var base_overrides := normalize_overrides(suite.get("overrides", {}))
	var sweep_points := _resolve_sweep(suite)
	var trace_kept := false

	for matchup: Dictionary in matchups:
		var battle_data: Dictionary = matchup["battle"]
		for point: Dictionary in sweep_points:
			var overrides: Dictionary = BattleLoader.deep_merge(base_overrides, point["overrides"])
			var results: Array[Dictionary] = []
			for i: int in runs:
				var state := BattleLoader.build(battle_data, overrides)
				if state == null:
					return _fail_runtime(report, "Battle failed to build for matchup '%s'." % str(matchup["id"]), started)
				var ais: Dictionary[String, AiController] = {}
				var ai_map: Dictionary = matchup["ai"]
				for named_faction: Variant in ai_map.keys():
					if not state.factions.has(str(named_faction)):
						return _fail_runtime(report, "Matchup '%s' names faction '%s', which battle '%s' does not have (factions: %s)." % [str(matchup["id"]), str(named_faction), state.battle_id, ", ".join(state.factions)], started)
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
			var cell := {
				"id": matchup["id"],
				"ai": matchup["ai"],
				"sweep_value": point["value"],
				"aggregate": aggregate,
				"runs": _run_summaries(results),
			}
			if matchup.has("tournament"):
				cell["tournament"] = matchup["tournament"]
			report["matchups"].append(cell)

	if report.has("tournament"):
		var standings := fold_standings(report["matchups"])
		report["standings"] = standings["standings"]
		report["matrix"] = standings["matrix"]

	if suite.has("baseline"):
		if not (suite["baseline"] is Dictionary):
			return _fail_runtime(report, "'baseline' must be {\"sweep_value\": v} and/or {\"matchup\": id}.", started)
		report["baseline"] = suite["baseline"]
		var problem := apply_baseline(suite["baseline"], report["matchups"])
		if not problem.is_empty():
			return _fail_runtime(report, problem, started)

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


## Load an AI pack: a script whose static register() puts AIs into the
## AiRegistry. Returns "" or the problem. The CLI resets the registry
## before each suite, so a pack is visible only to the suite that names it
## (or to every suite when it came from --register).
static func register_pack(path: String) -> String:
	var script: GDScript = load(path)
	if script == null:
		return "AI pack did not load: %s" % path
	if not script.has_method("register"):
		return "AI pack has no static register(): %s" % path
	script.call("register")
	return ""


const OVERRIDE_ROOTS: Array[String] = ["battle", "ruleset", "unit_defs", "terrain_defs"]


## Accept dotted keys ("ruleset.heal_range") as well as nested objects, and
## warn about a root the loader will never read: an override that silently
## reaches nothing is a suite that proves nothing.
static func normalize_overrides(raw: Dictionary) -> Dictionary:
	var result := {}
	for key_variant: Variant in raw.keys():
		var key := str(key_variant)
		if key.contains("."):
			BattleLoader.set_dotted_path(result, key, raw[key_variant])
		elif raw[key_variant] is Dictionary and result.has(key):
			result[key] = BattleLoader.deep_merge(result[key], raw[key_variant])
		else:
			result[key] = raw[key_variant]
	for root: Variant in result.keys():
		if not OVERRIDE_ROOTS.has(str(root)):
			push_warning("Override root '%s' is not one of %s and will be ignored." % [str(root), ", ".join(OVERRIDE_ROOTS)])
	return result


static func _resolve_battle(battle: Variant) -> Dictionary:
	if battle is Dictionary:
		return battle
	if battle is String:
		return BattleLoader.read_json(str(battle))
	return {}


## Expand a tournament block into matchups: every unordered AI pair on every
## battle, the first AI on the battle's first declared faction; swap_sides
## adds the reverse. No mirrors (a self-match says nothing about a ranking)
## and no duplicate ids (a variant of an AI registers under its own id).
## Returns {cells, battles} or {error}.
static func expand_tournament(suite: Dictionary) -> Dictionary:
	if suite.has("battle") or suite.has("matchups"):
		return {"error": "A tournament replaces 'battle' and 'matchups'; remove them from the suite."}
	if suite.has("sweep"):
		return {"error": "A tournament cannot be swept in the same suite; standings need one table per sweep value."}
	var block: Dictionary = suite["tournament"]
	var ais: Array[String] = []
	for entry: Variant in block.get("ais", []):
		var ai_id := str(entry)
		if ais.has(ai_id):
			return {"error": "Tournament lists AI '%s' twice." % ai_id}
		ais.append(ai_id)
	if ais.size() < 2:
		return {"error": "A tournament needs at least two AIs."}
	var battles: Array = block.get("battles", [])
	if battles.is_empty():
		return {"error": "A tournament needs at least one battle."}
	var swap := bool(block.get("swap_sides", true))

	var cells: Array[Dictionary] = []
	var battle_ids: Array[String] = []
	for entry: Variant in battles:
		var battle_data := _resolve_battle(entry)
		if battle_data.is_empty():
			return {"error": "Tournament battle did not load: %s" % str(entry)}
		var factions := state_factions(battle_data)
		var battle_id := str(battle_data.get("battle_id", entry))
		if factions.size() != 2:
			return {"error": "Tournament battle '%s' has %d factions; a round-robin needs exactly two." % [battle_id, factions.size()]}
		battle_ids.append(battle_id)
		for a: int in ais.size():
			for b: int in range(a + 1, ais.size()):
				cells.append(_tournament_cell(battle_data, battle_id, factions, ais[a], ais[b]))
				if swap:
					cells.append(_tournament_cell(battle_data, battle_id, factions, ais[b], ais[a]))
	return {"cells": cells, "battles": battle_ids}


static func _tournament_cell(battle_data: Dictionary, battle_id: String, factions: Array[String], first: String, second: String) -> Dictionary:
	return {
		"id": "%s:%s_vs_%s" % [battle_id, first, second],
		"ai": {factions[0]: first, factions[1]: second},
		"battle": battle_data,
		"tournament": {"battle": battle_id, "first": first, "second": second},
	}


## Per-AI standings and the pairwise matrix, folded from each cell's run
## list so counts are exact. points = wins + draws / 2; matrix[a][b] is a's
## win rate over every game a and b played, both sides and all battles.
static func fold_standings(cells: Array) -> Dictionary:
	var standings := {}
	var pair_wins := {}
	var pair_games := {}
	for cell: Dictionary in cells:
		if not cell.has("tournament"):
			continue
		var info: Dictionary = cell["tournament"]
		var first := str(info["first"])
		var second := str(info["second"])
		var ai_map: Dictionary = cell["ai"]
		var faction_of := {}
		for faction: String in ai_map.keys():
			faction_of[str(ai_map[faction])] = faction
		for ai_id: String in [first, second]:
			if not standings.has(ai_id):
				standings[ai_id] = {"games": 0, "wins": 0, "draws": 0, "losses": 0}
			if not pair_wins.has(ai_id):
				pair_wins[ai_id] = {}
				pair_games[ai_id] = {}
		for run: Dictionary in cell["runs"]:
			var winner := str(run["winner"])
			for ai_id: String in [first, second]:
				var other := second if ai_id == first else first
				var row: Dictionary = standings[ai_id]
				row["games"] += 1
				pair_games[ai_id][other] = int(pair_games[ai_id].get(other, 0)) + 1
				if winner.is_empty():
					row["draws"] += 1
				elif winner == str(faction_of[ai_id]):
					row["wins"] += 1
					pair_wins[ai_id][other] = int(pair_wins[ai_id].get(other, 0)) + 1
				else:
					row["losses"] += 1
	for ai_id: String in standings.keys():
		var row: Dictionary = standings[ai_id]
		var games := int(row["games"])
		row["win_rate"] = float(row["wins"]) / float(maxi(games, 1))
		row["points"] = float(row["wins"]) + float(row["draws"]) * 0.5
	var matrix := {}
	for ai_id: String in pair_games.keys():
		matrix[ai_id] = {}
		for other: String in pair_games[ai_id].keys():
			matrix[ai_id][other] = float(pair_wins[ai_id].get(other, 0)) / float(maxi(int(pair_games[ai_id][other]), 1))
	return {"standings": standings, "matrix": matrix}


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
		matchups.append({"id": str(entry.get("id", "matchup_%d" % matchups.size())), "ai": entry.get("ai", {}), "battle": battle_data})
	if matchups.is_empty():
		var ai := {}
		for entry: Variant in battle_data.get("factions", []):
			if entry is Dictionary and entry.has("ai"):
				ai[str(entry["id"])] = str(entry["ai"])
		matchups.append({"id": "default", "ai": ai, "battle": battle_data})
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
		# Through normalize_overrides so a sweep root outside OVERRIDE_ROOTS
		# gets the same warning an overrides block does instead of a silent
		# sweep of nothing.
		var overrides := normalize_overrides({path: value})
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
	var rounds_squares := 0
	var decisions_squares := 0
	var metric_sums := {}
	var metric_squares := {}
	var custom_sums := {}
	var custom_squares := {}
	for result: Dictionary in results:
		var winner := str(result["winner"])
		if winner.is_empty():
			draws += 1
		else:
			wins[winner] = int(wins.get(winner, 0)) + 1
		var reason := str(result["reason"])
		reasons[reason] = int(reasons.get(reason, 0)) + 1
		var rounds := int(result["rounds"])
		var decisions := int(result["decisions"])
		rounds_total += rounds
		rounds_squares += rounds * rounds
		decisions_total += decisions
		decisions_squares += decisions * decisions
		min_rounds = rounds if min_rounds < 0 else mini(min_rounds, rounds)
		max_rounds = maxi(max_rounds, rounds)
		_accumulate(metric_sums, metric_squares, result["metrics"])
		_accumulate(custom_sums, custom_squares, result["custom"])

	var win_rate := {}
	var win_ci := {}
	for faction: String in wins.keys():
		win_rate[faction] = float(wins[faction]) / float(maxi(count, 1))
		win_ci[faction] = wilson_half_width(int(wins[faction]), count)
	var reason_rate := {}
	var reason_ci := {}
	for reason: String in reasons.keys():
		reason_rate[reason] = float(reasons[reason]) / float(maxi(count, 1))
		reason_ci[reason] = wilson_half_width(int(reasons[reason]), count)
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
		"ci95": {
			"win_rate": win_ci,
			"draw_rate": wilson_half_width(draws, count),
			"mean_rounds": mean_half_width(float(rounds_total), float(rounds_squares), count),
			"mean_decisions": mean_half_width(float(decisions_total), float(decisions_squares), count),
			"reason": reason_ci,
			"metrics": _half_widths(metric_sums, metric_squares, count),
			"custom": _half_widths(custom_sums, custom_squares, count),
		},
	}


const Z95 := 1.959964


## Half the width of the Wilson score interval for k successes in n trials.
## Unlike the normal approximation it is not zero at 0% or 100%, which is
## where a 30-run suite often sits.
static func wilson_half_width(successes: int, n: int) -> float:
	if n <= 0:
		return 0.0
	var p := float(successes) / float(n)
	var z2 := Z95 * Z95
	var denominator := 1.0 + z2 / float(n)
	var spread := Z95 * sqrt(p * (1.0 - p) / float(n) + z2 / (4.0 * float(n) * float(n)))
	return spread / denominator


## 1.96 standard errors of a mean from its sum and sum of squares.
static func mean_half_width(total: float, squares: float, n: int) -> float:
	if n <= 1:
		return 0.0
	var mean := total / float(n)
	var variance := maxf(squares / float(n) - mean * mean, 0.0) * float(n) / float(n - 1)
	return Z95 * sqrt(variance / float(n))


static func _accumulate(sums: Dictionary, squares: Dictionary, values: Variant) -> void:
	if not (values is Dictionary):
		return
	for key: Variant in values.keys():
		var value: Variant = values[key]
		if value is Dictionary:
			if not sums.has(key) or not (sums[key] is Dictionary):
				sums[key] = {}
				squares[key] = {}
			_accumulate(sums[key], squares[key], value)
		elif value is int or value is float or value is bool:
			sums[key] = float(sums.get(key, 0.0)) + float(value)
			squares[key] = float(squares.get(key, 0.0)) + float(value) * float(value)


static func _divide(sums: Dictionary, count: int) -> Dictionary:
	var result := {}
	for key: Variant in sums.keys():
		if sums[key] is Dictionary:
			result[key] = _divide(sums[key], count)
		else:
			result[key] = float(sums[key]) / float(maxi(count, 1))
	return result


static func _half_widths(sums: Dictionary, squares: Dictionary, count: int) -> Dictionary:
	var result := {}
	for key: Variant in sums.keys():
		if sums[key] is Dictionary:
			result[key] = _half_widths(sums[key], squares[key], count)
		else:
			result[key] = mean_half_width(float(sums[key]), float(squares[key]), count)
	return result


# --- Baseline ---


## Pair every cell with its baseline and store the leaf-wise difference.
## baseline is {sweep_value} (same matchup, that value), {matchup} (that
## matchup, same sweep value) or both (one fixed cell). Returns "" or the
## problem.
static func apply_baseline(spec: Dictionary, cells: Array) -> String:
	var by_key := {}
	for cell: Dictionary in cells:
		by_key[_cell_key(cell["id"], cell["sweep_value"])] = cell
	var found := false
	for cell: Dictionary in cells:
		var matchup_id: String = str(spec["matchup"]) if spec.has("matchup") else str(cell["id"])
		var sweep_value: Variant = spec["sweep_value"] if spec.has("sweep_value") else cell["sweep_value"]
		var baseline: Variant = by_key.get(_cell_key(matchup_id, sweep_value))
		if baseline == null:
			continue
		found = true
		var is_baseline: bool = baseline == cell
		cell["baseline"] = is_baseline
		if not is_baseline:
			cell["delta"] = _delta(cell["aggregate"], (baseline as Dictionary)["aggregate"])
	if not found:
		return "Baseline %s names no cell in this suite." % JSON.stringify(spec)
	return ""


static func _cell_key(matchup_id: String, sweep_value: Variant) -> String:
	return "%s@%s" % [matchup_id, "" if sweep_value == null else str(sweep_value)]


## Leaf-wise cell minus baseline for the paths ci95 covers; a leaf missing
## on either side is skipped rather than read as zero.
static func _delta(cell: Dictionary, baseline: Dictionary) -> Dictionary:
	var result := {}
	for key: Variant in ["win_rate", "draw_rate", "mean_rounds", "mean_decisions", "reason", "metrics", "custom"]:
		if not cell.has(key) or not baseline.has(key):
			continue
		var diff: Variant = _delta_value(cell[key], baseline[key])
		if diff != null:
			result[key] = diff
	return result


static func _delta_value(a: Variant, b: Variant) -> Variant:
	if a is Dictionary and b is Dictionary:
		var result := {}
		for key: Variant in a.keys():
			if not b.has(key):
				continue
			var diff: Variant = _delta_value(a[key], b[key])
			if diff != null:
				result[key] = diff
		return result
	if _numeric(a) and _numeric(b):
		return float(a) - float(b)
	return null


# --- Assertions ---


func _evaluate_assertions(suite: Dictionary, report: Dictionary) -> void:
	for assertion: Dictionary in suite.get("assertions", []):
		var metric := str(assertion.get("metric", ""))
		var comparator := str(assertion.get("comparator", "eq"))
		var expected: Variant = assertion.get("expected")
		if metric.begins_with("standings.") or metric.begins_with("matrix."):
			var tables := {"standings": report.get("standings", {}), "matrix": report.get("matrix", {})}
			var actual: Variant = resolve_metric(tables, metric)
			var passed := actual != null and compare(actual, comparator, expected)
			var verification := {"metric": metric, "comparator": comparator, "expected": expected, "actual": actual, "matchup": "tournament", "sweep_value": null, "passed": passed}
			report["verifications"].append(verification)
			if not passed:
				report["failed"].append(verification)
			continue
		var relative := assertion.has("within")
		if relative:
			comparator = "within"
			expected = assertion["within"]
			if str(assertion.get("of", "baseline")) != "baseline" or not report.has("baseline"):
				var bad := {"metric": metric, "comparator": comparator, "expected": expected, "actual": null, "matchup": assertion.get("matchup", "*"), "sweep_value": assertion.get("sweep_value"), "passed": false, "message": "'within' needs a suite 'baseline' and 'of': \"baseline\""}
				report["verifications"].append(bad)
				report["failed"].append(bad)
				continue
		var matched_any := false
		for matchup: Dictionary in report["matchups"]:
			if assertion.has("matchup") and str(assertion["matchup"]) != str(matchup["id"]):
				continue
			if assertion.has("sweep_value") and assertion["sweep_value"] != matchup["sweep_value"]:
				continue
			if relative and not matchup.has("delta"):
				continue
			matched_any = true
			var actual: Variant
			var passed: bool
			if relative:
				# A delta leaf that does not exist is a typo, not "no change".
				actual = resolve_metric(matchup["delta"], metric, false)
				passed = actual != null and absf(float(actual)) <= float(expected)
			else:
				actual = resolve_metric(matchup["aggregate"], metric)
				passed = actual != null and compare(actual, comparator, expected)
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
## (no run ended by that reason, nobody of that faction won) unless
## missing_leaf_is_zero is false. A missing table is null and fails the
## assertion.
static func resolve_metric(aggregate: Dictionary, path: String, missing_leaf_is_zero: bool = true) -> Variant:
	var cursor: Variant = aggregate
	var keys := path.split(".")
	for i: int in keys.size():
		var key := keys[i]
		if not (cursor is Dictionary):
			return null
		var table: Dictionary = cursor
		if table.has(key):
			cursor = table[key]
		elif i == keys.size() - 1 and missing_leaf_is_zero:
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
