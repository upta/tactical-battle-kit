extends Node2D

# Units, rings, stances and transient effects drawn over the TileMapLayers
# at map_to_local positions supplied by the scene. Same idea as BattleView's
# effects, positioned by the map instead of by cell size.

const EFFECT_SECONDS := 0.5
const _FACTION_COLORS: Dictionary[String, Color] = {
	"squad": Color(0.3, 0.55, 0.95),
	"aliens": Color(0.85, 0.3, 0.25),
}

var state: BattleState = null
var ringed: Array[String] = []
var selected: String = ""

var _scene: Node2D
var _effects: Array[Dictionary] = []


func setup(scene: Node2D) -> void:
	_scene = scene
	set_process(false)


func _center(cell: Vector2i) -> Vector2:
	return to_local(_scene.cell_to_world(cell))


func show_events(events: Array[Dictionary]) -> void:
	if state == null:
		return
	for event: Dictionary in events:
		match str(event.get("type", "")):
			BattleEvents.ATTACKED:
				var attacker := state.unit(str(event.get("attacker_id")))
				var defender := state.unit(str(event.get("defender_id")))
				if attacker == null or defender == null:
					continue
				_effects.append({
					"kind": "shot", "from": _center(attacker.cell), "to": _center(defender.cell),
					"damage": int(event.get("damage", 0)), "hit": bool(event.get("hit", true)),
					"reaction": bool(event.get("reaction", false)), "chance": int(event.get("chance", 0)), "t": 0.0,
				})
			BattleEvents.MOVED:
				var points: Array[Vector2] = []
				var from: Array = event.get("from", [0, 0])
				points.append(_center(Vector2i(int(from[0]), int(from[1]))))
				for pair: Array in event.get("path", []):
					points.append(_center(Vector2i(int(pair[0]), int(pair[1]))))
				_effects.append({"kind": "trail", "points": points, "t": 0.0})
			"cover_destroyed":
				var pair: Array = event.get("cell", [0, 0])
				_effects.append({"kind": "burst", "at": _center(Vector2i(int(pair[0]), int(pair[1]))), "t": 0.0})
			BattleEvents.UNIT_DIED:
				var dead := state.unit(str(event.get("unit_id")))
				if dead != null:
					_effects.append({"kind": "gone", "at": _center(dead.cell), "t": 0.0})
			BattleEvents.UNIT_SPAWNED:
				var born := state.unit(str(event.get("unit_id")))
				if born != null:
					_effects.append({"kind": "spawn", "at": _center(born.cell), "t": 0.0})
	if not _effects.is_empty():
		set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	var kept: Array[Dictionary] = []
	for effect: Dictionary in _effects:
		effect["t"] = float(effect["t"]) + delta
		if float(effect["t"]) < EFFECT_SECONDS:
			kept.append(effect)
	_effects = kept
	if _effects.is_empty():
		set_process(false)
	queue_redraw()


func _draw() -> void:
	if state == null:
		return
	var font := ThemeDB.fallback_font
	var radius := 11.0
	for unit_id: String in state.sorted_unit_ids():
		var unit := state.units[unit_id]
		if not unit.is_on_field():
			continue
		var center := _center(unit.cell)
		var color: Color = _FACTION_COLORS.get(unit.faction, Color.GRAY)
		if ringed.has(unit_id):
			var is_selected := unit_id == selected
			draw_arc(center, radius + 4.0, 0.0, TAU, 32, Color(1, 1, 1, 1.0 if is_selected else 0.6), 2.5 if is_selected else 1.5)
		draw_circle(center, radius, color)
		draw_arc(center, radius, 0.0, TAU, 32, Color(0, 0, 0, 0.8), 1.0)
		var bar := Vector2(22.0, 3.0)
		var bar_origin := center + Vector2(-bar.x * 0.5, radius + 2.0)
		draw_rect(Rect2(bar_origin, bar), Color(0.1, 0.1, 0.1))
		draw_rect(Rect2(bar_origin, Vector2(bar.x * unit.hp_fraction(), bar.y)), Color(0.3, 0.9, 0.3))
		var stance := ""
		if bool(unit.custom.get("overwatch", false)):
			stance = "OW"
		elif bool(unit.custom.get("hunker", false)):
			stance = "HK"
		if not stance.is_empty():
			draw_string(font, center + Vector2(-8.0, 4.0), stance, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color.WHITE)
		_label(font, unit.def.display_name, center + Vector2(0.0, radius + 6.0), 8)
	for effect: Dictionary in _effects:
		_draw_effect(font, effect)


func _label(font: Font, text: String, top_center: Vector2, size: int, color: Color = Color.WHITE) -> void:
	var width := 60.0
	var origin := Vector2(top_center.x - width * 0.5, top_center.y + float(size))
	draw_string_outline(font, origin, text, HORIZONTAL_ALIGNMENT_CENTER, width, size, 2, Color(0, 0, 0, 0.9))
	draw_string(font, origin, text, HORIZONTAL_ALIGNMENT_CENTER, width, size, color)


func _draw_effect(font: Font, effect: Dictionary) -> void:
	var p := clampf(float(effect["t"]) / EFFECT_SECONDS, 0.0, 1.0)
	var fade := 1.0 - p
	match str(effect["kind"]):
		"shot":
			var from: Vector2 = effect["from"]
			var to: Vector2 = effect["to"]
			var tint := Color(1.0, 0.55, 0.2) if bool(effect["reaction"]) else Color(1.0, 0.95, 0.4)
			draw_line(from, to, Color(tint, 0.5 * fade), 1.5)
			draw_circle(from.lerp(to, clampf(p * 2.0, 0.0, 1.0)), 3.0, tint)
			if p > 0.3:
				var hit := bool(effect["hit"])
				var text := "-%d" % int(effect["damage"]) if hit else "miss (%d%%)" % int(effect["chance"])
				draw_arc(to, 14.0 + p * 6.0, 0.0, TAU, 24, Color(1.0, 0.25, 0.2, fade) if hit else Color(0.8, 0.8, 0.8, fade), 2.0)
				_label(font, text, to + Vector2(0.0, -26.0 - p * 8.0), 9, Color(1.0, 0.4, 0.3) if hit else Color(0.85, 0.85, 0.85))
		"trail":
			var points: Array[Vector2] = []
			points.assign(effect["points"])
			for i: int in range(1, points.size()):
				draw_line(points[i - 1], points[i], Color(1, 1, 1, 0.6 * fade), 2.0)
		"burst":
			var at: Vector2 = effect["at"]
			draw_arc(at, 6.0 + p * 18.0, 0.0, TAU, 24, Color(1.0, 0.7, 0.3, fade), 3.0)
			_label(font, "cover gone", at + Vector2(0.0, -24.0), 8, Color(1.0, 0.8, 0.5))
		"gone":
			var at: Vector2 = effect["at"]
			draw_line(at + Vector2(-9, -9), at + Vector2(9, 9), Color(1, 1, 1, fade), 2.5)
			draw_line(at + Vector2(-9, 9), at + Vector2(9, -9), Color(1, 1, 1, fade), 2.5)
		"spawn":
			var at: Vector2 = effect["at"]
			draw_arc(at, 18.0 * fade + 4.0, 0.0, TAU, 24, Color(0.9, 0.3, 0.9, fade), 2.5)
