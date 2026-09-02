class_name BattleView
extends Node2D

## Debug renderer: draws a BattleState's grid, overlays, units, hp bars,
## facing ticks and readable labels with plain shapes, plus short transient
## effects for the events a step produced (projectiles, hits, heals, deaths)
## so a watcher can follow what just happened. It exists so harness
## screenshots show the battle and so an example plays visibly. Games own
## their presentation; this is not meant to be skinned.

const _FACTION_COLORS: Array[Color] = [
	Color(0.85, 0.25, 0.2), Color(0.2, 0.45, 0.9), Color(0.9, 0.75, 0.2),
	Color(0.5, 0.25, 0.75), Color(0.2, 0.7, 0.6), Color(0.6, 0.6, 0.6),
]
const EFFECT_SECONDS := 0.45

@export var cell_size: int = 48
@export var draw_labels: bool = true

var state: BattleState = null:
	set(value):
		state = value
		queue_redraw()

var _units_drawn: int = 0
var _cells_drawn: int = 0
var _effects: Array[Dictionary] = []


func _ready() -> void:
	set_process(false)


func refresh() -> void:
	queue_redraw()


## Facts a harness asserts against.
func describe_ui() -> Dictionary:
	return {
		"units_drawn": _units_drawn,
		"cells_drawn": _cells_drawn,
		"cell_size": cell_size,
		"has_state": state != null,
		"effects_active": _effects.size(),
	}


## Screen position of a cell's center, in local coordinates.
func cell_center(cell: Vector2i) -> Vector2:
	if state != null and state.grid.topology is HexTopology:
		var w := float(cell_size)
		var h := w * 1.1547
		var x := cell.x * w + (w * 0.5 if (cell.y & 1) == 1 else 0.0) + w * 0.5
		var y := cell.y * h * 0.75 + h * 0.5
		return Vector2(x, y)
	return Vector2(cell) * float(cell_size) + Vector2.ONE * float(cell_size) * 0.5


# --- Effects ---


## Queue transient effects for the events one applied action produced.
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
					"kind": "attack",
					"from": cell_center(attacker.cell),
					"to": cell_center(defender.cell),
					"ranged": state.grid.distance(attacker.cell, defender.cell) > 1,
					"amount": int(event.get("damage", 0)),
					"counter": bool(event.get("counter", false)),
					"t": 0.0,
				})
			BattleEvents.HEALED:
				var healed := state.unit(str(event.get("unit_id")))
				if healed != null:
					_effects.append({"kind": "heal", "at": cell_center(healed.cell), "amount": int(event.get("amount", 0)), "t": 0.0})
			BattleEvents.ABILITY_USED:
				var cells: Array[Vector2i] = []
				for pair: Array in event.get("cells", []):
					cells.append(Vector2i(int(pair[0]), int(pair[1])))
				_effects.append({"kind": "area", "cells": cells, "t": 0.0})
			BattleEvents.UNIT_DIED, BattleEvents.LEFT_FIELD:
				var gone := state.unit(str(event.get("unit_id")))
				if gone != null:
					_effects.append({"kind": "gone", "at": cell_center(gone.cell), "label": str(event.get("status", "dead")), "t": 0.0})
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


# --- Drawing ---


func _draw() -> void:
	_units_drawn = 0
	_cells_drawn = 0
	if state == null:
		return
	var font := ThemeDB.fallback_font
	var hex := state.grid.topology is HexTopology
	for cell: Vector2i in state.grid.all_cells():
		var terrain := state.grid.terrain_at(cell)
		var color := terrain.color if terrain != null else Color.MAGENTA
		_draw_cell(cell, color, hex)
		for overlay: TerrainDef in state.grid.overlays_at(cell):
			_draw_cell(cell, overlay.color, hex, 0.6)
		_cells_drawn += 1

	for effect: Dictionary in _effects:
		if str(effect["kind"]) == "area":
			var alpha := 0.4 * (1.0 - float(effect["t"]) / EFFECT_SECONDS)
			for cell: Vector2i in effect["cells"]:
				_draw_cell(cell, Color(1.0, 0.95, 0.4), hex, alpha)

	var faction_index: Dictionary[String, int] = {}
	for i: int in state.factions.size():
		faction_index[state.factions[i]] = i

	var radius := float(cell_size) * 0.36
	var labels: Array[Dictionary] = []
	for unit_id: String in state.sorted_unit_ids():
		var unit := state.units[unit_id]
		if not unit.is_on_field():
			continue
		var color := _FACTION_COLORS[faction_index.get(unit.faction, 0) % _FACTION_COLORS.size()]
		for cell: Vector2i in state.occupied_cells(unit):
			var center := cell_center(cell)
			draw_circle(center, radius, color)
			draw_arc(center, radius, 0.0, TAU, 32, Color(0, 0, 0, 0.8), 1.5)
			if unit.facing >= 0:
				var direction := _facing_vector(unit.facing)
				draw_line(center + direction * radius * 0.7, center + direction * radius * 1.15, Color.WHITE, 3.0)
		var anchor := cell_center(unit.cell)
		var bar_width := float(cell_size) * 0.7
		var bar_origin := anchor + Vector2(-bar_width * 0.5, radius + 3.0)
		draw_rect(Rect2(bar_origin, Vector2(bar_width, 4.0)), Color(0.1, 0.1, 0.1))
		draw_rect(Rect2(bar_origin, Vector2(bar_width * unit.hp_fraction(), 4.0)), Color(0.3, 0.9, 0.3))
		if draw_labels:
			labels.append({"text": unit_label(unit), "at": anchor + Vector2(0.0, radius + 8.0)})
		_units_drawn += 1

	# Labels last, so a unit in the next row never covers the one above it.
	for label: Dictionary in labels:
		_draw_label(font, str(label["text"]), label["at"], 12, Color.WHITE)

	for effect: Dictionary in _effects:
		_draw_effect(font, effect)


## Human-readable label that fits the cell: the def's display name, or its
## first word when the full name would not fit.
func unit_label(unit: BattleUnit) -> String:
	var name := unit.def.display_name if unit.def != null else unit.id
	if name.is_empty():
		name = unit.id
	var font := ThemeDB.fallback_font
	if font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x > float(cell_size) * 1.4:
		name = name.split(" ")[0]
	return name


func _draw_label(font: Font, text: String, top_center: Vector2, size: int, color: Color) -> void:
	var width := float(cell_size) * 2.0
	var origin := Vector2(top_center.x - width * 0.5, top_center.y + float(size))
	draw_string_outline(font, origin, text, HORIZONTAL_ALIGNMENT_CENTER, width, size, 3, Color(0, 0, 0, 0.9))
	draw_string(font, origin, text, HORIZONTAL_ALIGNMENT_CENTER, width, size, color)


func _draw_effect(font: Font, effect: Dictionary) -> void:
	var p := clampf(float(effect["t"]) / EFFECT_SECONDS, 0.0, 1.0)
	var fade := 1.0 - p
	match str(effect["kind"]):
		"attack":
			var from: Vector2 = effect["from"]
			var to: Vector2 = effect["to"]
			var tint := Color(1.0, 0.6, 0.2) if bool(effect["counter"]) else Color(1.0, 0.9, 0.3)
			if bool(effect["ranged"]):
				var travel := clampf(p * 1.6, 0.0, 1.0)
				draw_line(from, to, Color(tint, 0.25 * fade), 1.0)
				draw_circle(from.lerp(to, travel), 5.0, tint)
			else:
				var lunge := from.lerp(to, 0.45)
				draw_line(from, lunge, Color(tint, fade), 4.0)
			if p > 0.35:
				var hit := (p - 0.35) / 0.65
				draw_arc(to, float(cell_size) * 0.42 + hit * 6.0, 0.0, TAU, 32, Color(1.0, 0.2, 0.2, 1.0 - hit), 3.0)
				var amount := int(effect["amount"])
				var text := "-%d" % amount if amount > 0 else "miss"
				_draw_label(font, text, to + Vector2(0.0, -float(cell_size) * 0.55 - hit * 14.0), 14, Color(1.0, 0.35, 0.3, 1.0 - hit * 0.6))
		"heal":
			var at: Vector2 = effect["at"]
			draw_arc(at, float(cell_size) * 0.42, 0.0, TAU, 32, Color(0.3, 1.0, 0.4, fade), 3.0)
			_draw_label(font, "+%d" % int(effect["amount"]), at + Vector2(0.0, -float(cell_size) * 0.55 - p * 14.0), 14, Color(0.4, 1.0, 0.5, 1.0 - p * 0.6))
		"gone":
			var at: Vector2 = effect["at"]
			var arm := float(cell_size) * 0.3
			draw_line(at + Vector2(-arm, -arm), at + Vector2(arm, arm), Color(1, 1, 1, fade), 3.0)
			draw_line(at + Vector2(-arm, arm), at + Vector2(arm, -arm), Color(1, 1, 1, fade), 3.0)
			_draw_label(font, str(effect["label"]), at + Vector2(0.0, -float(cell_size) * 0.55), 12, Color(1, 1, 1, fade))


func _draw_cell(cell: Vector2i, color: Color, hex: bool, alpha: float = 1.0) -> void:
	var fill := Color(color, alpha)
	if hex:
		var center := cell_center(cell)
		var radius := float(cell_size) * 0.5774
		var points := PackedVector2Array()
		for i: int in 6:
			var angle := PI / 6.0 + float(i) * PI / 3.0
			points.append(center + Vector2(cos(angle), sin(angle)) * radius)
		draw_colored_polygon(points, fill)
		points.append(points[0])
		draw_polyline(points, Color(0, 0, 0, 0.4), 1.0)
	else:
		var rect := Rect2(Vector2(cell) * float(cell_size), Vector2.ONE * float(cell_size))
		draw_rect(rect, fill)
		draw_rect(rect, Color(0, 0, 0, 0.4), false, 1.0)


func _facing_vector(direction: int) -> Vector2:
	var topology := state.grid.topology
	var origin := Vector2i(4, 4)
	var adjacent := topology.neighbors(origin)
	var target := adjacent[posmod(direction, adjacent.size())]
	return (cell_center(target) - cell_center(origin)).normalized()
