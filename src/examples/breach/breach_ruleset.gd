class_name BreachRuleset
extends BattleRuleset

## XCOM-flavored breach on a painted TileMap: two action points, dashes,
## directional cover read from cover tiles, hit rolls with misses,
## destructible full cover, overwatch as a reaction fired from a hook with
## engine.apply_reaction, hunkering, and alien reinforcements spawning on
## tiles the map flags. Exercises the seams no other example touches.

const SPAWN_LAYER := "spawn"

var base_hit: int = 0
var half_cover_penalty: int = 20
var full_cover_penalty: int = 40
var hunker_penalty: int = 30
var flank_crit_chance: int = 35
var cover_break_chance: int = 25
var reinforcement_round: int = 3
var reinforcement_count: int = 2


func id() -> String:
	return "breach"


func action_rules() -> Array[ActionRule]:
	return [BreachMoveRule.new(), ShootRule.new(), OverwatchRule.new(), HunkerRule.new(), ReactionShotRule.new(), WaitRule.new()]


func damage_model() -> DamageModel:
	return BreachDamageModel.new(self)


func single_move() -> bool:
	return false


func activation_slots() -> Array[String]:
	return ["ap1", "ap2"]


## Each unspent action point buys one move's worth of cells; two make a dash.
func move_budget(state: BattleState, unit: BattleUnit) -> int:
	return unit.def.move * unspent_points(unit)


func max_rounds() -> int:
	return 15


func make_unit_def(data: Dictionary) -> UnitDef:
	var def := BreachUnitDef.new()
	def.apply_overrides(data)
	if not data.has("display_name"):
		def.display_name = def.id.capitalize()
	return def


# --- Hooks ---


## A faction's overwatch and hunker stances end when its turn comes around.
func on_turn_started(state: BattleState, _engine: BattleEngine, turn: BattleTurn) -> void:
	for unit: BattleUnit in state.units_on_field_of(turn.faction):
		unit.custom.erase("overwatch")
		unit.custom.erase("hunker")


func on_round_started(state: BattleState, engine: BattleEngine) -> void:
	if state.round_number != reinforcement_round:
		return
	var spawned := 0
	for cell: Vector2i in state.grid.all_cells():
		if spawned >= reinforcement_count:
			break
		if not bool(state.grid.get_layer_value(SPAWN_LAYER, cell, false)):
			continue
		if state.unit_at(cell) != null:
			continue
		var def := _def_named(state, "sectoid")
		if def == null:
			return
		spawned += 1
		var unit := make_unit("reinforcement_%d" % spawned, def, "aliens", cell, {})
		engine.spawn(state, unit)


## Moving drops a stance; stepping into a watcher's sights draws its fire.
func on_event(state: BattleState, engine: BattleEngine, event: Dictionary) -> void:
	match str(event.get("type", "")):
		BattleEvents.MOVED:
			var mover := state.unit(str(event.get("unit_id")))
			if mover != null:
				mover.custom.erase("overwatch")
				mover.custom.erase("hunker")
		BattleEvents.STEPPED:
			var mover := state.unit(str(event.get("unit_id")))
			if mover == null or not mover.is_on_field():
				return
			var rule := engine.rule("overwatch_shot") as AttackRule
			for watcher: BattleUnit in state.enemies_on_field_of(mover.faction):
				if not bool(watcher.custom.get("overwatch", false)):
					continue
				# Only fire when the shot is actually legal; a rejected reaction
				# is noise in the log and the report.
				if not rule.in_range(state, watcher, mover) or not rule.can_target(state, watcher, mover):
					continue
				var shot := BattleAction.new("overwatch_shot", watcher.id, {"target_unit_id": mover.id, "target_cell": mover.cell})
				var produced := engine.apply_reaction(state, shot)
				var fired := false
				for e: Dictionary in produced:
					if str(e.get("type")) == BattleEvents.ATTACKED:
						fired = true
				if fired:
					engine.interrupt_move(mover.id)
				if not mover.is_on_field():
					return


func configure(params: Dictionary) -> void:
	base_hit = int(params.get("base_hit", base_hit))
	half_cover_penalty = int(params.get("half_cover_penalty", half_cover_penalty))
	full_cover_penalty = int(params.get("full_cover_penalty", full_cover_penalty))
	hunker_penalty = int(params.get("hunker_penalty", hunker_penalty))
	flank_crit_chance = int(params.get("flank_crit_chance", flank_crit_chance))
	cover_break_chance = int(params.get("cover_break_chance", cover_break_chance))
	reinforcement_round = int(params.get("reinforcement_round", reinforcement_round))
	reinforcement_count = int(params.get("reinforcement_count", reinforcement_count))


func summarize(state: BattleState) -> Dictionary:
	var shots := 0
	var hits := 0
	var reaction_shots := 0
	var cover_broken := 0
	for event: Dictionary in state.events:
		match str(event.get("type", "")):
			BattleEvents.ATTACKED:
				shots += 1
				if int(event.get("damage", 0)) > 0:
					hits += 1
				if bool(event.get("reaction", false)):
					reaction_shots += 1
			"cover_destroyed":
				cover_broken += 1
	return {
		"shots": shots,
		"hit_rate": float(hits) / float(maxi(shots, 1)),
		"reaction_shots": reaction_shots,
		"cover_broken": cover_broken,
	}


func ai_scripts() -> Dictionary[String, GDScript]:
	return {"breach": BreachAi}


# --- Helpers the rules and AI share ---


func unspent_points(unit: BattleUnit) -> int:
	var count := 0
	for slot: String in activation_slots():
		if not unit.has_spent(slot):
			count += 1
	return count


## "full", "half" or "none": the cover on the defender's neighbor toward
## the shooter. Hunkering counts as one step better.
func cover_toward(state: BattleState, defender: BattleUnit, from: Vector2i) -> String:
	var topology := state.grid.topology
	var direction := topology.direction_to(defender.cell, from)
	if direction < 0:
		return "none"
	var neighbor := topology.offset_cell(defender.cell, topology.direction_offset(direction))
	if state.grid.has_tag_at(neighbor, "full_cover"):
		return "full"
	if state.grid.has_tag_at(neighbor, "half_cover"):
		return "half"
	return "none"


func cover_cell_toward(state: BattleState, defender: BattleUnit, from: Vector2i) -> Vector2i:
	var topology := state.grid.topology
	var direction := topology.direction_to(defender.cell, from)
	return topology.offset_cell(defender.cell, topology.direction_offset(direction)) if direction >= 0 else Vector2i(-1, -1)


func hit_chance(state: BattleState, shooter: BattleUnit, target: BattleUnit) -> int:
	var aim: int = (shooter.def as BreachUnitDef).aim if shooter.def is BreachUnitDef else 60
	var chance: int = base_hit + aim
	match cover_toward(state, target, shooter.cell):
		"full":
			chance -= full_cover_penalty
		"half":
			chance -= half_cover_penalty
	if bool(target.custom.get("hunker", false)):
		chance -= hunker_penalty
	return clampi(chance, 5, 95)


func has_line_of_sight(state: BattleState, from: Vector2i, to: Vector2i) -> bool:
	var line := state.grid.topology.line(from, to)
	for i: int in range(1, line.size() - 1):
		if state.grid.has_tag_at(line[i], "blocks_los"):
			return false
	return true


func _def_named(state: BattleState, def_id: String) -> UnitDef:
	for unit: BattleUnit in state.units.values():
		if unit.def.id == def_id:
			return unit.def
	return null
