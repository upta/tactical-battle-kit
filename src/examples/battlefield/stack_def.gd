class_name StackDef
extends UnitDef

## A creature type in a Heroes-style army. A unit built from this is a
## STACK: its hp is the whole stack's pool (count * creature_hp) and its
## count is derived from hp, so damage kills whole creatures. size 2 makes a
## two-cell footprint; the ruleset's factory sets it.

@export var creature_hp: int = 10
@export var damage_min: int = 1
@export var damage_max: int = 3
## Initiative; higher acts first.
@export var speed: int = 4
## Ranged attacks available per battle; 0 means a melee-only creature.
@export var shots: int = 0
## 1 or 2 cells wide.
@export var size: int = 1
@export var flying: bool = false


func count_for(hp: int) -> int:
	return ceili(float(maxi(hp, 0)) / float(maxi(creature_hp, 1)))
