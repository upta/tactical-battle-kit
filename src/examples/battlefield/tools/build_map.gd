extends SceneTree

# One-time map bootstrap for the battlefield demo: a half-offset-square
# TileSet (Liberty or Death's brick rows; hex adjacency, odd-r coordinates)
# and the grassland map as a TileMapLayer scene. After this runs the .tscn
# is the source of truth and is edited in the editor.
#
#   godot --headless --path src --script res://examples/battlefield/tools/build_map.gd

const TILE := 40
const OUT_DIR := "res://examples/battlefield/map/"
const TILESET_PATH := OUT_DIR + "battlefield_tileset.tres"
const MAP_PATH := OUT_DIR + "grassland_map.tscn"

const TILES: Array[Dictionary] = [
	{"name": "grass", "terrain": "grass", "color": Color(0.53, 0.66, 0.38)},
	{"name": "grass_dark", "terrain": "grass", "color": Color(0.47, 0.6, 0.34)},
	{"name": "obstacle", "terrain": "obstacle", "color": Color(0.42, 0.35, 0.26)},
	{"name": "hl_move", "terrain": "", "color": Color(0.35, 0.6, 1.0, 0.5)},
	{"name": "hl_target", "terrain": "", "color": Color(1.0, 0.25, 0.2, 0.5)},
	{"name": "hl_anchor", "terrain": "", "color": Color(1.0, 0.9, 0.3, 0.5)},
	{"name": "hl_body", "terrain": "", "color": Color(1.0, 1.0, 1.0, 0.25)},
]

# 15 x 11, Heroes' battlefield. o = obstacle on the Obstacles layer.
const MAP: Array[String] = [
	"...............",
	"......o........",
	"...............",
	"....o.....o....",
	"...............",
	".......o.......",
	"...............",
	"....o.....o....",
	"...............",
	"........o......",
	"...............",
]


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var tileset := _build_tileset()
	var error := ResourceSaver.save(tileset, TILESET_PATH)
	if error != OK:
		push_error("Could not save tileset: %d" % error)
		quit(1)
		return
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
				image.set_pixel(i * TILE + x, y, color.darkened(0.3) if edge else color)
	var texture := ImageTexture.create_from_image(image)

	var tileset := TileSet.new()
	tileset.tile_shape = TileSet.TILE_SHAPE_HALF_OFFSET_SQUARE
	tileset.tile_offset_axis = TileSet.TILE_OFFSET_AXIS_HORIZONTAL
	tileset.tile_layout = TileSet.TILE_LAYOUT_STACKED
	tileset.tile_size = Vector2i(TILE, TILE)
	tileset.add_custom_data_layer()
	tileset.set_custom_data_layer_name(0, "terrain")
	tileset.set_custom_data_layer_type(0, TYPE_STRING)

	var source := TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = Vector2i(TILE, TILE)
	tileset.add_source(source, 0)
	for i: int in TILES.size():
		var coords := Vector2i(i, 0)
		source.create_tile(coords)
		source.get_tile_data(coords, 0).set_custom_data("terrain", TILES[i]["terrain"])
	return tileset


func _build_map_scene(tileset: TileSet) -> PackedScene:
	var root := Node2D.new()
	root.name = "GrasslandMap"
	var ground := TileMapLayer.new()
	ground.name = "Ground"
	ground.tile_set = tileset
	var obstacles := TileMapLayer.new()
	obstacles.name = "Obstacles"
	obstacles.tile_set = tileset
	root.add_child(ground)
	root.add_child(obstacles)
	ground.owner = root
	obstacles.owner = root

	for y: int in MAP.size():
		for x: int in MAP[y].length():
			ground.set_cell(Vector2i(x, y), 0, Vector2i(1 if (x + y) % 2 == 0 else 0, 0))
			if MAP[y][x] == "o":
				obstacles.set_cell(Vector2i(x, y), 0, Vector2i(2, 0))

	var packed := PackedScene.new()
	packed.pack(root)
	root.free()
	return packed
