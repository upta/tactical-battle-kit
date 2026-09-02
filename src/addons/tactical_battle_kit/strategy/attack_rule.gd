class_name AttackRule
extends ActionRule

## Default attack as a template: a unit strikes one enemy within its range,
## the defender strikes back if it can reach, the activation ends. Games
## subclass and override the pieces: can_target (line of sight, immunities),
## resolve (hit rolls, exchanges), counter_multiplier, after_attack (spend
## gunpowder, morale checks, break entrenchment).

var counterattacks: bool = true
var counter_multiplier: float = 0.5
var attack_ends_activation: bool = true


func id() -> String:
	return "attack"


func ends_activation() -> bool:
	return attack_ends_activation


func enumerate(state: BattleState, unit: BattleUnit) -> Array[BattleAction]:
	var actions: Array[BattleAction] = []
	for enemy: BattleUnit in state.enemies_on_field_of(unit.faction):
		if in_range(state, unit, enemy) and can_target(state, unit, enemy):
			actions.append(make_action(unit, {
				"target_unit_id": enemy.id,
				"target_cell": enemy.cell,
			}))
	return actions


func in_range(state: BattleState, attacker: BattleUnit, defender: BattleUnit) -> bool:
	var d := state.distance_between(attacker, defender)
	return d >= attacker.def.range_min and d <= attacker.def.range_max


## Extra targeting constraints beyond range. Default: none.
func can_target(_state: BattleState, _attacker: BattleUnit, _defender: BattleUnit) -> bool:
	return true


func can_counter(state: BattleState, defender: BattleUnit, attacker: BattleUnit) -> bool:
	return counterattacks and defender.is_on_field() and attacker.is_on_field() \
		and in_range(state, defender, attacker) and can_target(state, defender, attacker)


func apply(state: BattleState, engine: BattleEngine, action: BattleAction, rng: BattleRng) -> void:
	var attacker := state.unit(action.unit_id)
	var defender := state.unit(action.target_unit_id())
	resolve(state, engine, attacker, defender, rng, false)
	if can_counter(state, defender, attacker):
		resolve(state, engine, defender, attacker, rng, true)
	after_attack(state, engine, attacker, defender)


## One strike. Override for hit rolls, misses, or exchange mechanics.
func resolve(state: BattleState, engine: BattleEngine, attacker: BattleUnit, defender: BattleUnit, rng: BattleRng, counter: bool) -> void:
	var damage := engine.damage_model.compute(state, attacker, defender, rng)
	if counter:
		damage = roundi(float(damage) * counter_multiplier)
	damage = maxi(damage, 0)
	defender.hp -= damage
	engine.emit(state, {
		"type": BattleEvents.ATTACKED,
		"attacker_id": attacker.id,
		"defender_id": defender.id,
		"damage": damage,
		"counter": counter,
		"defender_hp": defender.hp,
	})
	if defender.hp <= 0:
		engine.kill(state, defender, attacker.id)


func after_attack(_state: BattleState, _engine: BattleEngine, _attacker: BattleUnit, _defender: BattleUnit) -> void:
	pass


func describe(_state: BattleState, action: BattleAction) -> String:
	return "%s attacks %s" % [action.unit_id, action.target_unit_id()]
