class_name UnitDef
extends Resource

## The stat block a unit is stamped from. Subclass to add game fields (jump,
## leadership, mp); balance sweeps patch any exported property by the def's
## [member id], so keep ids stable and unique within a battle.

@export var id: String = "unit"
@export var display_name: String = "Unit"
@export var max_hp: int = 10
@export var attack: int = 4
@export var defense: int = 1
## Movement budget per activation, spent through the ruleset's movement_cost.
@export var move: int = 3
@export var range_min: int = 1
@export var range_max: int = 1
## Free-form labels the damage model and rules key off ("cavalry", "commander").
@export var tags: Array[String] = []
## Cells this unit occupies, as canonical topology offsets from its anchor.
## Symmetric shapes only; footprints do not rotate with facing.
@export var footprint: Array[Vector2i] = [Vector2i.ZERO]
## Occupancy layer ("" ground, "air", ...). Units on different layers share cells.
@export var layer: String = ""


func has_tag(tag: String) -> bool:
	return tags.has(tag)


func apply_overrides(overrides: Dictionary) -> void:
	DefOverrides.apply(self, overrides, "UnitDef '%s'" % id)


func to_dict() -> Dictionary:
	return DefOverrides.to_dict(self)
