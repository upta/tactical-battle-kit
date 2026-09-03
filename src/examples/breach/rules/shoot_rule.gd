class_name ShootRule
extends AttackRule

## A shot: needs line of sight, rolls to hit against the target's cover and
## stance, ends the activation, never draws a counter. A hit on a target
## behind full cover may blow the cover away.


func _init() -> void:
	counterattacks = false
	attack_ends_activation = true


func id() -> String:
	return "shoot"


func can_target(state: BattleState, attacker: BattleUnit, defender: BattleUnit) -> bool:
	return (state.ruleset as BreachRuleset).has_line_of_sight(state, attacker.cell, defender.cell)


func resolve(state: BattleState, engine: BattleEngine, attacker: BattleUnit, defender: BattleUnit, rng: BattleRng, _counter: bool) -> void:
	var rules := state.ruleset as BreachRuleset
	var chance := rules.hit_chance(state, attacker, defender)
	var roll := rng.randi_range(1, 100)
	var hit := roll <= chance
	var damage := engine.damage_model.compute(state, attacker, defender, rng) if hit else 0
	defender.hp -= damage
	engine.emit(state, {
		"type": BattleEvents.ATTACKED,
		"attacker_id": attacker.id,
		"defender_id": defender.id,
		"damage": damage,
		"counter": false,
		"defender_hp": defender.hp,
		"hit": hit,
		"chance": chance,
		"reaction": is_reaction(),
	})
	if defender.hp <= 0:
		engine.kill(state, defender, attacker.id)
	_maybe_break_cover(state, engine, attacker, defender, rng, hit)


func is_reaction() -> bool:
	return false


func _maybe_break_cover(state: BattleState, engine: BattleEngine, attacker: BattleUnit, defender: BattleUnit, rng: BattleRng, hit: bool) -> void:
	var rules := state.ruleset as BreachRuleset
	if hit or rules.cover_toward(state, defender, attacker.cell) != "full":
		return
	if not rng.chance(float(rules.cover_break_chance) / 100.0):
		return
	var cell := rules.cover_cell_toward(state, defender, attacker.cell)
	if state.grid.remove_overlay(cell, "full_cover") > 0:
		engine.emit(state, {"type": "cover_destroyed", "cell": BattleEvents.cell(cell), "by": attacker.id})


func describe(state: BattleState, action: BattleAction) -> String:
	var shooter := state.unit(action.unit_id)
	var target := state.unit(action.target_unit_id())
	if shooter == null or target == null:
		return "%s shoots" % action.unit_id
	return "Shoot %s (%d%%)" % [target.def.display_name, (state.ruleset as BreachRuleset).hit_chance(state, shooter, target)]
