class_name BattleEvents
extends RefCounted

## Names of the events the kit emits into [member BattleState.events]. Every
## event is a Dictionary with "type" and "round"; the extra keys are listed
## beside each name. Games emit their own types freely; the simulator folds
## any event it recognizes and ignores the rest.

## {}
const BATTLE_STARTED := "battle_started"
## {winner, reason}
const BATTLE_ENDED := "battle_ended"
## {round}
const ROUND_STARTED := "round_started"
## {round}
const ROUND_ENDED := "round_ended"
## {faction, phase, unit_ids}
const TURN_STARTED := "turn_started"
## {faction, phase, action_count}
const TURN_ENDED := "turn_ended"
## {unit_id, from, to}  one per cell entered during a move
const STEPPED := "stepped"
## {unit_id, from, to, path, cost, interrupted}
const MOVED := "moved"
## {attacker_id, defender_id, damage, counter, defender_hp}
const ATTACKED := "attacked"
## {unit_id, ability, anchor, cells}
const ABILITY_USED := "ability_used"
## {unit_id, by, amount, hp}
const HEALED := "healed"
## {unit_id, killer_id}
const UNIT_DIED := "unit_died"
## {unit_id, status, by}
const LEFT_FIELD := "left_field"
## {unit_id, faction, cell}
const UNIT_SPAWNED := "unit_spawned"
## {unit_id}
const WAITED := "waited"
## {unit_id, action, reason}
const REJECTED := "rejected"


static func cell(c: Vector2i) -> Array:
	return [c.x, c.y]


static func cells(list: Array[Vector2i]) -> Array:
	var result: Array = []
	for c: Vector2i in list:
		result.append([c.x, c.y])
	return result
