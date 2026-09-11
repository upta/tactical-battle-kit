class_name SimHtml
extends RefCounted

## Renders report.json and summary.json as self-contained pages: one style
## block, no scripts, no external resources, so a page opens from disk in
## any environment. The markup is XHTML-strict (every tag closed, all text
## escaped) so src/tools/check_reports.gd can parse it. An analysis.md in
## the run directory is embedded at the top through markdown_subset().

const CSS := """
:root { --bg: #fbfaf7; --fg: #1f1f1f; --muted: #6b6b6b; --line: #dedad2; --card: #ffffff;
  --accent: #2f6fd6; --accent2: #d6772f; --pass: #2e8b57; --fail: #c0392b; --band: rgba(47,111,214,0.18); }
@media (prefers-color-scheme: dark) { :root { --bg: #17191d; --fg: #e8e6e1; --muted: #9a9a9a; --line: #33363c;
  --card: #1f2227; --accent: #6fa0ff; --accent2: #ffa45c; --pass: #5fcf8a; --fail: #ff6b5b; --band: rgba(111,160,255,0.22); } }
body { margin: 0; padding: 2rem; background: var(--bg); color: var(--fg); font: 15px/1.45 system-ui, sans-serif; }
main { max-width: 1100px; margin: 0 auto; }
h1 { font-size: 1.6rem; margin: 0 0 .25rem; } h2 { font-size: 1.15rem; margin: 2rem 0 .5rem; } h3 { font-size: 1rem; margin: 1.25rem 0 .25rem; }
p.desc { color: var(--muted); margin: 0 0 1rem; max-width: 80ch; }
.meta { color: var(--muted); font-size: .9rem; margin-bottom: 1rem; }
.pill { display: inline-block; padding: .1rem .55rem; border-radius: 999px; font-weight: 600; font-size: .85rem; color: #fff; }
.pill.pass { background: var(--pass); } .pill.fail { background: var(--fail); }
.scroll { overflow-x: auto; margin: .5rem 0 1rem; }
table { border-collapse: collapse; width: 100%; margin: 0; font-size: .92rem; }
th, td { text-align: left; padding: .4rem .6rem; border-bottom: 1px solid var(--line); vertical-align: middle; white-space: nowrap; }
th { color: var(--muted); font-weight: 600; font-size: .82rem; text-transform: uppercase; letter-spacing: .03em; }
td.num { text-align: right; font-variant-numeric: tabular-nums; }
.bar { position: relative; height: 1.15rem; min-width: 7rem; background: var(--line); border-radius: 3px; overflow: hidden; }
.bar .fill { position: absolute; top: 0; bottom: 0; left: 0; background: var(--accent); opacity: .55; }
.bar .ci { position: absolute; top: 82%; height: 14%; background: var(--fg); opacity: .55; }
.bar span { position: absolute; left: .4rem; top: 0; line-height: 1.15rem; font-size: .8rem; font-variant-numeric: tabular-nums; }
.delta { position: relative; height: 1.15rem; min-width: 8rem; background: var(--line); border-radius: 3px; overflow: hidden; }
.delta .zero { position: absolute; top: 0; bottom: 0; left: 50%; width: 1px; background: var(--fg); opacity: .5; }
.delta .fill { position: absolute; top: 0; bottom: 0; opacity: .6; } .delta .pos { background: var(--pass); } .delta .neg { background: var(--fail); }
.delta span { position: absolute; left: .4rem; top: 0; line-height: 1.15rem; font-size: .8rem; font-variant-numeric: tabular-nums; }
.heat { text-align: center; font-variant-numeric: tabular-nums; }
section.analysis { background: var(--card); border: 1px solid var(--line); border-radius: 8px; padding: 1rem 1.25rem; margin: 1rem 0 1.5rem; }
section.analysis h2 { margin-top: 0; }
.ok { color: var(--pass); font-weight: 600; } .bad { color: var(--fail); font-weight: 600; }
ul.details { margin: .25rem 0 .75rem; padding-left: 1.25rem; font-size: .92rem; } ul.details li { margin: .15rem 0; }
code { font-family: ui-monospace, Consolas, monospace; font-size: .88em; background: var(--line); padding: 0 .25rem; border-radius: 3px; }
svg.sweep { width: 100%; max-width: 720px; height: auto; display: block; margin: .5rem 0 1rem; }
svg.sweep text { fill: var(--muted); font-size: 12px; }
svg.sweep .axis { stroke: var(--line); }
.legend { color: var(--muted); font-size: .85rem; margin-bottom: .5rem; }
.swatch { display: inline-block; width: .8rem; height: .8rem; border-radius: 2px; vertical-align: -1px; margin-right: .3rem; }
a { color: var(--accent); }
"""

const SERIES_COLORS: Array[String] = ["var(--accent)", "var(--accent2)", "#7b4fd6", "#2fa8a0"]


static func render(report: Dictionary, analysis_html: String = "") -> String:
	var body: Array[String] = []
	var status := str(report.get("status", "runtime_error"))
	body.append("<h1>%s</h1>" % esc(str(report.get("suite_id", "suite"))))
	if not str(report.get("description", "")).is_empty():
		body.append("<p class=\"desc\">%s</p>" % esc(str(report["description"])))
	body.append("<div class=\"meta\"><span class=\"pill %s\">%s</span> exit %d · runs per cell %d · seed %d · %d ms · %s</div>" % [
		"pass" if status == "pass" else "fail", esc(status), int(report.get("exit_code", 0)), int(report.get("runs", 0)),
		int(report.get("seed", 0)), int(report.get("duration_msec", 0)), esc(str(report.get("timestamp", ""))),
	])
	if not analysis_html.is_empty():
		body.append("<section class=\"analysis\" id=\"analysis\">%s</section>" % analysis_html)

	var matchups: Array = report.get("matchups", [])
	if report.has("standings"):
		body.append_array(_standings(report))
	if not matchups.is_empty():
		var factions: Array = (matchups[0]["aggregate"]["win_rate"] as Dictionary).keys()
		body.append_array(_cells(matchups, factions))
		if matchups.any(func(m: Dictionary) -> bool: return m.has("delta")):
			body.append_array(_deltas(matchups, factions))
		body.append_array(_sweep_chart(report, matchups, factions))
		body.append_array(_details(matchups))
	body.append_array(_assertions(report))
	body.append_array(_errors(report))
	return _page(str(report.get("suite_id", "suite")), body)


static func render_summary(summary: Dictionary) -> String:
	var body: Array[String] = []
	var status := str(summary.get("status", "runtime_error"))
	var rows: Array = summary.get("suites", [])
	body.append("<h1>Sim suites</h1>")
	body.append("<div class=\"meta\"><span class=\"pill %s\">%s</span> exit %d · %d suites, %d passed, %d failed · %d ms · %s</div>" % [
		"pass" if status == "pass" else "fail", esc(status), int(summary.get("exit_code", 0)), rows.size(),
		int(summary.get("passed", 0)), int(summary.get("failed", 0)), int(summary.get("duration_msec", 0)), esc(str(summary.get("timestamp", ""))),
	])
	body.append("<section id=\"suites\"><div class=\"scroll\"><table><thead><tr><th>Suite</th><th>Status</th><th>Exit</th><th>Failed assertions</th><th>ms</th><th>Report</th></tr></thead><tbody>")
	for row: Dictionary in rows:
		var path := str(row.get("path", ""))
		var link := "-"
		if not path.is_empty():
			var relative := path.get_file()
			var parent := path.get_base_dir().get_file()
			link = "<a href=\"%s\">report.html</a>" % esc(parent.path_join(relative).path_join("report.html"))
		var ok := int(row.get("exit_code", 2)) == 0
		body.append("<tr><td>%s</td><td class=\"%s\">%s</td><td class=\"num\">%d</td><td class=\"num\">%d</td><td class=\"num\">%d</td><td>%s</td></tr>" % [
			esc(str(row.get("suite_id", ""))), "ok" if ok else "bad", esc(str(row.get("status", ""))), int(row.get("exit_code", 2)),
			int(row.get("failed", 0)), int(row.get("duration_msec", 0)), link,
		])
	body.append("</tbody></table></div></section>")
	var errors: Array[String] = []
	for row: Dictionary in rows:
		for error: Variant in row.get("errors", []):
			errors.append("<li><strong>%s</strong>: %s</li>" % [esc(str(row.get("suite_id", ""))), esc(str(error))])
	if not errors.is_empty():
		body.append("<h2>Errors</h2><ul class=\"details\">" + "".join(errors) + "</ul>")
	return _page("Sim suites", body)


# --- Sections ---


static func _standings(report: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var standings: Dictionary = report["standings"]
	var matrix: Dictionary = report.get("matrix", {})
	var ids: Array = standings.keys()
	ids.sort_custom(func(a: String, b: String) -> bool: return float(standings[a]["points"]) > float(standings[b]["points"]))
	var battles: Array = report.get("battle", []) if report.get("battle") is Array else [report.get("battle")]
	out.append("<section id=\"standings\"><h2>Standings</h2>")
	out.append("<div class=\"legend\">Battles: %s · sides swapped: %s</div>" % [
		esc(", ".join(battles.map(func(b: Variant) -> String: return str(b)))),
		str(bool((report.get("tournament", {}) as Dictionary).get("swap_sides", true))),
	])
	out.append("<div class=\"scroll\"><table><thead><tr><th>AI</th><th>Games</th><th>W</th><th>D</th><th>L</th><th>Win rate</th><th>Points</th></tr></thead><tbody>")
	for ai_id: String in ids:
		var row: Dictionary = standings[ai_id]
		out.append("<tr><td>%s</td><td class=\"num\">%d</td><td class=\"num\">%d</td><td class=\"num\">%d</td><td class=\"num\">%d</td><td>%s</td><td class=\"num\">%.1f</td></tr>" % [
			esc(ai_id), int(row["games"]), int(row["wins"]), int(row["draws"]), int(row["losses"]),
			_bar(float(row["win_rate"]), null), float(row["points"]),
		])
	out.append("</tbody></table></div>")
	out.append("<h3>Who beats whom</h3><div class=\"scroll\"><table><thead><tr><th>row beats column</th>" + "".join(ids.map(func(i: String) -> String: return "<th>%s</th>" % esc(i))) + "</tr></thead><tbody>")
	for a: String in ids:
		var cells: Array[String] = []
		for b: String in ids:
			var row: Dictionary = matrix.get(a, {})
			if a == b or not row.has(b):
				cells.append("<td class=\"heat\">-</td>")
			else:
				var v := float(row[b])
				cells.append("<td class=\"heat\" style=\"background: rgba(47,111,214,%.2f)\">%.0f%%</td>" % [v * 0.6, v * 100.0])
		out.append("<tr><td>%s</td>%s</tr>" % [esc(a), "".join(cells)])
	out.append("</tbody></table></div></section>")
	return out


static func _cells(matchups: Array, factions: Array) -> Array[String]:
	var out: Array[String] = []
	out.append("<section id=\"cells\"><h2>Cells</h2>")
	out.append("<div class=\"scroll\"><table><thead><tr><th>Matchup</th><th>Sweep</th>" + "".join(factions.map(func(f: String) -> String: return "<th>win %s</th>" % esc(f))) + "<th>Draw</th><th>Rounds min / mean / max</th><th>Decisions</th></tr></thead><tbody>")
	for matchup: Dictionary in matchups:
		var aggregate: Dictionary = matchup["aggregate"]
		var ci: Dictionary = aggregate.get("ci95", {})
		var cells: Array[String] = []
		cells.append("<td>%s%s</td>" % [esc(str(matchup["id"])), " <em>(baseline)</em>" if bool(matchup.get("baseline", false)) else ""])
		cells.append("<td>%s</td>" % esc(_sweep_label(matchup["sweep_value"])))
		for faction: String in factions:
			cells.append("<td>%s</td>" % _bar(float(aggregate["win_rate"].get(faction, 0.0)), ci.get("win_rate", {}).get(faction)))
		cells.append("<td>%s</td>" % _bar(float(aggregate["draw_rate"]), ci.get("draw_rate")))
		cells.append("<td class=\"num\">%d / %.1f / %d</td>" % [int(aggregate["min_rounds"]), float(aggregate["mean_rounds"]), int(aggregate["max_rounds"])])
		cells.append("<td class=\"num\">%.0f</td>" % float(aggregate["mean_decisions"]))
		out.append("<tr>" + "".join(cells) + "</tr>")
	out.append("</tbody></table></div></section>")
	return out


static func _deltas(matchups: Array, factions: Array) -> Array[String]:
	var out: Array[String] = []
	out.append("<section id=\"deltas\"><h2>Deltas vs baseline</h2>")
	out.append("<div class=\"legend\">Signed change from the baseline cell; the whiskers in the cell table say whether a delta clears the noise.</div>")
	out.append("<div class=\"scroll\"><table><thead><tr><th>Matchup</th><th>Sweep</th>" + "".join(factions.map(func(f: String) -> String: return "<th>Δ win %s</th>" % esc(f))) + "<th>Δ draw</th><th>Δ rounds</th><th>Δ decisions</th></tr></thead><tbody>")
	for matchup: Dictionary in matchups:
		if not matchup.has("delta"):
			continue
		var delta: Dictionary = matchup["delta"]
		var cells: Array[String] = []
		cells.append("<td>%s</td>" % esc(str(matchup["id"])))
		cells.append("<td>%s</td>" % esc(_sweep_label(matchup["sweep_value"])))
		for faction: String in factions:
			cells.append("<td>%s</td>" % _delta_bar(delta.get("win_rate", {}).get(faction), true))
		cells.append("<td>%s</td>" % _delta_bar(delta.get("draw_rate"), true))
		cells.append("<td class=\"num\">%s</td>" % _signed(delta.get("mean_rounds"), 1))
		cells.append("<td class=\"num\">%s</td>" % _signed(delta.get("mean_decisions"), 1))
		out.append("<tr>" + "".join(cells) + "</tr>")
	out.append("</tbody></table></div></section>")
	return out


## One SVG per matchup when the sweep values are numeric: a line per
## faction with its 95% band.
static func _sweep_chart(report: Dictionary, matchups: Array, factions: Array) -> Array[String]:
	var out: Array[String] = []
	var sweep: Dictionary = report.get("sweep", {}) if report.get("sweep") is Dictionary else {}
	if sweep.is_empty() or str(sweep.get("path", "")).is_empty():
		return out
	var groups := {}
	var order: Array[String] = []
	for matchup: Dictionary in matchups:
		var value: Variant = matchup["sweep_value"]
		if not (value is float or value is int):
			return out
		var id := str(matchup["id"])
		if not groups.has(id):
			groups[id] = []
			order.append(id)
		groups[id].append(matchup)
	out.append("<section id=\"sweep\"><h2>Sweep: %s</h2>" % esc(str(sweep["path"])))
	var legend: Array[String] = []
	for i: int in factions.size():
		legend.append("<span class=\"swatch\" style=\"background:%s\"></span>win %s" % [SERIES_COLORS[i % SERIES_COLORS.size()], esc(str(factions[i]))])
	out.append("<div class=\"legend\">%s · shaded: 95%% interval</div>" % "  ".join(legend))
	for id: String in order:
		var cells: Array = groups[id]
		if cells.size() < 2:
			continue
		out.append("<h3>%s</h3>" % esc(id))
		out.append(_svg_lines(cells, factions))
	out.append("</section>")
	return out


static func _svg_lines(cells: Array, factions: Array) -> String:
	var width := 720.0
	var height := 260.0
	var left := 48.0
	var right := 16.0
	var top := 12.0
	var bottom := 36.0
	var plot_w := width - left - right
	var plot_h := height - top - bottom
	var xs: Array[float] = []
	for cell: Dictionary in cells:
		xs.append(float(cell["sweep_value"]))
	var x_min: float = xs.min()
	var x_max: float = xs.max()
	var span := maxf(x_max - x_min, 0.000001)
	var parts: Array[String] = []
	parts.append("<svg class=\"sweep\" viewBox=\"0 0 %d %d\" xmlns=\"http://www.w3.org/2000/svg\" role=\"img\">" % [int(width), int(height)])
	for tick: int in [0, 25, 50, 75, 100]:
		var y := top + plot_h * (1.0 - float(tick) / 100.0)
		parts.append("<line class=\"axis\" x1=\"%.1f\" y1=\"%.1f\" x2=\"%.1f\" y2=\"%.1f\" />" % [left, y, width - right, y])
		parts.append("<text x=\"%.1f\" y=\"%.1f\" text-anchor=\"end\">%d%%</text>" % [left - 6.0, y + 4.0, tick])
	for i: int in cells.size():
		var x := left + plot_w * ((xs[i] - x_min) / span)
		parts.append("<text x=\"%.1f\" y=\"%.1f\" text-anchor=\"middle\">%s</text>" % [x, height - 12.0, esc(_sweep_label(cells[i]["sweep_value"]))])
	for f: int in factions.size():
		var faction: String = factions[f]
		var color: String = SERIES_COLORS[f % SERIES_COLORS.size()]
		var upper: Array[String] = []
		var lower: Array[String] = []
		var line: Array[String] = []
		for i: int in cells.size():
			var aggregate: Dictionary = cells[i]["aggregate"]
			var rate := float(aggregate["win_rate"].get(faction, 0.0))
			var half := float(aggregate.get("ci95", {}).get("win_rate", {}).get(faction, 0.0))
			var x := left + plot_w * ((xs[i] - x_min) / span)
			line.append("%.1f,%.1f" % [x, top + plot_h * (1.0 - rate)])
			upper.append("%.1f,%.1f" % [x, top + plot_h * (1.0 - clampf(rate + half, 0.0, 1.0))])
			lower.append("%.1f,%.1f" % [x, top + plot_h * (1.0 - clampf(rate - half, 0.0, 1.0))])
		lower.reverse()
		parts.append("<polygon points=\"%s\" fill=\"%s\" opacity=\"0.18\" />" % [" ".join(upper) + " " + " ".join(lower), color])
		parts.append("<polyline points=\"%s\" fill=\"none\" stroke=\"%s\" stroke-width=\"2\" />" % [" ".join(line), color])
		for point: String in line:
			var xy := point.split(",")
			parts.append("<circle cx=\"%s\" cy=\"%s\" r=\"3\" fill=\"%s\" />" % [xy[0], xy[1], color])
	parts.append("</svg>")
	return "".join(parts)


static func _details(matchups: Array) -> Array[String]:
	var out: Array[String] = []
	out.append("<section id=\"details\"><h2>Per cell</h2>")
	for matchup: Dictionary in matchups:
		var aggregate: Dictionary = matchup["aggregate"]
		var label := str(matchup["id"]) + ("" if matchup["sweep_value"] == null else " @ " + _sweep_label(matchup["sweep_value"]))
		out.append("<h3>%s</h3><ul class=\"details\">" % esc(label))
		if matchup.has("delta"):
			out.append("<li>vs baseline: %s</li>" % esc(SimReport.format_delta_leaves(matchup["delta"])))
		out.append("<li>End reasons: %s</li>" % esc(SimReport.format_rates(aggregate.get("reason", {}))))
		var faction_metrics: Dictionary = aggregate["metrics"].get("faction", {})
		for faction: String in faction_metrics.keys():
			var stats: Dictionary = faction_metrics[faction]
			out.append("<li><strong>%s</strong>: dealt %.1f, taken %.1f, kills %.1f, deaths %.1f, healed %.1f, survivors %.1f, hp share %.2f, first blood %.0f%%</li>" % [
				esc(faction), float(stats.get("damage_dealt", 0)), float(stats.get("damage_taken", 0)),
				float(stats.get("kills", 0)), float(stats.get("deaths", 0)), float(stats.get("healed", 0)),
				float(stats.get("survivors", 0)), float(stats.get("hp_share", 0)), float(stats.get("first_blood", 0)) * 100.0,
			])
		var custom: Dictionary = aggregate.get("custom", {})
		if not custom.is_empty():
			out.append("<li>Custom: <code>%s</code></li>" % esc(JSON.stringify(custom)))
		out.append("</ul>")
	out.append("</section>")
	return out


static func _assertions(report: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var verifications: Array = report.get("verifications", [])
	if verifications.is_empty():
		return out
	out.append("<section id=\"assertions\"><h2>Assertions</h2><div class=\"scroll\"><table><thead><tr><th>Result</th><th>Metric</th><th>Matchup</th><th>Sweep</th><th>Actual</th><th>Comparator</th><th>Expected</th></tr></thead><tbody>")
	for v: Dictionary in verifications:
		out.append("<tr><td class=\"%s\">%s</td><td><code>%s</code></td><td>%s</td><td>%s</td><td class=\"num\">%s</td><td>%s</td><td class=\"num\">%s</td></tr>" % [
			"ok" if v["passed"] else "bad", "PASS" if v["passed"] else "FAIL", esc(str(v["metric"])), esc(str(v["matchup"])),
			esc(_sweep_label(v["sweep_value"])), esc(SimReport.format_value(v["actual"])), esc(str(v["comparator"])), esc(SimReport.format_value(v["expected"])),
		])
	out.append("</tbody></table></div></section>")
	return out


static func _errors(report: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var errors: Array = report.get("errors", [])
	if errors.is_empty():
		return out
	out.append("<section id=\"errors\"><h2>Errors</h2><ul class=\"details\">")
	for error: String in errors:
		out.append("<li class=\"bad\">%s</li>" % esc(error))
	out.append("</ul></section>")
	return out


# --- Widgets ---


static func _bar(rate: float, half_width: Variant) -> String:
	var label := "%.0f%%" % (rate * 100.0)
	var ci := ""
	if half_width != null:
		var hw := float(half_width)
		label += " ±%.0f" % (hw * 100.0)
		var lo := clampf(rate - hw, 0.0, 1.0)
		var hi := clampf(rate + hw, 0.0, 1.0)
		ci = "<div class=\"ci\" style=\"left:%.1f%%;width:%.1f%%\"></div>" % [lo * 100.0, (hi - lo) * 100.0]
	return "<div class=\"bar\"><div class=\"fill\" style=\"width:%.1f%%\"></div>%s<span>%s</span></div>" % [rate * 100.0, ci, label]


## Centered at zero; a rate delta spans -1..1, so half the bar is 100 points.
static func _delta_bar(value: Variant, as_points: bool) -> String:
	if value == null:
		return "-"
	var v := float(value)
	var magnitude := clampf(absf(v), 0.0, 1.0) * 50.0
	var left := 50.0 if v >= 0.0 else 50.0 - magnitude
	var label := ("%+.0f pts" % (v * 100.0)) if as_points else ("%+.2f" % v)
	return "<div class=\"delta\"><div class=\"zero\"></div><div class=\"fill %s\" style=\"left:%.1f%%;width:%.1f%%\"></div><span>%s</span></div>" % [
		"pos" if v >= 0.0 else "neg", left, magnitude, label,
	]


static func _signed(value: Variant, decimals: int) -> String:
	if value == null:
		return "-"
	return ("%+." + str(decimals) + "f") % float(value)


static func _sweep_label(value: Variant) -> String:
	if value == null:
		return "-"
	if value is float and is_equal_approx(float(value), roundf(float(value))):
		return str(int(value))
	return str(value)


static func _page(title: String, body: Array[String]) -> String:
	return "\n".join([
		"<!DOCTYPE html>",
		"<html lang=\"en\">",
		"<head>",
		"<meta charset=\"utf-8\" />",
		"<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\" />",
		"<title>%s</title>" % esc(title),
		"<style>%s</style>" % CSS,
		"</head>",
		"<body><main>",
		"\n".join(body),
		"</main></body>",
		"</html>",
		"",
	])


static func esc(text: String) -> String:
	return text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("\"", "&quot;")


# --- Markdown subset ---


## Headings (#, ##, ###), paragraphs, "- " bullets, **bold** and `code`.
## Anything else is text. Enough for an analysis, not a document engine.
static func markdown_subset(text: String) -> String:
	var out: Array[String] = []
	var paragraph: Array[String] = []
	var in_list := false
	for raw_line: String in text.split("\n"):
		var line := raw_line.strip_edges(false, true)
		var trimmed := line.strip_edges()
		if trimmed.is_empty():
			_flush_paragraph(out, paragraph)
			if in_list:
				out.append("</ul>")
				in_list = false
			continue
		if trimmed.begins_with("- ") or trimmed.begins_with("* "):
			_flush_paragraph(out, paragraph)
			if not in_list:
				out.append("<ul>")
				in_list = true
			out.append("<li>%s</li>" % _inline(trimmed.substr(2)))
			continue
		if in_list:
			out.append("</ul>")
			in_list = false
		var level := 0
		while level < trimmed.length() and trimmed[level] == "#":
			level += 1
		if level > 0 and level <= 3 and trimmed.length() > level and trimmed[level] == " ":
			_flush_paragraph(out, paragraph)
			out.append("<h%d>%s</h%d>" % [level + 1, _inline(trimmed.substr(level + 1)), level + 1])
			continue
		paragraph.append(trimmed)
	_flush_paragraph(out, paragraph)
	if in_list:
		out.append("</ul>")
	return "\n".join(out)


static func _flush_paragraph(out: Array[String], paragraph: Array[String]) -> void:
	if paragraph.is_empty():
		return
	out.append("<p>%s</p>" % _inline(" ".join(paragraph)))
	paragraph.clear()


static func _inline(text: String) -> String:
	var escaped := esc(text)
	var bold := RegEx.create_from_string("\\*\\*(.+?)\\*\\*")
	escaped = bold.sub(escaped, "<strong>$1</strong>", true)
	var code := RegEx.create_from_string("`([^`]+)`")
	return code.sub(escaped, "<code>$1</code>", true)
