extends SceneTree

# Proof for the HTML reports: every report.html the sim wrote (found through
# each suite's latest.json) and summary.html if present must be well-formed
# and carry the sections its report implies. Three checks per page, because
# a page that "opened fine" proves nothing when nobody looked:
#
#   1. Tag balance: every opening tag has its closing tag, in order, with
#      self-closing tags and the doctype skipped. Catches an unclosed <div>
#      that a browser would silently absorb.
#   2. Godot's XMLParser reads the page to the end without error, so the
#      markup is also parseable as XML (escaping, quoting, entities).
#   3. Section ids: "cells" always; "assertions" when the report verified
#      any; "deltas" when any cell carries a delta; "sweep" when the suite
#      swept a path; "standings" when it has a tournament; "analysis" when
#      analysis.md sits beside it.
#
#   godot --headless --path src --script res://tools/check_reports.gd [-- --dir <artifacts/sim dir>]
#
# Prints "REPORT CHECK COMPLETE: N pages, M failures" and exits 0 or 1.

const _MARKER := "REPORT CHECK COMPLETE"
const _VOID_TAGS: Array[String] = ["meta", "br", "link", "img", "hr", "input"]

var _failures: Array[String] = []


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var dir := "res://artifacts/sim"
	for i: int in args.size():
		if args[i] == "--dir" and i + 1 < args.size():
			dir = args[i + 1]
	var root := ProjectSettings.globalize_path(dir)
	var pages := _find_pages(root)
	for page: Dictionary in pages:
		_check_page(page)
	for failure: String in _failures:
		print("REPORT FAIL: ", failure)
	print(_MARKER, ": %d pages, %d failures" % [pages.size(), _failures.size()])
	quit(0 if _failures.is_empty() and not pages.is_empty() else 1)


func _find_pages(root: String) -> Array[Dictionary]:
	var pages: Array[Dictionary] = []
	var dir := DirAccess.open(root)
	if dir == null:
		_failures.append("no artifacts directory at %s" % root)
		return pages
	if FileAccess.file_exists(root.path_join("summary.html")):
		pages.append({"path": root.path_join("summary.html"), "required": ["suites"]})
	for name: String in dir.get_directories():
		var pointer_path := root.path_join(name).path_join("latest.json")
		if not FileAccess.file_exists(pointer_path):
			continue
		var pointer: Variant = JSON.parse_string(FileAccess.get_file_as_string(pointer_path))
		if not (pointer is Dictionary):
			_failures.append("%s is not a JSON object" % pointer_path)
			continue
		var run_dir := str(pointer.get("path", ""))
		var report: Variant = JSON.parse_string(FileAccess.get_file_as_string(run_dir.path_join("report.json")))
		if not (report is Dictionary):
			_failures.append("%s has no readable report.json" % run_dir)
			continue
		# Mirror what the renderer promises: a section appears when the
		# report has something to put in it, not when the suite has the key.
		var required: Array[String] = ["cells"]
		if not (report.get("verifications", []) as Array).is_empty():
			required.append("assertions")
		var matchups: Array = report.get("matchups", [])
		if matchups.any(func(m: Dictionary) -> bool: return m.has("delta")):
			required.append("deltas")
		var sweep: Variant = report.get("sweep")
		if sweep is Dictionary and not str((sweep as Dictionary).get("path", "")).is_empty():
			required.append("sweep")
		if report.has("tournament"):
			required.append("standings")
		if FileAccess.file_exists(run_dir.path_join("analysis.md")):
			required.append("analysis")
		pages.append({"path": run_dir.path_join("report.html"), "required": required})
	return pages


func _check_page(page: Dictionary) -> void:
	var path := str(page["path"])
	if not FileAccess.file_exists(path):
		_failures.append("%s: missing" % path)
		return
	var html := FileAccess.get_file_as_string(path)
	_check_balance(path, html)
	_check_xml(path, html)
	for id: String in page["required"]:
		if not html.contains("id=\"%s\"" % id):
			_failures.append("%s: no section id=\"%s\"" % [path, id])


func _check_balance(path: String, html: String) -> void:
	var tag := RegEx.create_from_string("<(/?)([A-Za-z][A-Za-z0-9]*)(?:\\s[^<>]*?)?(/?)>")
	var stack: Array[String] = []
	for m: RegExMatch in tag.search_all(html):
		var closing := m.get_string(1) == "/"
		var name := m.get_string(2).to_lower()
		var self_closing := m.get_string(3) == "/"
		if self_closing or _VOID_TAGS.has(name):
			if closing:
				_failures.append("%s: closing tag for void element <%s>" % [path, name])
			continue
		if closing:
			if stack.is_empty() or stack[-1] != name:
				_failures.append("%s: </%s> closes <%s>" % [path, name, "nothing" if stack.is_empty() else stack[-1]])
				return
			stack.pop_back()
		else:
			stack.append(name)
	if not stack.is_empty():
		_failures.append("%s: unclosed <%s>" % [path, stack[-1]])


func _check_xml(path: String, html: String) -> void:
	# The doctype is HTML, not XML; everything after it must parse.
	var body := html
	var doctype := body.find("<!DOCTYPE")
	if doctype >= 0:
		body = body.substr(body.find(">", doctype) + 1)
	var parser := XMLParser.new()
	var opened := parser.open_buffer(body.to_utf8_buffer())
	if opened != OK:
		_failures.append("%s: XMLParser could not open the page (%d)" % [path, opened])
		return
	while true:
		var status := parser.read()
		if status == ERR_FILE_EOF:
			return
		if status != OK:
			_failures.append("%s: XMLParser error %d at line %d" % [path, status, parser.get_current_line()])
			return
