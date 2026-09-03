class_name ReactionShotRule
extends ShootRule

## The overwatch shot. Not part of the activation economy: spends nothing,
## is only enumerated for a unit on overwatch, and the ruleset fires it
## through engine.apply_reaction when an enemy steps into sight. One shot
## per stance.


func id() -> String:
	return "overwatch_shot"


func slot() -> String:
	return ""


func ends_activation() -> bool:
	return false


func can_use(_state: BattleState, unit: BattleUnit) -> bool:
	return bool(unit.custom.get("overwatch", false))


func is_reaction() -> bool:
	return true


func after_attack(_state: BattleState, _engine: BattleEngine, attacker: BattleUnit, _defender: BattleUnit) -> void:
	attacker.custom.erase("overwatch")
