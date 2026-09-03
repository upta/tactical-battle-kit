class_name HexTopology
extends GridTopology

## Hex adjacency stored in a rectangular grid. Two layouts:
## - rows (default, id "hex"): pointy-top hexes in "odd-r" offset
##   coordinates, odd rows shoved half a cell right. Godot: horizontal offset
##   axis, stacked layout.
## - columns (id "hex_columns"): flat-top hexes in "odd-q" coordinates, odd
##   columns shoved half a cell down. Godot: vertical offset axis, stacked.
## Every calculation converts to axial (q, r) first; canonical offsets for
## patterns and footprints are axial deltas, so a pattern authored once lands
## correctly in either layout.

## Rows layout, clockwise from east: E, SE, SW, W, NW, NE.
const _ROW_DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 1),
	Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, -1),
]
## Columns layout, clockwise from north: N, NE, SE, S, SW, NW.
const _COLUMN_DIRECTIONS: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0),
	Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0),
]

var columns: bool = false


func _init(column_layout: bool = false) -> void:
	columns = column_layout


func id() -> String:
	return "hex_columns" if columns else "hex"


func direction_count() -> int:
	return 6


func neighbors(cell: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for delta: Vector2i in (_COLUMN_DIRECTIONS if columns else _ROW_DIRECTIONS):
		result.append(offset_cell(cell, delta))
	return result


func distance(a: Vector2i, b: Vector2i) -> int:
	var ca := to_axial(a)
	var cb := to_axial(b)
	var dq := ca.x - cb.x
	var dr := ca.y - cb.y
	return maxi(absi(dq), maxi(absi(dr), absi(dq + dr)))


func offset_cell(anchor: Vector2i, offset: Vector2i) -> Vector2i:
	return from_axial(to_axial(anchor) + offset)


func to_offset(anchor: Vector2i, cell: Vector2i) -> Vector2i:
	return to_axial(cell) - to_axial(anchor)


## Sixty-degree turns via cube rotation, exact for every offset.
func rotate_offset(offset: Vector2i, steps: int) -> Vector2i:
	var q := offset.x
	var r := offset.y
	var s := -q - r
	for _i: int in posmod(steps, 6):
		var next_q := -r
		var next_r := -s
		s = -q
		q = next_q
		r = next_r
	return Vector2i(q, r)


func line(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var steps := distance(a, b)
	if steps == 0:
		result.append(a)
		return result
	var start := Vector2(to_axial(a))
	var end := Vector2(to_axial(b))
	for i: int in steps + 1:
		var t := float(i) / float(steps)
		result.append(from_axial(_round_axial(start.lerp(end, t))))
	return result


func to_axial(cell: Vector2i) -> Vector2i:
	if columns:
		var r := cell.y - (cell.x - (cell.x & 1)) / 2
		return Vector2i(cell.x, r)
	var q := cell.x - (cell.y - (cell.y & 1)) / 2
	return Vector2i(q, cell.y)


func from_axial(axial: Vector2i) -> Vector2i:
	if columns:
		var y := axial.y + (axial.x - (axial.x & 1)) / 2
		return Vector2i(axial.x, y)
	var x := axial.x + (axial.y - (axial.y & 1)) / 2
	return Vector2i(x, axial.y)


static func _round_axial(axial: Vector2) -> Vector2i:
	var x := axial.x
	var z := axial.y
	var y := -x - z
	var rx := roundf(x)
	var ry := roundf(y)
	var rz := roundf(z)
	var x_diff := absf(rx - x)
	var y_diff := absf(ry - y)
	var z_diff := absf(rz - z)
	if x_diff > y_diff and x_diff > z_diff:
		rx = -ry - rz
	elif y_diff > z_diff:
		ry = -rx - rz
	else:
		rz = -rx - ry
	return Vector2i(int(rx), int(rz))
