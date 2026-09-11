# Architecture

Where things live and what the words mean. This file does not restate what
code does; follow the paths. If it contradicts the code, the code wins and
this file has a bug: fix it or delete it.

## Codemap

| Path | What lives here |
| --- | --- |
| `src/addons/tactical_battle_kit/core/` | The node-free model. `battle_state.gd` (grid, units, factions, turn, custom, events; `clone()`), `battle_engine.gd` (the only mutator: legal actions, apply, loop primitives, kill/remove/spawn/interrupt), `battle_grid.gd` (named layers of flat arrays plus an overlay stack per cell), `grid_topology.gd` + `square_topology.gd` + `hex_topology.gd` (adjacency, distance, directions, offsets, lines, shapes), `area_pattern.gd`, `pathfinder.gd` (reachability through the ruleset's movement cost, footprint-aware), `battle_unit.gd`, `battle_action.gd`, `battle_turn.gd`, `battle_outcome.gd`, `battle_events.gd` (event names and shapes), `battle_rng.gd` (seeded, forkable), `unit_def.gd` / `terrain_def.gd` (resources) and `def_overrides.gd` (property-based patching). |
| `src/addons/tactical_battle_kit/strategy/` | What a game implements. `battle_ruleset.gd` is the bundle (actions, models, scheduler, outcome, hooks, factories, configure, summarize, ai_scripts). `action_rule.gd` (abstract), `move_rule.gd` (default, step-wise, interruptible), `attack_rule.gd` and `area_rule.gd` (templates), `wait_rule.gd`. `damage_model.gd` (abstract) and `linear_damage_model.gd`. `ai_controller.gd` (abstract), `random_ai.gd` (the only shipped AI), `ai_registry.gd` (scripts by id), `action_targets.gd` (click semantics from action params, shared by every presentation). |
| `src/addons/tactical_battle_kit/sim/` | Headless: `battle_simulator.gd` (one battle, folds metrics from events), `sim_suite.gd` (matchups × sweep × runs, aggregation, assertions), `sim_report.gd` (report.json, report.md, latest pointers, summaries, `render`), `sim_html.gd` (report.html and summary.html: self-contained pages with an embedded analysis.md), `sim_cli.gd` (the `--script` entry point: `--suite`, `--suites`, `--render`). |
| `src/addons/tactical_battle_kit/loaders/` | `battle_loader.gd`: battle JSON to BattleState through the ruleset's factories; every override root; `deep_merge`, `set_dotted_path`. |
| `src/addons/tactical_battle_kit/view/` | The only node layer. `battle_view.gd` is a debug renderer (shapes, hp bars, facing ticks; hex and square); `battle_runner.gd` steps a battle in a scene, awaiting `choose_async` for humans; `human_controller.gd` is that human: emits `decision_requested` with the legal actions and suspends until `submit()`; `tilemap_grid_source.gd` builds a grid from painted TileMapLayers (tile data only, headless-safe). |
| `src/app/` | The dev shell: `root.tscn` routes to the validation bootstrap under `--test-mode`, else to `battle_viewer.tscn`, and registers the InputMap actions; the viewer plays any battle file (`-- --battle`) with its declared AIs, from a start menu (pick a battle, play a faction or watch AI vs AI; `-- --human <faction>` or `-- --watch` skips it) with click mapping generic over action params, and prints the `[Kit] Battle ready:` marker. |
| `src/examples/skirmish/` | Warsong-flavored square skirmish: `skirmish_ruleset.gd`, `rules/` (aura damage model, commander attack rule, heal aura), `ai/greedy_ai.gd`, `data/` (.tres defs), `battles/open_field.json`. |
| `src/examples/chess/` | Chess: `chess_ruleset.gd` (one action per turn, checkmate outcome), `chess_move_rule.gd` (all movement, king safety by ray casting), `ai/capture_first_ai.gd`, `battles/standard.json` (inline defs). |
| `src/examples/breach/` | XCOM-flavored breach on a painted TileMap: `breach_ruleset.gd` (action points, cover from tile tags, overwatch reactions through `apply_reaction`, reinforcements through `spawn`), `rules/`, `ai/`, `map/` (generated tileset and TileMapLayer scene; `tools/build_map.gd` bootstrapped them once), `breach.tscn` + `breach_scene.gd` + `breach_overlay.gd` (its own presentation: TileMapLayers, highlight layer, overlay drawing). |
| `src/examples/battlefield/` | Heroes-style stacks on a painted half-offset-square map: `battlefield_ruleset.gd` (initiative scheduler with Wait, stacks, flyers via `movement_cost` + `can_stop_at`), `stack_def.gd` (subclassed def: creature hp, damage range, speed, shots, size, flying), `rules/` (melee with one retaliation, volley, death cloud AreaRule with friendly fire, defend, delay), `ai/`, `map/` (generated tileset and TileMapLayer scene), `battlefield.tscn` + scene and overlay scripts. |
| `src/examples/frontier/` | Hex musket war: `frontier_ruleset.gd` (per-unit initiative, supply, entrench clearing), `rules/` (musket attack with powder and routing, entrench, damage model), `ai/frontier_ai.gd`, `battles/river_crossing.json`. |
| `src/sim/suites/` | Balance suites, one claim each; `./simulate.ps1` runs them all. |
| `example-game/` | A second Godot project that consumes the addon the way a game does (symlinked `addons/`, its own `rules/`, `ai/`, `battles/`, `sim/suites/`). Both the CI fixture for the consumer path and the only demonstration of a consuming project's layout, so everything in it is what a real game would write (D17). |
| `src/validation/` | The scenario suite: `scenarios/*.json`, `harnesses/*.tscn`, `scripts/harness_controllers/`, `fixtures/*.json` (tiny battles). |
| `src/addons/agentic_godot_validation/` | Validation kit runtime, a symlink into the submodule. |
| `src/tools/` | Repo-owned checks: `check_scripts.ps1` (compile gate, engine half in `compile_check.gd`); `check_reports.gd` (the sim's HTML pages are well-formed and carry their sections; `simulate.ps1` and CI run it); `export_web.ps1` (Web export that proves its files, fetching a standard editor if godot is mono) and `serve_web.ps1` (local server with the right wasm mime). |
| `src/artifacts/` | Generated: `sim/<suite>/<stamp>/`, `<scenario>/<stamp>/`, `suites/`. Gitignored. |
| `docs/` | Reference for consumers: core model, ruleset seams, suite schema, battle file, install. |
| `.claude/` | Skills, commands, reviewer agents (code, test, balance), two Stop hooks (verification freshness, doc budgets). CLAUDE.md is the contract. |
| `.github/` | CI (compile, sim suites), `playtest.yml` (web export to R2 on every push, D13) and `playtest-cleanup.yml` (prune on branch delete), consumer-facing skills, Copilot pointer. |
| repo root | `simulate.ps1` and `validate.ps1` (the two gates), `setup.ps1`/`setup.sh` + `symlink-config.txt` (kit intake), `validation.config.psd1`, `tools/` → validation kit runners (symlink). |

## Seams

Every game-facing decision is a method on `BattleRuleset`; the engine calls
these and nothing else:

- **Actions.** `action_rules()` returns `ActionRule`s. The engine unions
  their `enumerate()` for legal actions and dispatches `apply()` by kind. A
  rule mutates state and calls `engine.emit()`; the engine spends slots
  (`spends()`, `ends_activation()`), records the action on the turn and polls
  the outcome.
- **Movement.** `movement_cost(state, unit, cell)` (-1 impassable),
  `can_stop_at` (pass over but never end there: flyers over obstacles),
  `can_pass_through`, `move_budget`, `single_move`. `Pathfinder` reads these;
  nothing reads `TerrainDef.move_cost` directly except the default.
- **Damage.** `damage_model()`; `AttackRule`/`AreaRule` call
  `engine.damage_model.compute(state, attacker, defender, rng)`.
- **Scheduling.** `begin_round`, `next_turn` (a `BattleTurn` or null),
  `is_turn_over`, `on_turn_ended`. Scheduler state lives in `state.custom`.
- **Outcome.** `check_outcome(state)` returns a `BattleOutcome` or null,
  polled after every apply, at turn end and at round end; `max_rounds()` is
  the engine's own draw. Hooks may call `engine.end_battle()`.
- **Alliances, facing, slots.** `are_enemies`, `uses_facing`,
  `activation_slots`, `unit_can_act`.
- **Hooks.** `on_battle_started`, `on_round_started`, `on_turn_started`,
  `on_turn_ended`, `on_event`; all receive the engine and may re-enter
  `apply`, `remove_from_field`, `interrupt_move`, `spawn`.
- **Factories and data.** `make_unit_def`, `make_terrain_def`, `make_unit`;
  `configure(params)` for sweeps; `summarize(state)` for the report;
  `ai_scripts()` for named AIs. `BattleLoader` is the only caller of the
  factories.
- **Runtime state.** Kit fields on `BattleUnit`/`BattleState` are what the
  engine needs; everything else is `custom`. Def fields are typed subclasses.
- **Events.** `state.events` is the source of truth. Metrics are folded from
  it (`BattleSimulator.fold_metrics`); the view, runner and report never
  diff state.
- **Occupancy.** Every occupancy question goes through `state.occupied_cells`
  / `unit_at(cell, layer)` / `units_at`, so footprints and layers are one
  place.
- **Decisions.** `AiController.choose(state, engine, turn, rng)` at faction
  level; `BattleRunner` awaits `choose_async` when a controller has it, and
  `HumanController` is the shipped one: a UI listens to `decision_requested`
  and calls `submit()`. Click semantics come from `ActionTargets`.
- **Reactions.** A hook may fire an action by a unit outside the turn with
  `engine.apply_reaction`, validated against that rule's own enumerate;
  `engine.rng` is the stream hooks roll from. `interrupt_move` stops a move
  mid-path.
- **Presentation.** Five things a view implements (docs/presentation.md):
  cell mapping, the map, units from state, effects from events, a human
  deciding through `HumanController` and `ActionTargets`.

## Golden path

The skirmish example is the exemplar vertical; pattern-match it:

1. Rules: `skirmish_ruleset.gd` overrides `movement_cost`, `check_outcome`,
   `on_event`, `configure`, `summarize`, `ai_scripts`
2. Strategies: `rules/aura_damage_model.gd` extends the linear model,
   `rules/commander_attack_rule.gd` overrides one template step,
   `rules/heal_aura_rule.gd` implements `affect`
3. Data: `data/unit_defs/*.tres`, `data/terrain/*.tres`,
   `battles/open_field.json` naming them
4. Decision: `ai/greedy_ai.gd` scores `engine.legal_actions`
5. Proof: `src/sim/suites/skirmish_*.json` (rules, balance) and
   `src/validation/scenarios/*.json` driving `battle_view_harness.tscn`
   (the view and runner, with screenshots)

## Vocabulary

| Noun | Meaning |
| --- | --- |
| ruleset | The game's strategy bundle; one instance per loaded battle, shared by every clone of its state. |
| rule | An `ActionRule`: one kind of thing a unit can do. |
| turn | A `BattleTurn`: one faction deciding for some units, optionally in a phase. Produced by the scheduler. |
| activation / slot | A unit's opportunity within a turn; slots (`move`, `action`) are what rules spend. |
| event | A dictionary in `state.events`; what happened. Kit names in `BattleEvents`, game names free-form. |
| outcome | `BattleOutcome`: winner (or "" for a draw) and reason. |
| on field / alive | `status == "active"` / `status != "dead"`. Routed, captured, dormant are alive and off the field. |
| footprint / layer | Cells a unit covers from its anchor; the occupancy plane it sits on. |
| overlay / layer (grid) | A TerrainDef stacked on some cells; a per-cell array every cell has a value in. |
| suite / matchup / sweep / cell | A balance run; an AI assignment; a parameter axis; one (matchup, sweep value) aggregate. |
| harness / scenario / artifact | Validation nouns: a minimal scene, the JSON contract that drives it, the evidence a run writes. |

## Known shape problems

Named so nobody copies them as patterns:

- `BattleState.unit_at` scans every unit per call. Fine at example scale;
  the pathfinder precomputes a blocker map instead of calling it, and any
  future occupancy index goes behind the same three methods.
- `BattleEngine` caches legal actions by `(state instance, event count)`.
  A rule whose `apply` mutates nothing observable and emits nothing would
  leave the cache stale; every shipped rule emits.
- `ChessMoveRule.leaves_king_safe` moves a piece and restores it inside
  `enumerate`. Contained, but not a pattern: prefer `state.clone()` for
  lookahead anywhere the cost is acceptable.
- `BattleLoader` instantiates and frees a PackedScene when a battle names a
  `map_scene`, which is the one place below `view/` that touches nodes. It
  reads tile data only and never enters the tree; keep it that way.
