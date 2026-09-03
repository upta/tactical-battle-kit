extends SceneTree

# One-time map bootstrap for the breach demo. Builds the tile atlas (a
# PortableCompressedTexture2D, so no import step), the TileSet with its
# custom data fields, and the warehouse map as a real TileMapLayer scene with
# tile_map_data, then saves all three. After this runs the .tscn is the
# source of truth and is edited in the editor; this script only exists so
# the first version did not have to be painted by hand.
#
#   godot --headless --path src --script res://examples/breach/tools/build_map.gd

const TILE := 32
const OUT_DIR := "res://examples/breach/map/"
const TILESET_PATH := OUT_DIR + "breach_tileset.tres"
const MAP_PATH := OUT_DIR + "warehouse_map.tscn"

# Atlas column -> tile: terrain id, spawn flag, color.
const TILES: Array[Dictionary] = [
	{"name": "floor", "terrain": "floor", "spawn": false, "color": Color(0.54, 0.56, 0.59)},
	{"name": "wall", "terrain": "wall", "spawn": false, "color": Color(0.17, 0.18, 0.2)},
	{"name": "rubble", "terrain": "rubble", "spawn": false, "color": Color(0.44, 0.39, 0.35)},
	{"name": "floor_spawn", "terrain": "floor", "spawn": true, "color": Color(0.6, 0.45, 0.45)},
	{"name": "half_cover", "terrain": "half_cover", "spawn": false, "color": Color(0.72, 0.6, 0.35)},
	{"name": "full_cover", "terrain": "full_cover", "spawn": false, "color": Color(0.36, 0.42, 0.47)},
	{"name": "hl_move", "terrain": "", "spawn": false, "color": Color(0.35, 0.6, 1.0, 0.45)},
	{"name": "hl_target", "terrain": "", "spawn": false, "color": Color(1.0, 0.25, 0.2, 0.45)},
	{"name": "hl_anchor", "terrain": "", "spawn": false, "color": Color(1.0, 0.9, 0.3, 0.45)},
]

# Ground glyphs: . floor, # wall, : rubble, S spawn floor.
# Cover glyphs (on floor): h half, H full.
const MAP: Array[String] = [
	"##################",
	"#........#.......#",
	"#..h.....#...S...#",
	"#....H...:...h...#",
	"#.::.....#.......#",
	"#....h...#.H.....#",
	"#..H.....:.......#",
	"#........#...h...#",
	"#..S.....#.......#",
	"##################",
]


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var tileset := _build_tileset()
	var error := ResourceSaver.save(tileset, TILESET_PATH)
	if error != OK:
		push_error("Could not save tileset: %d" % error)
		quit(1)
		return
	# Reload from disk so the scene references the saved resource by path
	# rather than embedding a copy.
	var saved_tileset: TileSet = ResourceLoader.load(TILESET_PATH, "TileSet", ResourceLoader.CACHE_MODE_REPLACE)
	if saved_tileset == null:
		push_error("Saved tileset did not load back.")
		quit(1)
		return
	var scene := _build_map_scene(saved_tileset)
	error = ResourceSaver.save(scene, MAP_PATH)
	if error != OK:
		push_error("Could not save map scene: %d" % error)
		quit(1)
		return
	print("BUILD MAP COMPLETE: %s, %s" % [TILESET_PATH, MAP_PATH])
	quit(0)


func _build_tileset() -> TileSet:
	var image := Image.create(TILE * TILES.size(), TILE, false, Image.FORMAT_RGBA8)
	for i: int in TILES.size():
		var color: Color = TILES[i]["color"]
		for y: int in TILE:
			for x: int in TILE:
				var edge := x == 0 or y == 0 or x == TILE - 1 or y == TILE - 1
				image.set_pixel(i * TILE + x, y, color.darkened(0.35) if edge else color)
	# ImageTexture embeds its pixels in the .tres; a compressed texture does
	# not serialize to text, and a PNG would need an import pass first.
	var texture := ImageTexture.create_from_image(image)

	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(TILE, TILE)
	tileset.add_custom_data_layer()
	tileset.set_custom_data_layer_name(0, "terrain")
	tileset.set_custom_data_layer_type(0, TYPE_STRING)
	tileset.add_custom_data_layer()
	tileset.set_custom_data_layer_name(1, "spawn")
	tileset.set_custom_data_layer_type(1, TYPE_BOOL)

	var source := TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = Vector2i(TILE, TILE)
	# The source must belong to the set before its tiles can carry custom
	# data; the layers are the set's.
	tileset.add_source(source, 0)
	for i: int in TILES.size():
		var coords := Vector2i(i, 0)
		source.create_tile(coords)
		var data := source.get_tile_data(coords, 0)
		data.set_custom_data("terrain", TILES[i]["terrain"])
		data.set_custom_data("spawn", TILES[i]["spawn"])
	return tileset


func _build_map_scene(tileset: TileSet) -> PackedScene:
	var root := Node2D.new()
	root.name = "WarehouseMap"
	var ground := TileMapLayer.new()
	ground.name = "Ground"
	ground.tile_set = tileset
	var cover := TileMapLayer.new()
	cover.name = "Cover"
	cover.tile_set = tileset
	root.add_child(ground)
	root.add_child(cover)
	ground.owner = root
	cover.owner = root

	for y: int in MAP.size():
		for x: int in MAP[y].length():
			var glyph := MAP[y][x]
			var ground_tile := _tile_index("floor")
			match glyph:
				"#":
					ground_tile = _tile_index("wall")
				":":
					ground_tile = _tile_index("rubble")
				"S":
					ground_tile = _tile_index("floor_spawn")
			ground.set_cell(Vector2i(x, y), 0, Vector2i(ground_tile, 0))
			if glyph == "h":
				cover.set_cell(Vector2i(x, y), 0, Vector2i(_tile_index("half_cover"), 0))
			elif glyph == "H":
				cover.set_cell(Vector2i(x, y), 0, Vector2i(_tile_index("full_cover"), 0))

	var packed := PackedScene.new()
	packed.pack(root)
	root.free()
	return packed


func _tile_index(tile_name: String) -> int:
	for i: int in TILES.size():
		if str(TILES[i]["name"]) == tile_name:
			return i
	return 0
