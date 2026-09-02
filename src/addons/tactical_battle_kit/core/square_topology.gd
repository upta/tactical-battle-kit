class_name SquareTopology
extends GridTopology

## Square grid. Four neighbors by default, eight with [member diagonals].
## Distance is manhattan (4), chebyshev (8) or rounded euclidean when
## [member euclidean] is set, which is the inch-grid approximation for
## free-movement games.

const _FOUR: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1),
]
const _EIGHT: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1),
	Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
]

var diagonals: bool = false
var euclidean: bool = false


func _init(with_diagonals: bool = false, with_euclidean: bool = false) -> void:
	diagonals = with_diagonals
	euclidean = with_euclidean


func id() -> String:
	if euclidean:
		return "euclid"
	return "square8" if diagonals else "square"


func direction_count() -> int:
	return 8 if diagonals else 4


func neighbors(cell: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for offset: Vector2i in (_EIGHT if diagonals else _FOUR):
		result.append(cell + offset)
	return result


func distance(a: Vector2i, b: Vector2i) -> int:
	var dx := absi(a.x - b.x)
	var dy := absi(a.y - b.y)
	if euclidean:
		return roundi(sqrt(float(dx * dx + dy * dy)))
	return maxi(dx, dy) if diagonals else dx + dy


func offset_cell(anchor: Vector2i, offset: Vector2i) -> Vector2i:
	return anchor + offset


func to_offset(anchor: Vector2i, cell: Vector2i) -> Vector2i:
	return cell - anchor


## Quarter turns on a four-direction grid. With diagonals a step is an eighth
## turn, which is not lattice-preserving for arbitrary offsets, so the result
## is rounded; exact for offsets on the eight rays.
func rotate_offset(offset: Vector2i, steps: int) -> Vector2i:
	if not diagonals:
		var result := offset
		for _i: int in posmod(steps, 4):
			result = Vector2i(-result.y, result.x)
		return result
	var angle := float(posmod(steps, 8)) * PI / 4.0
	var rotated := Vector2(offset).rotated(angle)
	return Vector2i(roundi(rotated.x), roundi(rotated.y))


func line(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var dx := absi(b.x - a.x)
	var dy := -absi(b.y - a.y)
	var sx := 1 if a.x < b.x else -1
	var sy := 1 if a.y < b.y else -1
	var err := dx + dy
	var current := a
	while true:
		result.append(current)
		if current == b:
			break
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			current.x += sx
		if e2 <= dx:
			err += dx
			current.y += sy
	return result
