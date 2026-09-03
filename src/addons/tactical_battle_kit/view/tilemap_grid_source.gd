class_name TileMapGridSource
extends RefCounted

## Builds a BattleGrid from painted TileMapLayers, so the map a designer
## paints in the editor is the battle's source of truth. Reads tile data
## only (no rendering), so it works headless in the sim.
##
## Contract on the TileSet: a String custom data field (default "terrain")
## naming a terrain id on every tile of the ground layer; overlay layers use
## the same field for the overlay's terrain id; any other custom data field
## listed in data_layers becomes a grid layer of the same name.
##
## The grid's (0, 0) is the ground layer's used-rect origin; origin() gives
## the offset a scene adds to turn a grid cell back into a TileMapLayer cell.


static func origin(ground: TileMapLayer) -> Vector2i:
	return ground.get_used_rect().position


static func build(ground: TileMapLayer, overlays: Array[TileMapLayer], legend: Dictionary, topology: GridTopology, data_layers: Array[String] = [], terrain_key: String = "terrain") -> BattleGrid:
	var rect := ground.get_used_rect()
	var grid := BattleGrid.new(rect.size.x, rect.size.y, topology)
	var offset := rect.position
	for layer_name: String in data_layers:
		grid.add_layer(layer_name, null)

	for y: int in rect.size.y:
		for x: int in rect.size.x:
			var map_cell := offset + Vector2i(x, y)
			var grid_cell := Vector2i(x, y)
			var tile := ground.get_cell_tile_data(map_cell)
			var terrain := _terrain_for(tile, legend, terrain_key)
			if terrain == null:
				push_error("Ground tile at %s has no terrain the legend knows." % str(map_cell))
				continue
			grid.set_terrain(grid_cell, terrain)
			for layer_name: String in data_layers:
				grid.set_layer_value(layer_name, grid_cell, tile.get_custom_data(layer_name))

	for overlay_layer: TileMapLayer in overlays:
		for map_cell: Vector2i in overlay_layer.get_used_cells():
			var grid_cell := map_cell - offset
			if not grid.in_bounds(grid_cell):
				continue
			var terrain := _terrain_for(overlay_layer.get_cell_tile_data(map_cell), legend, terrain_key)
			if terrain != null:
				grid.add_overlay(grid_cell, terrain)
	return grid


## Instantiate a map scene, build from its layers, free it. [param legend]
## is keyed by terrain id.
static func from_scene(scene_path: String, ground_name: String, overlay_names: Array[String], legend: Dictionary, topology: GridTopology, data_layers: Array[String] = [], terrain_key: String = "terrain") -> BattleGrid:
	var packed: PackedScene = load(scene_path)
	if packed == null:
		push_error("Map scene did not load: %s" % scene_path)
		return null
	var scene := packed.instantiate()
	var ground := scene.get_node_or_null(ground_name) as TileMapLayer
	if ground == null:
		push_error("Map scene %s has no TileMapLayer named '%s'." % [scene_path, ground_name])
		scene.free()
		return null
	var overlays: Array[TileMapLayer] = []
	for overlay_name: String in overlay_names:
		var overlay := scene.get_node_or_null(overlay_name) as TileMapLayer
		if overlay != null:
			overlays.append(overlay)
		else:
			push_warning("Map scene %s has no overlay layer '%s'." % [scene_path, overlay_name])
	var grid := build(ground, overlays, legend, topology, data_layers, terrain_key)
	scene.free()
	return grid


static func _terrain_for(tile: TileData, legend: Dictionary, terrain_key: String) -> TerrainDef:
	if tile == null:
		return null
	var terrain_id := str(tile.get_custom_data(terrain_key))
	return legend.get(terrain_id)
