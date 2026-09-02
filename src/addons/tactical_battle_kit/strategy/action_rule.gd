@abstract
class_name ActionRule
extends RefCounted

## One kind of thing a unit can do. enumerate() lists the legal instances for
## a unit; apply() performs one, mutating the state and emitting events
## through the engine. The engine handles legality, slot bookkeeping and the
## outcome poll, so a rule only describes what the action does.


## Stable id; becomes BattleAction.kind.
@abstract func id() -> String


## Activation slot this action spends ("move", "action"); "" spends nothing.
## The engine skips enumerate() for a unit that has already spent the slot.
func slot() -> String:
	return "action"


## When true, every slot in the ruleset's activation_slots() is spent.
func ends_activation() -> bool:
	return false


## Slots spent by this particular application. Default: the rule's slot.
func spends(_state: BattleState, _unit: BattleUnit, _action: BattleAction) -> Array[String]:
	var result: Array[String] = []
	if slot() != "":
		result.append(slot())
	return result


## Cheap gate before enumeration (unit type, resource available, phase).
func can_use(_state: BattleState, _unit: BattleUnit) -> bool:
	return true


@abstract func enumerate(state: BattleState, unit: BattleUnit) -> Array[BattleAction]


## Perform the action. Emit events with engine.emit(); do not log directly.
@abstract func apply(state: BattleState, engine: BattleEngine, action: BattleAction, rng: BattleRng) -> void


func describe(_state: BattleState, action: BattleAction) -> String:
	return "%s %s" % [action.unit_id, action.kind]


func make_action(unit: BattleUnit, params: Dictionary = {}) -> BattleAction:
	return BattleAction.new(id(), unit.id, params)
