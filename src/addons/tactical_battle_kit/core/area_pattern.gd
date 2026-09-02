class_name AreaPattern
extends RefCounted

## The shape of an area effect, resolved against a topology at an anchor.
## Named shapes come from the topology so a radius is a diamond, a square or a
## hex blob as appropriate; explicit offsets are canonical topology offsets and
## work on any grid. Oriented patterns are rotated to a direction index.

enum Kind { RADIUS, RING, LINE, OFFSETS }

var kind: Kind = Kind.RADIUS
var size: int = 1
var include_center: bool = true
## When true, offsets are rotated to the direction passed to resolve().
var oriented: bool = false
var offsets: Array[Vector2i] = []


static func radius(cells: int, with_center: bool = true) -> AreaPattern:
	var pattern := AreaPattern.new()
	pattern.kind = Kind.RADIUS
	pattern.size = cells
	pattern.include_center = with_center
	return pattern


static func ring(cells: int) -> AreaPattern:
	var pattern := AreaPattern.new()
	pattern.kind = Kind.RING
	pattern.size = cells
	return pattern


## A straight line of [param length] cells starting one step from the anchor
## in the resolve direction.
static func line(length: int) -> AreaPattern:
	var pattern := AreaPattern.new()
	pattern.kind = Kind.LINE
	pattern.size = length
	pattern.oriented = true
	return pattern


static func from_offsets(canonical: Array[Vector2i], rotates: bool = false) -> AreaPattern:
	var pattern := AreaPattern.new()
	pattern.kind = Kind.OFFSETS
	pattern.offsets = canonical.duplicate()
	pattern.oriented = rotates
	return pattern


## Cells covered at [param anchor], unbounded. Callers filter by grid bounds.
func resolve(topology: GridTopology, anchor: Vector2i, direction: int = -1) -> Array[Vector2i]:
	match kind:
		Kind.RADIUS:
			return topology.cells_within(anchor, size, include_center)
		Kind.RING:
			return topology.ring(anchor, size)
		Kind.LINE:
			var result: Array[Vector2i] = []
			var step := topology.direction_offset(maxi(direction, 0))
			var current := anchor
			for _i: int in size:
				current = topology.offset_cell(current, step)
				result.append(current)
			return result
	var cells: Array[Vector2i] = []
	for offset: Vector2i in offsets:
		var placed := offset
		if oriented and direction > 0:
			placed = topology.rotate_offset(offset, direction)
		cells.append(topology.offset_cell(anchor, placed))
	return cells


func to_dict() -> Dictionary:
	var offset_list: Array = []
	for offset: Vector2i in offsets:
		offset_list.append([offset.x, offset.y])
	return {
		"kind": Kind.keys()[kind].to_lower(),
		"size": size,
		"include_center": include_center,
		"oriented": oriented,
		"offsets": offset_list,
	}
