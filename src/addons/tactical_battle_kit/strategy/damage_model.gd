@abstract
class_name DamageModel
extends RefCounted

## How much one strike hurts. Receives the whole state so it can read terrain
## stacks, facing, custom counters (gunpowder, supply), auras, anything.
## Returns hit points removed; 0 is a miss. The rule that calls it decides
## what to do with the number.


@abstract func compute(state: BattleState, attacker: BattleUnit, defender: BattleUnit, rng: BattleRng) -> int
