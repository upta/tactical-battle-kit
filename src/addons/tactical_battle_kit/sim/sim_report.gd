class_name SimReport
extends RefCounted

## Writes a suite report to disk: <out>/<suite_id>/<timestamp>/report.json
## and report.md, a per-suite latest.json pointer, and <out>/latest_suite.json.


static func write(report: Dictionary, out_dir: String) -> String:
	var suite_id := str(report.get("suite_id", "suite"))
	var stamp := Time.get_datetime_string_from_system(true, false).replace(":", "").replace("-", "").replace("T", "-")
	var run_dir := out_dir.path_join(suite_id).path_join(stamp)
	var absolute := ProjectSettings.globalize_path(run_dir)
	DirAccess.make_dir_recursive_absolute(absolute)

	_write_text(absolute.path_join("report.json"), JSON.stringify(_without_trace(report), "  "))
	_write_text(absolute.path_join("report.md"), to_markdown(report))
	if report.has("trace"):
		_write_text(absolute.path_join("trace.json"), JSON.stringify(report["trace"], "  "))

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

	var matchups: Array = report.get("matchups", [])
	if not matchups.is_empty():
		var factions: Array = (matchups[0]["aggregate"]["win_rate"] as Dictionary).keys()
		var header := "| Matchup | Sweep | " + " | ".join(factions.map(func(f: String) -> String: return "win " + f)) + " | Draw | Rounds (min/mean/max) | Decisions |"
		var divider := "| --- | --- | " + " | ".join(factions.map(func(_f: String) -> String: return "---")) + " | --- | --- | --- |"
		lines.append(header)
		lines.append(divider)
		for matchup: Dictionary in matchups:
			var aggregate: Dictionary = matchup["aggregate"]
			var cells: Array[String] = []
			cells.append(str(matchup["id"]))
			cells.append(str(matchup["sweep_value"]) if matchup["sweep_value"] != null else "-")
			for faction: String in factions:
				cells.append("%.0f%%" % (float(aggregate["win_rate"].get(faction, 0.0)) * 100.0))
			cells.append("%.0f%%" % (float(aggregate["draw_rate"]) * 100.0))
			cells.append("%d / %.1f / %d" % [int(aggregate["min_rounds"]), float(aggregate["mean_rounds"]), int(aggregate["max_rounds"])])
			cells.append("%.0f" % float(aggregate["mean_decisions"]))
			lines.append("| " + " | ".join(cells) + " |")
		lines.append("")

		for matchup: Dictionary in matchups:
			var aggregate: Dictionary = matchup["aggregate"]
			var label := str(matchup["id"]) + ("" if matchup["sweep_value"] == null else " @ " + str(matchup["sweep_value"]))
			lines.append("## %s" % label)
			lines.append("")
			lines.append("- End reasons: " + _format_rates(aggregate.get("reason", {})))
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
				_format_value(v["actual"]), str(v["comparator"]), _format_value(v["expected"]),
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


static func _format_rates(rates: Dictionary) -> String:
	var parts: Array[String] = []
	for key: String in rates.keys():
		parts.append("%s %.0f%%" % [key, float(rates[key]) * 100.0])
	return ", ".join(parts)


static func _format_value(value: Variant) -> String:
	if value == null:
		return "null"
	if value is float:
		return "%.3f" % float(value)
	return str(value)
