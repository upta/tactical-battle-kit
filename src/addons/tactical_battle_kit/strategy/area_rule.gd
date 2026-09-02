@abstract
class_name AreaRule
extends ActionRule

## Template for area effects: heals, spells, breath weapons, artillery. The
## rule picks anchors within cast_range (0 = the caster's own cell), resolves
## a pattern there, filters the units covered by who it affects, and calls
## affect() once per unit. Oriented patterns enumerate one action per
## direction. Subclasses implement affect() and usually after_apply() to spend
## a resource.

const AFFECTS_ENEMIES := "enemies"
const AFFECTS_ALLIES := "allies"
const AFFECTS_ALL := "all"

var cast_range: int = 0
var affects: String = AFFECTS_ENEMIES


func pattern() -> AreaPattern:
	return AreaPattern.radius(1)


## Anchor cells this unit may target. Default: within cast_range, in bounds.
func anchors(state: BattleState, unit: BattleUnit) -> Array[Vector2i]:
	if cast_range <= 0:
		return [unit.cell]
	return state.grid.bounded(state.grid.topology.cells_within(unit.cell, cast_range))


func enumerate(state: BattleState, unit: BattleUnit) -> Array[BattleAction]:
	var actions: Array[BattleAction] = []
	var oriented := pattern().oriented
	for anchor: Vector2i in anchors(state, unit):
		if oriented:
			for direction: int in state.grid.topology.direction_count():
				actions.append(make_action(unit, {"anchor": anchor, "direction": direction}))
		else:
			actions.append(make_action(unit, {"anchor": anchor, "direction": -1}))
	return actions


## Cells covered by an action, bounded to the grid.
func covered_cells(state: BattleState, action: BattleAction) -> Array[Vector2i]:
	var anchor: Vector2i = action.params.get("anchor", Vector2i.ZERO)
	var direction := int(action.params.get("direction", -1))
	return state.grid.bounded(pattern().resolve(state.grid.topology, anchor, direction))


func affected_units(state: BattleState, caster: BattleUnit, cells: Array[Vector2i]) -> Array[BattleUnit]:
	var targets: Array[BattleUnit] = []
	for cell: Vector2i in cells:
		for candidate: BattleUnit in state.units_at(cell):
			if targets.has(candidate):
				continue
			var hostile := state.ruleset.are_enemies(caster.faction, candidate.faction)
			match affects:
				AFFECTS_ENEMIES:
					if hostile:
						targets.append(candidate)
				AFFECTS_ALLIES:
					if not hostile:
						targets.append(candidate)
				_:
					targets.append(candidate)
	return targets


func apply(state: BattleState, engine: BattleEngine, action: BattleAction, rng: BattleRng) -> void:
	var caster := state.unit(action.unit_id)
	var cells := covered_cells(state, action)
	var anchor: Vector2i = action.params.get("anchor", caster.cell)
	engine.emit(state, {
		"type": BattleEvents.ABILITY_USED,
		"unit_id": caster.id,
		"ability": id(),
		"anchor": BattleEvents.cell(anchor),
		"cells": BattleEvents.cells(cells),
	})
	for target: BattleUnit in affected_units(state, caster, cells):
		affect(state, engine, caster, target, rng)
	after_apply(state, engine, caster, action)


## What happens to one unit in the area.
@abstract func affect(state: BattleState, engine: BattleEngine, caster: BattleUnit, target: BattleUnit, rng: BattleRng) -> void


func after_apply(_state: BattleState, _engine: BattleEngine, _caster: BattleUnit, _action: BattleAction) -> void:
	pass


## Convenience for damage-dealing affect() implementations.
func deal_damage(state: BattleState, engine: BattleEngine, source: BattleUnit, target: BattleUnit, damage: int) -> void:
	target.hp -= maxi(damage, 0)
	engine.emit(state, {
		"type": BattleEvents.ATTACKED,
		"attacker_id": source.id,
		"defender_id": target.id,
		"damage": maxi(damage, 0),
		"counter": false,
		"ability": id(),
		"defender_hp": target.hp,
	})
	if target.hp <= 0:
		engine.kill(state, target, source.id)


## Convenience for healing affect() implementations.
func heal(state: BattleState, engine: BattleEngine, source: BattleUnit, target: BattleUnit, amount: int) -> void:
	var before := target.hp
	target.hp = mini(target.def.max_hp, target.hp + maxi(amount, 0))
	engine.emit(state, {
		"type": BattleEvents.HEALED,
		"unit_id": target.id,
		"by": source.id,
		"ability": id(),
		"amount": target.hp - before,
		"hp": target.hp,
	})
