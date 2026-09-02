class_name TerrainDef
extends Resource

## One kind of ground, or one kind of overlay (fence, fire, cover). Authored
## as a .tres for designers or built from a dict by the loader through the
## ruleset's factory. Subclass to add game fields; overrides and sweeps reach
## any exported property.

@export var id: String = "plain"
@export var display_name: String = "Plain"
## Movement points spent to enter a cell carrying this terrain. The default
## movement model sums the stack; a ruleset may ignore it entirely.
@export var move_cost: int = 1
## Fraction added to a defender's defense while standing here (0.5 = +50%).
@export var defense_bonus: float = 0.0
@export var passable: bool = true
## Single character used in ASCII maps.
@export var glyph: String = "."
@export var color: Color = Color(0.55, 0.7, 0.4)
## Free-form labels rules key off ("forest", "fence", "castle", "blocks_los").
@export var tags: Array[String] = []


func has_tag(tag: String) -> bool:
	return tags.has(tag)


func apply_overrides(overrides: Dictionary) -> void:
	DefOverrides.apply(self, overrides, "TerrainDef '%s'" % id)


func to_dict() -> Dictionary:
	return DefOverrides.to_dict(self)
