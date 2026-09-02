class_name BattleGrid
extends RefCounted

## Named layers of flat width*height arrays plus an overlay stack per cell.
## The "terrain" layer holds TerrainDef references; other layers hold whatever
## the game puts there (heights, regions, fog). Overlays are TerrainDefs
## stacked on top of the base terrain (fences, fire, cover) and are the right
## home for anything that is on SOME cells; a layer is for anything EVERY cell
## has a value for. Knows nothing about units.

const TERRAIN_LAYER := "terrain"
const _OVERLAY_LAYER := "__overlays"

var width: int = 0
var height: int = 0
var topology: GridTopology = SquareTopology.new()
var _layers: Dictionary[String, Array] = {}


func _init(grid_width: int = 0, grid_height: int = 0, grid_topology: GridTopology = null) -> void:
	width = grid_width
	height = grid_height
	if grid_topology != null:
		topology = grid_topology
	add_layer(TERRAIN_LAYER, TerrainDef.new())
	var overlays: Array = []
	overlays.resize(width * height)
	for i: int in overlays.size():
		overlays[i] = []
	_layers[_OVERLAY_LAYER] = overlays


## Build from rows of glyphs. Every glyph must be in [param legend].
static func from_ascii(rows: Array, legend: Dictionary, grid_topology: GridTopology = null) -> BattleGrid:
	var grid_height := rows.size()
	var grid_width := 0
	for row: Variant in rows:
		grid_width = maxi(grid_width, str(row).length())
	var grid := BattleGrid.new(grid_width, grid_height, grid_topology)
	for y: int in grid_height:
		var row := str(rows[y])
		for x: int in grid_width:
			var glyph := row[x] if x < row.length() else " "
			var terrain: TerrainDef = legend.get(glyph)
			if terrain == null:
				push_error("Map glyph '%s' at (%d,%d) is not in the terrain legend." % [glyph, x, y])
				continue
			grid.set_terrain(Vector2i(x, y), terrain)
	return grid


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < width and cell.y < height


func index_of(cell: Vector2i) -> int:
	return cell.y * width + cell.x


# --- Layers ---


func add_layer(layer_name: String, fill: Variant) -> void:
	var values: Array = []
	values.resize(width * height)
	values.fill(fill)
	_layers[layer_name] = values


func has_layer(layer_name: String) -> bool:
	return _layers.has(layer_name) and layer_name != _OVERLAY_LAYER


func layer_names() -> Array[String]:
	var names: Array[String] = []
	for layer_name: String in _layers.keys():
		if layer_name != _OVERLAY_LAYER:
			names.append(layer_name)
	return names


func get_layer_value(layer_name: String, cell: Vector2i, default: Variant = null) -> Variant:
	if not in_bounds(cell) or not _layers.has(layer_name):
		return default
	return _layers[layer_name][index_of(cell)]


func set_layer_value(layer_name: String, cell: Vector2i, value: Variant) -> void:
	if not _layers.has(layer_name):
		add_layer(layer_name, null)
	if in_bounds(cell):
		_layers[layer_name][index_of(cell)] = value


# --- Terrain and overlays ---


## Base terrain of the cell, ignoring overlays.
func base_terrain_at(cell: Vector2i) -> TerrainDef:
	return get_layer_value(TERRAIN_LAYER, cell)


## The topmost terrain: the last overlay if any, else the base.
func terrain_at(cell: Vector2i) -> TerrainDef:
	if not in_bounds(cell):
		return null
	var overlays: Array = _layers[_OVERLAY_LAYER][index_of(cell)]
	if overlays.is_empty():
		return base_terrain_at(cell)
	return overlays[overlays.size() - 1]


func set_terrain(cell: Vector2i, terrain: TerrainDef) -> void:
	set_layer_value(TERRAIN_LAYER, cell, terrain)


## Base first, overlays in the order they were added.
func terrain_stack(cell: Vector2i) -> Array[TerrainDef]:
	var stack: Array[TerrainDef] = []
	if not in_bounds(cell):
		return stack
	stack.append(base_terrain_at(cell))
	for overlay: TerrainDef in _layers[_OVERLAY_LAYER][index_of(cell)]:
		stack.append(overlay)
	return stack


func overlays_at(cell: Vector2i) -> Array[TerrainDef]:
	var result: Array[TerrainDef] = []
	if in_bounds(cell):
		result.assign(_layers[_OVERLAY_LAYER][index_of(cell)])
	return result


func add_overlay(cell: Vector2i, terrain: TerrainDef) -> void:
	if in_bounds(cell):
		_layers[_OVERLAY_LAYER][index_of(cell)].append(terrain)


## Remove every overlay carrying [param tag]; returns how many were removed.
func remove_overlay(cell: Vector2i, tag: String) -> int:
	if not in_bounds(cell):
		return 0
	var overlays: Array = _layers[_OVERLAY_LAYER][index_of(cell)]
	var kept: Array = []
	var removed := 0
	for overlay: TerrainDef in overlays:
		if overlay.has_tag(tag):
			removed += 1
		else:
			kept.append(overlay)
	_layers[_OVERLAY_LAYER][index_of(cell)] = kept
	return removed


func has_tag_at(cell: Vector2i, tag: String) -> bool:
	for terrain: TerrainDef in terrain_stack(cell):
		if terrain.has_tag(tag):
			return true
	return false


# --- Geometry pass-throughs (bounded) ---


func neighbors(cell: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for candidate: Vector2i in topology.neighbors(cell):
		if in_bounds(candidate):
			result.append(candidate)
	return result


func distance(a: Vector2i, b: Vector2i) -> int:
	return topology.distance(a, b)


func bounded(cells: Array[Vector2i]) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell: Vector2i in cells:
		if in_bounds(cell):
			result.append(cell)
	return result


func all_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y: int in height:
		for x: int in width:
			cells.append(Vector2i(x, y))
	return cells


# --- Copy and export ---


func clone() -> BattleGrid:
	var copy := BattleGrid.new(width, height, topology)
	for layer_name: String in _layers.keys():
		if layer_name == _OVERLAY_LAYER:
			var overlays: Array = []
			overlays.resize(width * height)
			for i: int in overlays.size():
				overlays[i] = (_layers[layer_name][i] as Array).duplicate()
			copy._layers[layer_name] = overlays
		else:
			copy._layers[layer_name] = _layers[layer_name].duplicate()
	return copy


func to_ascii() -> Array[String]:
	var rows: Array[String] = []
	for y: int in height:
		var row := ""
		for x: int in width:
			row += terrain_at(Vector2i(x, y)).glyph
		rows.append(row)
	return rows


func to_dict() -> Dictionary:
	var layers := {}
	for layer_name: String in layer_names():
		if layer_name == TERRAIN_LAYER:
			continue
		var rows: Array = []
		for y: int in height:
			var row: Array = []
			for x: int in width:
				row.append(DefOverrides.jsonify(get_layer_value(layer_name, Vector2i(x, y))))
			rows.append(row)
		layers[layer_name] = rows
	return {
		"width": width,
		"height": height,
		"topology": topology.id(),
		"map": to_ascii(),
		"layers": layers,
	}
