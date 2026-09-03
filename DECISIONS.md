# Decisions

Contested calls the code cannot explain itself. A decision belongs here only
if the choice was genuinely contested AND the code cannot self-document it:
bold title, three lines maximum, optional *Why:*. Ids are frozen: never
renumber, never reuse. New decisions append to Active; superseded ones move to
Closed as one-line stubs.

## Active

**D1: Sim suites and validation scenarios are the test suite; there is no unit-test framework.**
Rules and balance are proved headless by seeded suites; the view and runner
by in-engine scenarios with screenshots. GUT/gdUnit4 were considered and
rejected as a second, weaker source of truth.

**D2: All GDScript, no C# core.**
A library piece has to drop into GDScript-only jam projects. If simulation
speed ever matters, the path is a GDExtension behind the same seams, not a
second language in the addon.

**D3: The engine holds no game logic; every rule is a strategy on one `BattleRuleset`.**
Actions, damage, movement cost, scheduling, outcome, alliances, hooks and
factories are methods with defaults. *Why:* seven genre games (Warsong,
chess, Gemfire, Liberty or Death, FFT, XCOM, D&D) were walked through the
design; each hardcoded switch in the engine broke at least one of them.

**D4: Decisions are made at faction-turn level, not per unit.**
`AiController.choose(state, engine, turn, rng)` over the union of legal
actions. *Why:* chess picks the piece as part of the move; per-unit prompting
cannot express that, faction-level prompting expresses both.

**D5: Runtime state is a `custom` dictionary; def state is a typed subclass.**
`unit.custom` / `state.custom` clone in one line and need no factories;
`UnitDef`/`TerrainDef` subclasses give typed, editor-visible, sweepable
fields. Metrics live on neither: they are folded from events.

**D6: Grid data is layers of flat arrays plus an overlay stack, not per-cell dictionaries.**
A layer for what every cell has (terrain, height); an overlay for what some
cells have (fence, fire, cover). *Why:* dense reads for the pathfinder,
one-array clone, and ASCII layers map straight onto it.

**D7: Continuous-space games are out of scope; a fine grid approximates them.**
`SquareTopology` offers euclidean distance for inch-grid play. Multi-cell
footprints are in (symmetric, non-rotating); float positions are not.

**D8: The validation kit is a submodule plus symlinks, not a vendored copy.**
Same as every sibling repo: `submodules/agentic_godot_validation`,
materialized by setup.ps1 / setup.sh.

**D9: Shipped AIs are examples; the addon ships only `RandomAi`.**
Random works against any ruleset (smoke driver, balance baseline). Every
game writes its own; the examples show three shapes.

**D10: `AiRegistry` holds scripts, never closures.**
A static dictionary of lambdas kept instances alive past engine shutdown and
crashed the process at exit (B-1). Registration is `{id: Script}`.

**D11: Simulation verdicts come from the `RESULT` line, not the process exit code.**
Godot mono builds can die during teardown after every artifact is written;
`simulate.ps1` trusts the printed verdict and falls back to the exit code
only when no verdict was printed.

**D12: No style gate; gdformat and gdlint are not run anywhere.**
The code is agent-written and the compile gate plus the two proof gates are
what matter. gdtoolkit drifted between releases, nothing local can run it,
and a check nobody can reproduce is noise.

**D13: Every branch, main included, deploys a web playtest build to Cloudflare R2.**
`playtest.yml` exports the Web preset on push and uploads under
`tactical-battle-kit/<branch>/`; deleting the branch prunes it. Same bucket and
mechanism as the jam games; main is included because there is no itch.io
release and the main build is the thing to show people.

**D14: A painted map is the source of truth; the kit reads TileMapLayers, never writes them.**
`TileMapGridSource` builds the grid from tile custom data, headless. A tool
script bootstrapped the first breach map from ASCII once; after that the
`.tscn` is edited in the editor and nothing regenerates it.

**D15: Reactions bypass the activation economy.**
`engine.apply_reaction` validates against the rule's own `enumerate` and
skips the turn-membership and slot checks; a reaction rule declares slot ""
and gates itself with `can_use` (overwatch stance). *Why:* the watcher has
already spent its turn, and a reaction that had to be "legal for the active
turn" could never fire.

## Closed

(none yet)
