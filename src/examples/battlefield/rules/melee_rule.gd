class_name MeleeRule
extends AttackRule

## Adjacent strike. The defender retaliates at full strength once per round;
## the attack template's counter path does the strike, this rule only decides
## whether the stack still has its retaliation.


func _init() -> void:
	counterattacks = true
	counter_multiplier = 1.0
	attack_ends_activation = true


func id() -> String:
	return "melee"


func in_range(state: BattleState, attacker: BattleUnit, defender: BattleUnit) -> bool:
	return state.distance_between(attacker, defender) <= 1


func can_counter(state: BattleState, defender: BattleUnit, attacker: BattleUnit) -> bool:
	return super(state, defender, attacker) and not bool(defender.custom.get("retaliated", false))


func resolve(state: BattleState, engine: BattleEngine, attacker: BattleUnit, defender: BattleUnit, rng: BattleRng, counter: bool) -> void:
	if counter:
		attacker.custom["retaliated"] = true
	super(state, engine, attacker, defender, rng, counter)


func describe(state: BattleState, action: BattleAction) -> String:
	var attacker := state.unit(action.unit_id)
	var target := state.unit(action.target_unit_id())
	if attacker == null or target == null:
		return "%s attacks" % action.unit_id
	var expected: Dictionary = (state.ruleset as BattlefieldRuleset).expected_damage(state, attacker, target, false)
	return "Attack %s (%d-%d dmg)" % [target.def.display_name, int(expected["min"]), int(expected["max"])]
