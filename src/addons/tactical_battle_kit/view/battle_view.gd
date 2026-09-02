class_name BattleView
extends Node2D

## Debug renderer: draws a BattleState's grid, overlays, units, hp bars and
## facing ticks with plain shapes. It exists so harness screenshots show
## the battle and so an example plays visibly. Games own their presentation;
## this is not meant to be skinned.

const _FACTION_COLORS: Array[Color] = [
	Color(0.85, 0.25, 0.2), Color(0.2, 0.45, 0.9), Color(0.9, 0.75, 0.2),
	Color(0.5, 0.25, 0.75), Color(0.2, 0.7, 0.6), Color(0.6, 0.6, 0.6),
]

@export var cell_size: int = 48
@export var draw_labels: bool = true

var state: BattleState = null:
	set(value):
		state = value
		queue_redraw()

var _units_drawn: int = 0
var _cells_drawn: int = 0


func refresh() -> void:
	queue_redraw()


## Facts a harness asserts against.
func describe_ui() -> Dictionary:
	return {
		"units_drawn": _units_drawn,
		"cells_drawn": _cells_drawn,
		"cell_size": cell_size,
		"has_state": state != null,
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

	var faction_index: Dictionary[String, int] = {}
	for i: int in state.factions.size():
		faction_index[state.factions[i]] = i

	for unit_id: String in state.sorted_unit_ids():
		var unit := state.units[unit_id]
		if not unit.is_on_field():
			continue
		var color := _FACTION_COLORS[faction_index.get(unit.faction, 0) % _FACTION_COLORS.size()]
		var radius := float(cell_size) * 0.36
		for cell: Vector2i in state.occupied_cells(unit):
			var center := cell_center(cell)
			draw_circle(center, radius, color)
			draw_arc(center, radius, 0.0, TAU, 24, Color.BLACK, 1.5)
			if unit.facing >= 0:
				var tip := center + Vector2(_facing_vector(unit.facing)) * radius
				draw_line(center, tip, Color.WHITE, 2.0)
		var anchor := cell_center(unit.cell)
		var bar_width := float(cell_size) * 0.7
		var bar_origin := anchor + Vector2(-bar_width * 0.5, radius + 3.0)
		draw_rect(Rect2(bar_origin, Vector2(bar_width, 4.0)), Color(0.1, 0.1, 0.1))
		draw_rect(Rect2(bar_origin, Vector2(bar_width * unit.hp_fraction(), 4.0)), Color(0.3, 0.9, 0.3))
		if draw_labels:
			draw_string(font, anchor + Vector2(-radius, 4.0), unit.id, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)
		_units_drawn += 1


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
