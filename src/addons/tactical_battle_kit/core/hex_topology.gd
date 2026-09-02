class_name HexTopology
extends GridTopology

## Pointy-top hexes stored in "odd-r" offset coordinates: rows are straight,
## odd rows are shoved half a cell to the right, so an ASCII map row is a grid
## row. Every calculation converts to axial (q, r) first; canonical offsets for
## patterns and footprints are axial deltas.

## Direction order: E, SE, SW, W, NW, NE (clockwise, y down) as axial deltas.
const _AXIAL_DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 1),
	Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, -1),
]


func id() -> String:
	return "hex"


func direction_count() -> int:
	return 6


func neighbors(cell: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for delta: Vector2i in _AXIAL_DIRECTIONS:
		result.append(offset_cell(cell, delta))
	return result


func distance(a: Vector2i, b: Vector2i) -> int:
	var ca := _to_axial(a)
	var cb := _to_axial(b)
	var dq := ca.x - cb.x
	var dr := ca.y - cb.y
	return maxi(absi(dq), maxi(absi(dr), absi(dq + dr)))


func offset_cell(anchor: Vector2i, offset: Vector2i) -> Vector2i:
	return _from_axial(_to_axial(anchor) + offset)


func to_offset(anchor: Vector2i, cell: Vector2i) -> Vector2i:
	return _to_axial(cell) - _to_axial(anchor)


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
	var start := Vector2(_to_axial(a))
	var end := Vector2(_to_axial(b))
	for i: int in steps + 1:
		var t := float(i) / float(steps)
		result.append(_from_axial(_round_axial(start.lerp(end, t))))
	return result


static func _to_axial(cell: Vector2i) -> Vector2i:
	var q := cell.x - (cell.y - (cell.y & 1)) / 2
	return Vector2i(q, cell.y)


static func _from_axial(axial: Vector2i) -> Vector2i:
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
