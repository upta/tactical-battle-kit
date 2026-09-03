extends Node2D

# Stacks, counts, rings, stances and effects drawn over the half-offset
# TileMapLayers. A two-cell creature is one body spanning both cell centers.

const EFFECT_SECONDS := 0.7
const _FACTION_COLORS: Dictionary[String, Color] = {
	"castle": Color(0.3, 0.5, 0.95),
	"necropolis": Color(0.55, 0.3, 0.6),
}

var state: BattleState = null
var ringed: Array[String] = []
var selected: String = ""

var _scene: Node2D
var _effects: Array[Dictionary] = []
var _hover_cell: Vector2i = Vector2i(-1, -1)
var _hover_lines: Array[String] = []


func setup(scene: Node2D) -> void:
	_scene = scene
	set_process(false)


func set_hover(cell: Vector2i, lines: Array[String]) -> void:
	if cell == _hover_cell and lines == _hover_lines:
		return
	_hover_cell = cell
	_hover_lines = lines
	queue_redraw()


func hover_lines() -> Array[String]:
	return _hover_lines.duplicate()


func _center(cell: Vector2i) -> Vector2:
	return to_local(_scene.cell_to_world(cell))


func _body_center(unit: BattleUnit) -> Vector2:
	var total := Vector2.ZERO
	var cells := state.occupied_cells(unit)
	for cell: Vector2i in cells:
		total += _center(cell)
	return total / float(maxi(cells.size(), 1))


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
					"kind": "hit", "from": _body_center(attacker), "to": _body_center(defender),
					"damage": int(event.get("damage", 0)), "counter": bool(event.get("counter", false)),
					"cloud": str(event.get("ability", "")) == "death_cloud", "friendly": bool(event.get("friendly", false)), "t": 0.0,
				})
			BattleEvents.ABILITY_USED:
				var cells: Array[Vector2i] = []
				for pair: Array in event.get("cells", []):
					cells.append(Vector2i(int(pair[0]), int(pair[1])))
				_effects.append({"kind": "cloud", "cells": cells, "t": 0.0})
			BattleEvents.MOVED:
				var points: Array[Vector2] = []
				var from: Array = event.get("from", [0, 0])
				points.append(_center(Vector2i(int(from[0]), int(from[1]))))
				for pair: Array in event.get("path", []):
					points.append(_center(Vector2i(int(pair[0]), int(pair[1]))))
				_effects.append({"kind": "trail", "points": points, "t": 0.0})
			BattleEvents.UNIT_DIED:
				var dead := state.unit(str(event.get("unit_id")))
				if dead != null:
					_effects.append({"kind": "gone", "at": _body_center(dead), "t": 0.0})
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
	for effect: Dictionary in _effects:
		if str(effect["kind"]) == "cloud":
			var alpha := 0.5 * (1.0 - float(effect["t"]) / EFFECT_SECONDS)
			for cell: Vector2i in effect["cells"]:
				draw_circle(_center(cell), 18.0, Color(0.5, 0.9, 0.4, alpha))
	for unit_id: String in state.sorted_unit_ids():
		var unit := state.units[unit_id]
		if not unit.is_on_field():
			continue
		var cells := state.occupied_cells(unit)
		var center := _body_center(unit)
		var color: Color = _FACTION_COLORS.get(unit.faction, Color.GRAY)
		var wide := cells.size() > 1
		var radius := 13.0
		if ringed.has(unit_id):
			var is_selected := unit_id == selected
			draw_arc(center, radius + (18.0 if wide else 5.0), 0.0, TAU, 40, Color(1, 1, 1, 1.0 if is_selected else 0.6), 2.5 if is_selected else 1.5)
		if wide:
			var a := _center(cells[0])
			var b := _center(cells[1])
			draw_line(a, b, color, radius * 2.0)
			draw_circle(a, radius, color)
			draw_circle(b, radius, color)
		else:
			draw_circle(center, radius, color)
		draw_arc(center, radius, 0.0, TAU, 32, Color(0, 0, 0, 0.6), 1.0)
		var count := BattlefieldRuleset.count_of(unit)
		_label(font, str(count), center + Vector2(0.0, -7.0), 11, Color.WHITE)
		# Heroes-style: how much the NEXT creature to die has left, not the
		# whole pool. Full again after every death.
		var stack := unit.def as StackDef
		if stack != null and count > 0:
			var top_hp := unit.hp - (count - 1) * stack.creature_hp
			var fraction := clampf(float(top_hp) / float(maxi(stack.creature_hp, 1)), 0.0, 1.0)
			var bar := Vector2(24.0, 3.0)
			var bar_origin := center + Vector2(-bar.x * 0.5, -radius - 6.0)
			draw_rect(Rect2(bar_origin, bar), Color(0.1, 0.1, 0.1, 0.9))
			draw_rect(Rect2(bar_origin, Vector2(bar.x * fraction, bar.y)), Color(0.9, 0.3, 0.2).lerp(Color(0.3, 0.9, 0.3), fraction))
		var stance := ""
		if bool(unit.custom.get("defending", false)):
			stance = "DEF"
		elif bool(unit.custom.get("delayed", false)):
			stance = "WAIT"
		var shots := BattlefieldRuleset.shots_left(unit)
		var line := unit.def.display_name + (" (%d shots)" % shots if shots > 0 else "") + (" " + stance if not stance.is_empty() else "")
		_label(font, line, center + Vector2(0.0, radius + 4.0), 8)
	for effect: Dictionary in _effects:
		_draw_effect(font, effect)
	_draw_hover(font)


func _draw_hover(font: Font) -> void:
	if _hover_cell.x < 0 or _hover_lines.is_empty():
		return
	var at := _center(_hover_cell) + Vector2(0.0, -34.0)
	var size := Vector2(96.0, 11.0 * _hover_lines.size() + 6.0)
	var rect := Rect2(at - Vector2(size.x * 0.5, size.y), size)
	draw_rect(rect, Color(0.08, 0.08, 0.1, 0.92))
	draw_rect(rect, Color(1, 1, 1, 0.5), false, 1.0)
	for i: int in _hover_lines.size():
		var origin := Vector2(rect.position.x, rect.position.y + 3.0 + 11.0 * float(i))
		draw_string(font, origin + Vector2(0.0, 9.0), _hover_lines[i], HORIZONTAL_ALIGNMENT_CENTER, size.x, 9, Color(1.0, 0.95, 0.6) if i == 0 else Color.WHITE)


func _label(font: Font, text: String, top_center: Vector2, size: int, color: Color = Color.WHITE) -> void:
	var width := 110.0
	var origin := Vector2(top_center.x - width * 0.5, top_center.y + float(size))
	draw_string_outline(font, origin, text, HORIZONTAL_ALIGNMENT_CENTER, width, size, 2, Color(0, 0, 0, 0.9))
	draw_string(font, origin, text, HORIZONTAL_ALIGNMENT_CENTER, width, size, color)


func _draw_effect(font: Font, effect: Dictionary) -> void:
	var p := clampf(float(effect["t"]) / EFFECT_SECONDS, 0.0, 1.0)
	var fade := 1.0 - p
	match str(effect["kind"]):
		"hit":
			var from: Vector2 = effect["from"]
			var to: Vector2 = effect["to"]
			var tint := Color(1.0, 0.5, 0.2) if bool(effect["counter"]) else (Color(0.5, 0.9, 0.4) if bool(effect["cloud"]) else Color(1.0, 0.95, 0.4))
			if not bool(effect["cloud"]):
				draw_line(from, to, Color(tint, 0.5 * fade), 2.0)
			var headline := "-%d" % int(effect["damage"])
			if bool(effect["counter"]):
				headline = "retaliation " + headline
			elif bool(effect["friendly"]):
				headline = "friendly fire " + headline
			_label(font, headline, to + Vector2(0.0, -40.0 - p * 8.0), 10, Color(1.0, 0.4, 0.3) if not bool(effect["friendly"]) else Color(1.0, 0.7, 0.3))
		"trail":
			var points: Array[Vector2] = []
			points.assign(effect["points"])
			for i: int in range(1, points.size()):
				draw_line(points[i - 1], points[i], Color(1, 1, 1, 0.6 * fade), 2.0)
		"gone":
			var at: Vector2 = effect["at"]
			draw_line(at + Vector2(-10, -10), at + Vector2(10, 10), Color(1, 1, 1, fade), 3.0)
			draw_line(at + Vector2(-10, 10), at + Vector2(10, -10), Color(1, 1, 1, fade), 3.0)
