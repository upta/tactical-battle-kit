---
name: author-battle-ruleset
description: Use when implementing a game on the kit, adding an example, or asking "where does this mechanic go". The seam catalog, the decision table from mechanic to seam, the minimum files for a new example, and the traps.
---

# Author a ruleset

A game is one `BattleRuleset` subclass plus the strategies it hands out.
Nothing in `addons/tactical_battle_kit/` is edited to make a game work; if
a mechanic has no seam, that is a kit change with a proposal (CLAUDE.md § No
silent architecture), not a workaround.

## Mechanic → seam

| Mechanic | Seam |
| --- | --- |
| A thing a unit can do (move, attack, cast, entrench, build, capture) | `ActionRule` subclass; list it in `action_rules()` |
| Attack variants (hit rolls, counters, gunpowder, morale) | Subclass `AttackRule`; override `can_target`, `resolve`, `after_attack`, `counter_multiplier` |
| Area heal, spell, breath, artillery | Subclass `AreaRule`; set `cast_range`, `affects`, `pattern()`; implement `affect` |
| Damage math (auras, facing, cover, supply, height) | `DamageModel` subclass returned by `damage_model()` |
| Who can enter what terrain (cavalry vs forest, flyers, bridges) | `movement_cost(state, unit, cell)`; -1 is impassable |
| Move-then-act vs split movement vs action points | `single_move()`, `move_budget()`, `activation_slots()`, `unit_can_act()` |
| Turn order (faction turns, one action, per-unit initiative, CT clock, phases) | `begin_round()`, `next_turn()`, `is_turn_over()`, `on_turn_ended()` |
| Victory, objectives, timeouts | `check_outcome()` (polled after every action) or `engine.end_battle()` from a hook |
| Allies, guests, neutrals | `are_enemies(a, b)` |
| Facing and flank damage | `uses_facing()` true; read `unit.facing` and `topology.arc` in the damage model |
| Routing, capture, dormant, revive | `engine.remove_from_field(state, unit, status)`; `unit.status`; `engine.spawn()` |
| Fences, fire, cover, fog | Grid overlays (`add_overlay`/`remove_overlay` with tags); on a painted map, an overlay TileMapLayer |
| Reactions (overwatch, opportunity attacks) | `on_event` hook calling `engine.apply_reaction` and `engine.interrupt_move`; the reaction is its own ActionRule with slot "" |
| A painted map | `map_scene` in the battle file; `terrain` custom data on tiles; see docs/presentation.md |
| Height, regions, deployment zones | Grid layers; `cell_layers` in the battle file |
| Per-unit runtime numbers (mp, powder, entrenched, CT) | `unit.custom` |
| Per-battle runtime numbers (supply, decks, weather, phase) | `state.custom` |
| New stat on a def (jump, leadership, class) | Subclass `UnitDef`/`TerrainDef`; return it from `make_unit_def`/`make_terrain_def` |
| Tunables a sweep should reach | Plain vars on the ruleset, read in `configure(params)` |
| Numbers for the balance report | `summarize(state)`; numeric leaves only |
| An AI by name | `ai_scripts()` returning `{id: Script}` |
| Big units | `UnitDef.footprint` offsets (symmetric, no rotation); the battlefield example's two-cell creatures |
| Pass over but never stop (flyers over obstacles) | `can_stop_at(state, unit, cell)` on the ruleset |

Randomness always comes from the `BattleRng` passed in. Never `randi()`.

## Seam signatures (so nobody has to open the addon)

```gdscript
# BattleRuleset
func ai_scripts() -> Dictionary[String, GDScript]        # {"greedy": GreedyAi}, scripts not instances
func configure(params: Dictionary) -> void               # receives "ruleset.<key>" overrides and sweeps
func summarize(state: BattleState) -> Dictionary         # numeric leaves only, averaged per matchup
func movement_cost(state: BattleState, unit: BattleUnit, cell: Vector2i) -> int   # -1 impassable
func check_outcome(state: BattleState) -> BattleOutcome  # null keeps playing; BattleOutcome.new(winner, reason)
func on_event(state: BattleState, engine: BattleEngine, event: Dictionary) -> void

# ActionRule
func id() -> String
func slot() -> String                    # "action" default, "move", or "" to spend nothing
func ends_activation() -> bool           # true spends EVERY slot in activation_slots(): no move afterwards
func can_use(state: BattleState, unit: BattleUnit) -> bool
func enumerate(state: BattleState, unit: BattleUnit) -> Array[BattleAction]   # make_action(unit, params)
func apply(state: BattleState, engine: BattleEngine, action: BattleAction, rng: BattleRng) -> void

# AttackRule template (extends ActionRule): override any of
func can_target(state, attacker, defender) -> bool
func resolve(state, engine, attacker, defender, rng, counter: bool) -> void
func after_attack(state, engine, attacker, defender) -> void
var counterattacks := true; var counter_multiplier := 0.5; var attack_ends_activation := true

# AreaRule template (extends ActionRule)
var cast_range := 0                      # 0: the caster's own cell is the only anchor
var affects := AreaRule.AFFECTS_ENEMIES  # or AFFECTS_ALLIES, AFFECTS_ALL
func pattern() -> AreaPattern            # AreaPattern.radius(n), ring(n), line(n), from_offsets([...])
func anchors(state, unit) -> Array[Vector2i]
func affect(state, engine, caster, target, rng) -> void       # once per covered unit; heal() and deal_damage() helpers
func after_apply(state, engine, caster, action) -> void
# The caster IS a target when the pattern covers its cell and affects allies.
# Emits ability_used {unit_id, ability, anchor, cells} then whatever affect() emits.

# AiController
func choose(state: BattleState, engine: BattleEngine, turn: BattleTurn, rng: BattleRng) -> BattleAction

# Handy state queries
state.distance_between(a: BattleUnit, b: BattleUnit) -> int
state.units_on_field_of(faction) / enemies_on_field_of(faction) -> Array[BattleUnit]
state.grid.distance(a: Vector2i, b: Vector2i) -> int
```

Kit event keys the report folds: `attacked {attacker_id, defender_id,
damage, counter}`, `healed {unit_id, by, amount}` (summed into
`metrics.faction.<f>.healed` by the healed unit's faction), `unit_died
{unit_id, killer_id}`, `left_field {unit_id, status, by}`. Every other type
is only counted under `metrics.events.<type>`.

An `enumerate` that returns nothing when the action would do nothing (no
hurt ally in range) is the intended pattern: it keeps RandomAi honest and
the legal list small.

## Minimum files for a new example

```
src/examples/<game>/<game>_ruleset.gd        the BattleRuleset
src/examples/<game>/rules/*.gd               ActionRule / DamageModel subclasses
src/examples/<game>/ai/<game>_ai.gd          at least one AiController (RandomAi is free)
src/examples/<game>/battles/<name>.json      a battle file (inline unit_defs are fine)
src/sim/suites/<game>_<claim>.json           one suite that proves a claim about the rules
```

Add the battle to `BATTLES` in `src/app/battle_viewer.gd` so N cycles to
it, and a codemap row to ARCHITECTURE.md. Exemplars: `examples/skirmish`
(hooks, aura, area rule, dissolve), `examples/chess` (one-action turns, no
hp, custom outcome), `examples/frontier` (hex, per-unit scheduler, powder,
entrench, rout and capture, supply).

## Traps

- **A rule mutates and emits, never logs.** `engine.emit(state, event)`
  runs hooks; `state.log_event` bypasses them. Rules only call emit.
- **`enumerate` must be pure.** The engine caches legal actions by event
  count; an enumerate that mutates state is invisible to the cache. Chess
  tests king safety by moving and restoring inside one call, which is fine
  because nothing observes the middle.
- **Slots are spent by the engine after `apply`.** A rule that needs to spend
  something else overrides `spends()`; it does not touch `unit.spent`.
- **`check_outcome` runs after every apply**, including mid-turn. A commander
  killed by the third unit to act ends the battle before the fourth acts.
- **Scheduler state lives in `state.custom`**, never on the ruleset: the
  ruleset instance is shared by every clone of the state.
- **`ai_scripts()` returns scripts, not lambdas.** Statics holding closures
  crash the engine at exit.
- **Typed everything.** `Array[BattleUnit]`, `Dictionary[String, int]`,
  parameter and return types on every function. `Variant` only where a
  value is really open.
