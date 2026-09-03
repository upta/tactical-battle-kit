class_name BreachUnitDef
extends UnitDef

## A subclassed def: aim is a game stat the kit knows nothing about, yet the
## loader builds it from JSON through make_unit_def and sweeps reach it as
## unit_defs.<id>.aim with no kit change.

## Base chance to hit, in percent, before cover.
@export var aim: int = 60
