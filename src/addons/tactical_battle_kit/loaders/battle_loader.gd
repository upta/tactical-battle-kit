class_name BattleLoader
extends RefCounted

## Builds a [BattleState] from a battle dictionary (usually a JSON file).
## Every def is created through the ruleset's factories so subclassed
## resources work; every override root ("battle", "ruleset", "unit_defs",
## "terrain_defs") is applied here so sims and tests share one code path.
##
## Battle file shape:
##   battle_id, ruleset (script path), topology (id, optional),
##   terrain_legend {glyph: path | dict}, map [rows], cell_layers {name: [rows]},
##   overlays [{cell, terrain}], unit_defs {key: path | dict},
##   factions [{id, ai} | id], units [{id, faction, def, cell, hp?, facing?,
##   layer?, status?, custom?}], custom {}
## Painted map instead of rows: map_scene (tscn path), ground_layer (node
## name, default "Ground"), overlay_layers [names], data_layers [custom data
## fields that become grid layers], terrain_key (default "terrain"); then
## terrain_legend is keyed by terrain id.


static func load_file(path: String, overrides: Dictionary = {}) -> BattleState:
	var data := read_json(path)
	if data.is_empty():
		return null
	return build(data, overrides)


static func read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("Battle file not found: %s" % path)
		return {}
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_error("Battle file is not a JSON object: %s" % path)
		return {}
	return parsed


## Resolve the ruleset from the data and build.
static func build(data: Dictionary, overrides: Dictionary = {}) -> BattleState:
	var merged := deep_merge(data, overrides.get("battle", {}))
	var ruleset_path := str(merged.get("ruleset", ""))
	if ruleset_path.is_empty():
		push_error("Battle '%s' names no ruleset script." % str(merged.get("battle_id", "?")))
		return null
	var script: GDScript = load(ruleset_path)
	if script == null:
		push_error("Ruleset script did not load: %s" % ruleset_path)
		return null
	if not script.can_instantiate():
		push_error("Ruleset script failed to compile: %s (the parse errors above are the cause)." % ruleset_path)
		return null
	var ruleset: BattleRuleset = script.new()
	return build_with_ruleset(merged, ruleset, overrides)


static func build_with_ruleset(data: Dictionary, ruleset: BattleRuleset, overrides: Dictionary = {}) -> BattleState:
	ruleset.configure(overrides.get("ruleset", {}))
	var ai_scripts := ruleset.ai_scripts()
	for ai_id: String in ai_scripts.keys():
		AiRegistry.register(ai_id, ai_scripts[ai_id])

	var state := BattleState.new()
	state.battle_id = str(data.get("battle_id", "battle"))
	state.ruleset = ruleset
	state.custom = (data.get("custom", {}) as Dictionary).duplicate(true)

	var topology_id := str(data.get("topology", ""))
	var topology := GridTopology.from_id(topology_id) if not topology_id.is_empty() else ruleset.topology()

	var terrain_overrides: Dictionary = overrides.get("terrain_defs", {})
	var legend := {}
	var legend_data: Dictionary = data.get("terrain_legend", {})
	for glyph: String in legend_data.keys():
		var terrain := _resolve_terrain(legend_data[glyph], ruleset, terrain_overrides)
		if terrain != null:
			legend[glyph] = terrain
	if data.has("map_scene"):
		# Painted map: the TileMapLayers are the source of truth and the
		# legend is keyed by terrain id rather than glyph.
		var overlay_names: Array[String] = []
		overlay_names.assign(data.get("overlay_layers", []))
		var data_layers: Array[String] = []
		data_layers.assign(data.get("data_layers", []))
		state.grid = TileMapGridSource.from_scene(
			str(data["map_scene"]), str(data.get("ground_layer", "Ground")), overlay_names,
			legend, topology, data_layers, str(data.get("terrain_key", "terrain")))
		if state.grid == null:
			return null
	else:
		var rows: Array = data.get("map", [])
		if rows.is_empty():
			push_error("Battle '%s' has no map rows." % state.battle_id)
			return null
		state.grid = BattleGrid.from_ascii(rows, legend, topology)

	var cell_layers: Dictionary = data.get("cell_layers", {})
	for layer_name: String in cell_layers.keys():
		_apply_cell_layer(state.grid, layer_name, cell_layers[layer_name])

	for overlay_entry: Dictionary in data.get("overlays", []):
		var terrain := _resolve_terrain(overlay_entry.get("terrain"), ruleset, terrain_overrides)
		if terrain != null:
			state.grid.add_overlay(_cell(overlay_entry.get("cell", [0, 0])), terrain)

	for faction_entry: Variant in data.get("factions", []):
		if faction_entry is Dictionary:
			var faction_id := str(faction_entry.get("id"))
			state.factions.append(faction_id)
			if faction_entry.has("ai"):
				state.faction_ai[faction_id] = str(faction_entry["ai"])
		else:
			state.factions.append(str(faction_entry))

	var unit_def_overrides: Dictionary = overrides.get("unit_defs", {})
	var named_defs: Dictionary = data.get("unit_defs", {})
	var def_cache: Dictionary[String, UnitDef] = {}
	for entry: Dictionary in data.get("units", []):
		var def := _resolve_unit_def(entry.get("def"), named_defs, ruleset, unit_def_overrides, def_cache)
		if def == null:
			return null
		var unit := ruleset.make_unit(str(entry.get("id")), def, str(entry.get("faction")), _cell(entry.get("cell", [0, 0])), entry)
		state.add_unit(unit)
	# An override for a def no unit uses would otherwise apply to nothing and
	# leave every sweep cell identical; a sim suite with a typo must not pass.
	var applied_def_ids: Array[String] = []
	for def: UnitDef in def_cache.values():
		applied_def_ids.append(def.id)
	for def_id: Variant in unit_def_overrides.keys():
		if not applied_def_ids.has(str(def_id)):
			push_error("Override names unit def '%s' but no unit in battle '%s' uses it (defs: %s)." % [str(def_id), state.battle_id, ", ".join(applied_def_ids)])
			return null
	return state


static func _resolve_terrain(source: Variant, ruleset: BattleRuleset, overrides: Dictionary) -> TerrainDef:
	var terrain: TerrainDef = null
	if source is String:
		var path := str(source)
		if path.ends_with(".json"):
			terrain = ruleset.make_terrain_def(read_json(path))
		else:
			var loaded: Resource = load(path)
			terrain = loaded as TerrainDef
			if terrain == null:
				push_error("Terrain resource did not load as TerrainDef: %s" % path)
				return null
			terrain = terrain.duplicate()
	elif source is Dictionary:
		terrain = ruleset.make_terrain_def(source)
	if terrain != null and overrides.has(terrain.id):
		terrain.apply_overrides(overrides[terrain.id])
	return terrain


static func _resolve_unit_def(source: Variant, named: Dictionary, ruleset: BattleRuleset, overrides: Dictionary, cache: Dictionary[String, UnitDef]) -> UnitDef:
	var key := ""
	var def: UnitDef = null
	if source is String:
		key = str(source)
		if cache.has(key):
			return cache[key]
		if named.has(key):
			def = _resolve_unit_def(named[key], {}, ruleset, {}, cache)
		elif key.ends_with(".json"):
			def = ruleset.make_unit_def(read_json(key))
		else:
			var loaded: Resource = load(key)
			def = loaded as UnitDef
			if def == null:
				push_error("Unit def did not resolve: %s" % key)
				return null
			def = def.duplicate()
	elif source is Dictionary:
		def = ruleset.make_unit_def(source)
		key = def.id
		if cache.has(key):
			return cache[key]
	if def == null:
		push_error("Unit entry has no usable def: %s" % str(source))
		return null
	if overrides.has(def.id):
		def.apply_overrides(overrides[def.id])
	cache[key] = def
	return def


static func _apply_cell_layer(grid: BattleGrid, layer_name: String, rows: Array) -> void:
	grid.add_layer(layer_name, null)
	for y: int in mini(rows.size(), grid.height):
		var row := str(rows[y])
		for x: int in mini(row.length(), grid.width):
			var glyph := row[x]
			var value: Variant = int(glyph) if glyph.is_valid_int() else glyph
			grid.set_layer_value(layer_name, Vector2i(x, y), value)


static func _cell(value: Variant) -> Vector2i:
	if value is Array and value.size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	return Vector2i.ZERO


## Recursive merge: dictionaries merge, everything else is replaced.
static func deep_merge(base: Dictionary, patch: Dictionary) -> Dictionary:
	var result := base.duplicate(true)
	for key: Variant in patch.keys():
		if result.has(key) and result[key] is Dictionary and patch[key] is Dictionary:
			result[key] = deep_merge(result[key], patch[key])
		else:
			result[key] = patch[key]
	return result


## Set a dotted path ("unit_defs.cavalry.attack") in a nested dictionary.
static func set_dotted_path(target: Dictionary, path: String, value: Variant) -> void:
	var keys := path.split(".")
	var cursor := target
	for i: int in keys.size() - 1:
		var key := keys[i]
		if not cursor.has(key) or not (cursor[key] is Dictionary):
			cursor[key] = {}
		cursor = cursor[key]
	cursor[keys[keys.size() - 1]] = value
