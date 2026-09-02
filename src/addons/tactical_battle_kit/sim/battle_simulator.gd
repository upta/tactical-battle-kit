class_name BattleSimulator
extends RefCounted

## Runs one battle to completion, synchronously, with an AI per faction.
## The loop is the engine's primitives in the canonical order; BattleRunner
## (the node) walks the same sequence with awaits for human players.
## The result carries kit metrics folded from the event log and the
## ruleset's own summary, kept in separate dictionaries.

## Keep the full event log in the result.
var trace: bool = false


func run(state: BattleState, ais: Dictionary[String, AiController], rng: BattleRng) -> Dictionary:
	var engine := BattleEngine.new(state.ruleset)
	var engine_rng := rng.fork("engine")
	var ai_rngs: Dictionary[String, BattleRng] = {}
	for faction: String in state.factions:
		ai_rngs[faction] = rng.fork("ai:" + faction)

	var decisions := 0
	engine.start_battle(state)
	while not state.ended:
		engine.begin_round(state)
		while not state.ended:
			var turn := engine.next_turn(state)
			if turn == null:
				break
			while not engine.is_turn_over(state, turn):
				var ai: AiController = ais.get(turn.faction)
				if ai == null:
					push_error("No AI for faction '%s'." % turn.faction)
					engine.end_battle(state, "", "missing_ai")
					break
				var action := ai.choose(state, engine, turn, ai_rngs[turn.faction])
				if action == null:
					break
				engine.apply(state, action, engine_rng)
				decisions += 1
			engine.end_turn(state, turn)
		engine.end_round(state)
	return result(state, decisions)


func result(state: BattleState, decisions: int) -> Dictionary:
	var outcome := state.outcome if state.outcome != null else BattleOutcome.draw("unfinished")
	var data := {
		"battle_id": state.battle_id,
		"winner": outcome.winner,
		"reason": outcome.reason,
		"rounds": state.round_number,
		"decisions": decisions,
		"metrics": fold_metrics(state),
		"custom": _numeric_only(state.ruleset.summarize(state)),
	}
	if trace:
		data["events"] = state.events.duplicate()
		data["final_state"] = state.to_dict()
	return data


## Kit metrics derived from the event log. Shape:
##   faction.<id>: damage_dealt, damage_taken, kills, deaths, healed,
##                 survivors, hp_share, first_blood, left_field.<status>
##   def.<id>:     damage_dealt, damage_taken, kills, deaths
##   events.<type>: count
static func fold_metrics(state: BattleState) -> Dictionary:
	var faction_stats := {}
	var def_stats := {}
	var event_counts := {}
	for faction: String in state.factions:
		faction_stats[faction] = {
			"damage_dealt": 0, "damage_taken": 0, "kills": 0, "deaths": 0,
			"healed": 0, "survivors": 0, "hp_share": 0.0, "first_blood": 0,
			"left_field": {},
		}
	for unit: BattleUnit in state.units.values():
		if not def_stats.has(unit.def.id):
			def_stats[unit.def.id] = {"damage_dealt": 0, "damage_taken": 0, "kills": 0, "deaths": 0}

	var first_blood_taken := false
	for event: Dictionary in state.events:
		var type := str(event.get("type", ""))
		event_counts[type] = int(event_counts.get(type, 0)) + 1
		match type:
			BattleEvents.ATTACKED:
				var attacker := state.unit(str(event.get("attacker_id")))
				var defender := state.unit(str(event.get("defender_id")))
				var damage := int(event.get("damage", 0))
				if attacker != null:
					_bump(faction_stats, attacker.faction, "damage_dealt", damage)
					_bump(def_stats, attacker.def.id, "damage_dealt", damage)
					if damage > 0 and not first_blood_taken:
						first_blood_taken = true
						_bump(faction_stats, attacker.faction, "first_blood", 1)
				if defender != null:
					_bump(faction_stats, defender.faction, "damage_taken", damage)
					_bump(def_stats, defender.def.id, "damage_taken", damage)
			BattleEvents.HEALED:
				var healed := state.unit(str(event.get("unit_id")))
				if healed != null:
					_bump(faction_stats, healed.faction, "healed", int(event.get("amount", 0)))
			BattleEvents.UNIT_DIED:
				var dead := state.unit(str(event.get("unit_id")))
				var killer := state.unit(str(event.get("killer_id")))
				if dead != null:
					_bump(faction_stats, dead.faction, "deaths", 1)
					_bump(def_stats, dead.def.id, "deaths", 1)
				if killer != null:
					_bump(faction_stats, killer.faction, "kills", 1)
					_bump(def_stats, killer.def.id, "kills", 1)
			BattleEvents.LEFT_FIELD:
				var gone := state.unit(str(event.get("unit_id")))
				if gone != null and faction_stats.has(gone.faction):
					var left: Dictionary = faction_stats[gone.faction]["left_field"]
					var status := str(event.get("status"))
					left[status] = int(left.get(status, 0)) + 1

	for faction: String in state.factions:
		faction_stats[faction]["survivors"] = state.units_on_field_of(faction).size()
		faction_stats[faction]["hp_share"] = state.hp_share(faction)

	return {"faction": faction_stats, "def": def_stats, "events": event_counts}


static func _bump(table: Dictionary, key: String, field: String, amount: int) -> void:
	if not table.has(key):
		return
	var row: Dictionary = table[key]
	row[field] = int(row.get(field, 0)) + amount


static func _numeric_only(value: Variant) -> Variant:
	if value is Dictionary:
		var result := {}
		for key: Variant in value.keys():
			var inner: Variant = _numeric_only(value[key])
			if inner != null:
				result[str(key)] = inner
		return result
	if value is int or value is float or value is bool:
		return float(value)
	return null
