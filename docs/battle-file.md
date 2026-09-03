# Battle file

A battle is a JSON object `BattleLoader` turns into a `BattleState`. Every
def goes through the ruleset's factories, so subclassed resources work, and
every override root is applied here, so suites and tests share one path.

```json
{
  "battle_id": "open_field",
  "ruleset": "res://examples/skirmish/skirmish_ruleset.gd",
  "topology": "square",
  "terrain_legend": {
    ".": "res://examples/skirmish/data/terrain/plain.tres",
    "f": {"id": "forest", "glyph": "f", "move_cost": 2, "defense_bonus": 0.5, "tags": ["forest"]}
  },
  "map": ["......", "..ff..", "......"],
  "cell_layers": {"height": ["000000", "001100", "000000"]},
  "overlays": [{"cell": [3, 0], "terrain": {"id": "fence", "passable": false, "tags": ["fence"]}}],
  "unit_defs": {
    "spearman": "res://examples/skirmish/data/unit_defs/spearman.tres",
    "scout": {"id": "scout", "max_hp": 8, "attack": 3, "defense": 1, "move": 5, "tags": ["infantry"]}
  },
  "factions": [{"id": "red", "ai": "greedy"}, {"id": "blue", "ai": "random"}],
  "custom": {"supply": {"red": 10, "blue": 6}},
  "units": [
    {"id": "r1", "faction": "red", "def": "spearman", "cell": [1, 1], "facing": 0, "custom": {"commander": "r_cmd"}},
    {"id": "b1", "faction": "blue", "def": "scout", "cell": [4, 1], "hp": 5, "layer": "", "status": "active"}
  ]
}
```

| Key | Meaning |
| --- | --- |
| `battle_id` | Name in reports and the viewer's boot marker |
| `ruleset` | Script path of the `BattleRuleset` subclass; instantiated per load |
| `topology` | `square`, `square8`, `euclid`, `hex` (odd-r rows, pointy-top), `hex_columns` (odd-q columns, flat-top); omitted means `ruleset.topology()` |
| `terrain_legend` | Glyph to a `.tres` path, a `.json` path, or an inline dict |
| `map` | Rows of glyphs; ragged rows pad with an error |
| `map_scene`, `ground_layer`, `overlay_layers`, `data_layers`, `terrain_key` | Painted map instead of rows: the scene's TileMapLayers are read through `TileMapGridSource`; `terrain_legend` is then keyed by terrain id |
| `cell_layers` | Named per-cell layers as rows; digits become ints, anything else a string |
| `overlays` | Terrain stacked on specific cells |
| `unit_defs` | Named defs; a unit's `def` may be one of these names, a path, or an inline dict |
| `factions` | Declared order is the default turn order; `ai` is the default AI id |
| `custom` | Initial `state.custom` |
| `units` | `id`, `faction`, `def`, `cell`, and optional per-instance `hp`, `facing`, `layer`, `status`, `custom` |

Facing is a direction index of the topology (square: E, S, W, N; hex: E, SE,
SW, W, NW, NE). Cells are `[x, y]` with y down; hex cells are odd-r offset
coordinates, so a map row is a grid row.

Overrides (from a suite's `overrides` or `sweep`) are applied in this order:
`battle` is deep-merged onto the file before anything is built; `ruleset`
goes to `configure()`; `terrain_defs.<id>` and `unit_defs.<id>` patch the
resolved defs by their `id` field, whatever their source.
