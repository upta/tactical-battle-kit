class_name SimReport
extends RefCounted

## Writes a suite report to disk: <out>/<suite_id>/<timestamp>/report.json,
## report.md and report.html, a per-suite latest.json pointer, and
## <out>/latest_suite.json. A --suites run also gets <out>/summary.json,
## summary.md and summary.html: one row per suite, the worst exit code, and
## the verdict. render() re-emits a page from its JSON, embedding an
## analysis.md found beside a report.

const ANALYSIS_FILE := "analysis.md"


static func write(report: Dictionary, out_dir: String) -> String:
	var suite_id := str(report.get("suite_id", "suite"))
	var stamp := Time.get_datetime_string_from_system(true, false).replace(":", "").replace("-", "").replace("T", "-")
	var run_dir := out_dir.path_join(suite_id).path_join(stamp)
	var absolute := ProjectSettings.globalize_path(run_dir)
	DirAccess.make_dir_recursive_absolute(absolute)

	_write_text(absolute.path_join("report.json"), JSON.stringify(_without_trace(report), "  ", false))
	_write_text(absolute.path_join("report.md"), to_markdown(report))
	_write_text(absolute.path_join("report.html"), SimHtml.render(_without_trace(report)))
	if report.has("trace"):
		_write_text(absolute.path_join("trace.json"), JSON.stringify(report["trace"], "  ", false))

	var pointer := {
		"suite_id": suite_id,
		"status": report.get("status"),
		"exit_code": report.get("exit_code"),
		"path": absolute,
		"timestamp": report.get("timestamp"),
	}
	_write_text(ProjectSettings.globalize_path(out_dir.path_join(suite_id).path_join("latest.json")), JSON.stringify(pointer, "  "))
	_write_text(ProjectSettings.globalize_path(out_dir.path_join("latest_suite.json")), JSON.stringify(pointer, "  "))
	return absolute


## Fold one report per suite into the cross-suite verdict. Each row keeps
## what the RESULT line prints plus the report directory.
static func summarize(reports: Array[Dictionary], worst_exit: int) -> Dictionary:
	var rows: Array[Dictionary] = []
	var passed := 0
	var duration := 0
	for report: Dictionary in reports:
		var exit_code := int(report.get("exit_code", SimSuite.EXIT_RUNTIME_ERROR))
		if exit_code == SimSuite.EXIT_PASS:
			passed += 1
		duration += int(report.get("duration_msec", 0))
		rows.append({
			"suite_id": str(report.get("suite_id", "")),
			"status": str(report.get("status", "runtime_error")),
			"exit_code": exit_code,
			"failed": (report.get("failed", []) as Array).size(),
			"errors": report.get("errors", []),
			"duration_msec": int(report.get("duration_msec", 0)),
			"path": str(report.get("artifacts", "")),
		})
	var status := "pass"
	if worst_exit == SimSuite.EXIT_ASSERTION_FAILURE:
		status = "assertion_failure"
	elif worst_exit != SimSuite.EXIT_PASS:
		status = "runtime_error"
	return {
		"suites": rows,
		"passed": passed,
		"failed": rows.size() - passed,
		"status": status,
		"exit_code": worst_exit,
		"duration_msec": duration,
		"timestamp": Time.get_datetime_string_from_system(true, true),
	}


static func write_summary(summary: Dictionary, out_dir: String) -> String:
	var absolute := ProjectSettings.globalize_path(out_dir)
	DirAccess.make_dir_recursive_absolute(absolute)
	_write_text(absolute.path_join("summary.json"), JSON.stringify(summary, "  ", false))
	_write_text(absolute.path_join("summary.md"), summary_to_markdown(summary))
	_write_text(absolute.path_join("summary.html"), SimHtml.render_summary(summary))
	return absolute


## Re-render a page from its JSON. `target` is a run directory, a
## report.json, an output directory holding summary.json, or that file.
## A report picks up analysis.md from its directory. Returns the absolute
## path of the page written, or "" with an error pushed.
static func render(target: String) -> String:
	var absolute := ProjectSettings.globalize_path(target)
	var json_path := ""
	if absolute.get_file() == "report.json" or absolute.get_file() == "summary.json":
		json_path = absolute
	elif FileAccess.file_exists(absolute.path_join("report.json")):
		json_path = absolute.path_join("report.json")
	elif FileAccess.file_exists(absolute.path_join("summary.json")):
		json_path = absolute.path_join("summary.json")
	else:
		push_error("Nothing to render at %s: expected report.json or summary.json." % absolute)
		return ""
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(json_path))
	if not (data is Dictionary):
		push_error("Could not parse %s." % json_path)
		return ""
	var dir := json_path.get_base_dir()
	var page := ""
	var html := ""
	if json_path.get_file() == "summary.json":
		page = dir.path_join("summary.html")
		html = SimHtml.render_summary(data)
	else:
		page = dir.path_join("report.html")
		var analysis := ""
		var analysis_path := dir.path_join(ANALYSIS_FILE)
		if FileAccess.file_exists(analysis_path):
			analysis = SimHtml.markdown_subset(FileAccess.get_file_as_string(analysis_path))
		html = SimHtml.render(data, analysis)
	_write_text(page, html)
	return page


## file:/// form of an absolute path, for a human's browser.
static func file_url(absolute: String) -> String:
	var normalized := absolute.replace("\\", "/")
	return ("file://" if normalized.begins_with("/") else "file:///") + normalized


static func summary_to_markdown(summary: Dictionary) -> String:
	var lines: Array[String] = []
	lines.append("# Sim suites")
	lines.append("")
	lines.append("**Status:** %s (exit %d) · %d suites, %d passed, %d failed · %d ms · %s" % [
		str(summary["status"]), int(summary["exit_code"]), (summary["suites"] as Array).size(),
		int(summary["passed"]), int(summary["failed"]), int(summary["duration_msec"]), str(summary["timestamp"]),
	])
	lines.append("")
	lines.append("| Suite | Status | Exit | Failed assertions | ms | Report |")
	lines.append("| --- | --- | --- | --- | --- | --- |")
	for row: Dictionary in summary["suites"]:
		var report_path := str(row["path"])
		lines.append("| %s | %s | %d | %d | %d | %s |" % [
			str(row["suite_id"]), str(row["status"]), int(row["exit_code"]), int(row["failed"]),
			int(row["duration_msec"]), "-" if report_path.is_empty() else report_path.path_join("report.md"),
		])
	lines.append("")
	for row: Dictionary in summary["suites"]:
		for error: Variant in row.get("errors", []):
			lines.append("- %s: %s" % [str(row["suite_id"]), str(error)])
	return "\n".join(lines)


static func _without_trace(report: Dictionary) -> Dictionary:
	var copy := report.duplicate()
	if copy.has("trace"):
		var trace: Dictionary = copy["trace"]
		copy["trace"] = {"matchup": trace.get("matchup"), "sweep_value": trace.get("sweep_value"), "seed": trace.get("seed"), "file": "trace.json"}
	return copy


static func _write_text(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write %s" % path)
		return
	file.store_string(text)
	file.close()


static func to_markdown(report: Dictionary) -> String:
	var lines: Array[String] = []
	lines.append("# %s" % str(report.get("suite_id")))
	lines.append("")
	if not str(report.get("description", "")).is_empty():
		lines.append(str(report["description"]))
		lines.append("")
	lines.append("**Status:** %s (exit %d) · runs per cell: %d · seed: %d · %d ms" % [
		str(report.get("status")), int(report.get("exit_code", 0)), int(report.get("runs", 0)),
		int(report.get("seed", 0)), int(report.get("duration_msec", 0)),
	])
	lines.append("")

	if report.has("standings"):
		lines.append_array(_tournament_tables(report))

	var matchups: Array = report.get("matchups", [])
	if not matchups.is_empty():
		var factions: Array = (matchups[0]["aggregate"]["win_rate"] as Dictionary).keys()
		var header := "| Matchup | Sweep | " + " | ".join(factions.map(func(f: String) -> String: return "win " + f)) + " | Draw | Rounds (min/mean/max) | Decisions |"
		var divider := "| --- | --- | " + " | ".join(factions.map(func(_f: String) -> String: return "---")) + " | --- | --- | --- |"
		lines.append(header)
		lines.append(divider)
		for matchup: Dictionary in matchups:
			var aggregate: Dictionary = matchup["aggregate"]
			var ci: Dictionary = aggregate.get("ci95", {})
			var cells: Array[String] = []
			cells.append(str(matchup["id"]) + (" (baseline)" if bool(matchup.get("baseline", false)) else ""))
			cells.append(str(matchup["sweep_value"]) if matchup["sweep_value"] != null else "-")
			for faction: String in factions:
				cells.append(_rate_with_ci(float(aggregate["win_rate"].get(faction, 0.0)), ci.get("win_rate", {}).get(faction)))
			cells.append(_rate_with_ci(float(aggregate["draw_rate"]), ci.get("draw_rate")))
			cells.append("%d / %.1f / %d" % [int(aggregate["min_rounds"]), float(aggregate["mean_rounds"]), int(aggregate["max_rounds"])])
			cells.append("%.0f" % float(aggregate["mean_decisions"]))
			lines.append("| " + " | ".join(cells) + " |")
		lines.append("")
		if matchups.any(func(m: Dictionary) -> bool: return m.has("delta")):
			lines.append_array(_delta_table(matchups, factions))

		for matchup: Dictionary in matchups:
			var aggregate: Dictionary = matchup["aggregate"]
			var label := str(matchup["id"]) + ("" if matchup["sweep_value"] == null else " @ " + str(matchup["sweep_value"]))
			lines.append("## %s" % label)
			lines.append("")
			if matchup.has("delta"):
				lines.append("- vs baseline: " + format_delta_leaves(matchup["delta"]))
			lines.append("- End reasons: " + format_rates(aggregate.get("reason", {})))
			var faction_metrics: Dictionary = aggregate["metrics"].get("faction", {})
			for faction: String in faction_metrics.keys():
				var stats: Dictionary = faction_metrics[faction]
				lines.append("- %s: dealt %.1f, taken %.1f, kills %.1f, deaths %.1f, healed %.1f, survivors %.1f, hp share %.2f, first blood %.0f%%" % [
					faction, float(stats.get("damage_dealt", 0)), float(stats.get("damage_taken", 0)),
					float(stats.get("kills", 0)), float(stats.get("deaths", 0)), float(stats.get("healed", 0)),
					float(stats.get("survivors", 0)), float(stats.get("hp_share", 0)), float(stats.get("first_blood", 0)) * 100.0,
				])
			var custom: Dictionary = aggregate.get("custom", {})
			if not custom.is_empty():
				lines.append("- Custom: " + JSON.stringify(custom))
			lines.append("")

	var verifications: Array = report.get("verifications", [])
	if not verifications.is_empty():
		lines.append("## Assertions")
		lines.append("")
		lines.append("| Result | Metric | Matchup | Sweep | Actual | Comparator | Expected |")
		lines.append("| --- | --- | --- | --- | --- | --- | --- |")
		for v: Dictionary in verifications:
			lines.append("| %s | %s | %s | %s | %s | %s | %s |" % [
				"PASS" if v["passed"] else "FAIL", str(v["metric"]), str(v["matchup"]),
				str(v["sweep_value"]) if v["sweep_value"] != null else "-",
				format_value(v["actual"]), str(v["comparator"]), format_value(v["expected"]),
			])
		lines.append("")

	var errors: Array = report.get("errors", [])
	if not errors.is_empty():
		lines.append("## Errors")
		lines.append("")
		for error: String in errors:
			lines.append("- " + error)
		lines.append("")
	return "\n".join(lines)


## Standings sorted by points, then the matrix: a row's AI beat the column's
## AI this often, both sides and every battle pooled.
static func _tournament_tables(report: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	var standings: Dictionary = report["standings"]
	var matrix: Dictionary = report.get("matrix", {})
	var ids: Array = standings.keys()
	ids.sort_custom(func(a: String, b: String) -> bool: return float(standings[a]["points"]) > float(standings[b]["points"]))
	var battles: Array = report.get("battle", []) if report.get("battle") is Array else [report.get("battle")]
	lines.append("## Standings")
	lines.append("")
	lines.append("Battles: " + ", ".join(battles.map(func(b: Variant) -> String: return str(b))) + " · sides swapped: " + str(bool((report.get("tournament", {}) as Dictionary).get("swap_sides", true))))
	lines.append("")
	lines.append("| AI | Games | W | D | L | Win rate | Points |")
	lines.append("| --- | --- | --- | --- | --- | --- | --- |")
	for ai_id: String in ids:
		var row: Dictionary = standings[ai_id]
		lines.append("| %s | %d | %d | %d | %d | %.0f%% | %.1f |" % [
			ai_id, int(row["games"]), int(row["wins"]), int(row["draws"]), int(row["losses"]),
			float(row["win_rate"]) * 100.0, float(row["points"]),
		])
	lines.append("")
	lines.append("| beats → | " + " | ".join(ids) + " |")
	lines.append("| --- | " + " | ".join(ids.map(func(_i: String) -> String: return "---")) + " |")
	for a: String in ids:
		var cells: Array[String] = []
		for b: String in ids:
			var row: Dictionary = matrix.get(a, {})
			cells.append("-" if a == b or not row.has(b) else "%.0f%%" % (float(row[b]) * 100.0))
		lines.append("| %s | %s |" % [a, " | ".join(cells)])
	lines.append("")
	return lines


static func _rate_with_ci(rate: float, half_width: Variant) -> String:
	if half_width == null:
		return "%.0f%%" % (rate * 100.0)
	return "%.0f%% ±%.0f" % [rate * 100.0, float(half_width) * 100.0]


## One row per non-baseline cell: signed differences from its baseline for
## the headline numbers. The intervals beside the raw numbers above say
## whether a delta clears the noise.
static func _delta_table(matchups: Array, factions: Array) -> Array[String]:
	var lines: Array[String] = []
	lines.append("## Deltas vs baseline")
	lines.append("")
	lines.append("| Matchup | Sweep | " + " | ".join(factions.map(func(f: String) -> String: return "Δ win " + f)) + " | Δ draw | Δ rounds | Δ decisions |")
	lines.append("| --- | --- | " + " | ".join(factions.map(func(_f: String) -> String: return "---")) + " | --- | --- | --- |")
	for matchup: Dictionary in matchups:
		if not matchup.has("delta"):
			continue
		var delta: Dictionary = matchup["delta"]
		var cells: Array[String] = []
		cells.append(str(matchup["id"]))
		cells.append(str(matchup["sweep_value"]) if matchup["sweep_value"] != null else "-")
		for faction: String in factions:
			cells.append(_signed_points(delta.get("win_rate", {}).get(faction)))
		cells.append(_signed_points(delta.get("draw_rate")))
		cells.append(_signed(delta.get("mean_rounds")))
		cells.append(_signed(delta.get("mean_decisions")))
		lines.append("| " + " | ".join(cells) + " |")
	lines.append("")
	return lines


static func _signed_points(value: Variant) -> String:
	return "-" if value == null else "%+.0f pts" % (float(value) * 100.0)


static func _signed(value: Variant) -> String:
	return "-" if value == null else "%+.1f" % float(value)


## The custom and per-faction metric deltas, flattened to "path +x". Def
## and event deltas stay in report.json; here they would drown the line.
static func format_delta_leaves(delta: Dictionary) -> String:
	var parts: Array[String] = []
	_flatten_delta(delta.get("custom", {}), "custom", parts)
	_flatten_delta((delta.get("metrics", {}) as Dictionary).get("faction", {}), "faction", parts)
	return ", ".join(parts) if not parts.is_empty() else "no metric leaves in common"


static func _flatten_delta(value: Variant, prefix: String, parts: Array[String]) -> void:
	if value is Dictionary:
		for key: Variant in value.keys():
			_flatten_delta(value[key], prefix + "." + str(key), parts)
	elif value is float and not is_zero_approx(float(value)):
		parts.append("%s %+.2f" % [prefix, float(value)])


static func format_rates(rates: Dictionary) -> String:
	var parts: Array[String] = []
	for key: String in rates.keys():
		parts.append("%s %.0f%%" % [key, float(rates[key]) * 100.0])
	return ", ".join(parts)


static func format_value(value: Variant) -> String:
	if value == null:
		return "null"
	if value is float:
		return "%.3f" % float(value)
	return str(value)
