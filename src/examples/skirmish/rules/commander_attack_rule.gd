class_name CommanderAttackRule
extends AttackRule

## Full-strength counterattacks, and a unit that lands a hit turns to face
## its target so the next flank comes from somewhere else.


func _init() -> void:
	counter_multiplier = 1.0


func after_attack(state: BattleState, _engine: BattleEngine, attacker: BattleUnit, defender: BattleUnit) -> void:
	if state.ruleset.uses_facing() and attacker.is_on_field():
		attacker.facing = state.grid.topology.direction_to(attacker.cell, defender.cell)
