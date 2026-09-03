@abstract
class_name GridTopology
extends RefCounted

## Adjacency, distance, direction and shape for one grid geometry. Cells are
## Vector2i everywhere in the kit; the topology is the only place that knows
## what "next to", "behind" or "within 2" mean, so square and hex battles
## share every other rule.
##
## Directions are indices 0..direction_count()-1 in the order neighbors()
## returns them, clockwise from east. Pattern and footprint offsets are given
## in the topology's canonical offset space and placed with offset_cell().


## Stable id used by battle JSON ("topology": "hex").
@abstract func id() -> String


## Number of facing directions: 4, 8 or 6.
@abstract func direction_count() -> int


## Every cell adjacent to [param cell] in direction order, ignoring bounds.
@abstract func neighbors(cell: Vector2i) -> Array[Vector2i]


## Minimum number of steps between two cells over open ground.
@abstract func distance(a: Vector2i, b: Vector2i) -> int


## Place a canonical offset relative to [param anchor]. Square: plain delta.
## Hex: axial delta, so the same pattern lands correctly on either row parity.
@abstract func offset_cell(anchor: Vector2i, offset: Vector2i) -> Vector2i


## Rotate a canonical offset clockwise by [param steps] direction steps.
@abstract func rotate_offset(offset: Vector2i, steps: int) -> Vector2i


## Every cell on the straight line from [param a] to [param b], both included.
@abstract func line(a: Vector2i, b: Vector2i) -> Array[Vector2i]


## The direction index from [param from] toward [param to]: exact for adjacent
## cells, the closest neighbor direction otherwise. -1 when the cells match.
func direction_to(from: Vector2i, to: Vector2i) -> int:
	if from == to:
		return -1
	var adjacent := neighbors(from)
	var best := -1
	var best_distance := 0
	for i: int in adjacent.size():
		var d := distance(adjacent[i], to)
		if best < 0 or d < best_distance:
			best = i
			best_distance = d
	return best


## Angular separation in direction steps between a facing and an incoming
## direction: 0 is a frontal hit, direction_count() / 2 is the rear.
func arc(facing: int, incoming: int) -> int:
	if facing < 0 or incoming < 0:
		return 0
	var n := direction_count()
	var delta := absi(facing - incoming) % n
	return mini(delta, n - delta)


## The canonical offset for one direction step.
func direction_offset(direction: int) -> Vector2i:
	var origin := Vector2i.ZERO
	var adjacent := neighbors(origin)
	return to_offset(origin, adjacent[posmod(direction, adjacent.size())])


## Inverse of offset_cell: the canonical offset that maps [param anchor] to
## [param cell].
@abstract func to_offset(anchor: Vector2i, cell: Vector2i) -> Vector2i


## All cells within [param radius] steps of [param center], ignoring bounds.
func cells_within(center: Vector2i, radius: int, include_center: bool = true) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for dy: int in range(-radius, radius + 1):
		for dx: int in range(-radius, radius + 1):
			var cell := Vector2i(center.x + dx, center.y + dy)
			if cell == center and not include_center:
				continue
			if distance(center, cell) <= radius:
				result.append(cell)
	return result


## Cells at exactly [param radius] steps from [param center].
func ring(center: Vector2i, radius: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for dy: int in range(-radius, radius + 1):
		for dx: int in range(-radius, radius + 1):
			var cell := Vector2i(center.x + dx, center.y + dy)
			if distance(center, cell) == radius:
				result.append(cell)
	return result


static func from_id(topology_id: String) -> GridTopology:
	match topology_id:
		"square", "":
			return SquareTopology.new()
		"square8":
			return SquareTopology.new(true)
		"euclid":
			return SquareTopology.new(true, true)
		"hex":
			return HexTopology.new()
		"hex_columns":
			return HexTopology.new(true)
	push_error("Unknown grid topology id: %s" % topology_id)
	return null
