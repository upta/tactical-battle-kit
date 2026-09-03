# Tactical Battle Kit

A GDScript rules engine for grid tactics games, with a headless balance
simulator that runs thousands of seeded battles and asserts on the results.
Fire Emblem, Koei, Langrisser, chess, hex wargames: the engine holds no game
logic, and every rule a game needs is a strategy it hands to the engine
through one `BattleRuleset` object.

This repository serves two purposes:

- package source for the reusable addon under `src/addons/tactical_battle_kit/`
- a runnable dev shell with three example games, their balance suites, and
  the in-engine validation scenarios that prove the view and runner

## What a game gets

- **A node-free core.** `BattleState`, `BattleEngine`, grid, units, actions
  and events are plain scripts. The simulator builds and discards thousands
  per second; the same state drives a scene through `BattleRunner`.
- **Strategies, not switches.** Actions (`ActionRule`), damage
  (`DamageModel`), movement cost, turn scheduling, victory, alliances,
  facing, footprints, layers and overlays are all methods on the ruleset with
  sane defaults. Chess and a hex musket war share the engine unchanged.
- **Determinism.** One seed replays one battle exactly, anywhere.
- **Balance suites.** JSON: a battle, N runs, matchups of AIs, an optional
  parameter sweep, assertions on win rates, rounds, event-derived metrics and
  the game's own numbers. Exit codes like a test runner. Runs in CI.
- **Playable.** `HumanController` hands any faction to a person: the viewer
  rings your units, highlights moves, targets and area anchors, and puts
  targetless actions in a button bar, all mapped generically off action
  params so every ruleset is playable with no per-game UI code.
- **In-engine proof.** The
  [agentic-godot-validation](https://github.com/upta/agentic-godot-validation)
  kit drives the debug view in a real engine and keeps screenshots.

## Quick start

```powershell
git clone --recurse-submodules https://github.com/upta/tactical-battle-kit.git
cd tactical-battle-kit
./setup.ps1            # materializes the validation kit symlinks, imports once
./simulate.ps1         # every balance suite, headless (~1 min)
./validate.ps1         # the scenario suite, windowed engine
godot --path src       # start menu: pick a battle, then play a side or watch AI vs AI
```

Requires Godot 4.7 (standard or mono), PowerShell 7 for the runners, git with
submodules. Linux and macOS: `./setup.sh`, then the runners under `pwsh`.

## Web playtests

Every push to any branch, main included, exports the Web build and uploads
it to Cloudflare R2 at `https://<bucket-public-url>/tactical-battle-kit/<branch>/index.html`
(D13). The Actions run summary prints the link. Deleting a branch prunes its
build. Two repository secrets are required and never copy between repos:
`CLOUDFLARE_API_TOKEN` (Workers R2 Storage: Edit) and `CLOUDFLARE_ACCOUNT_ID`;
the `R2_PUBLIC_BASE` variable makes the summary link clickable. Locally,
`powershell src/tools/export_web.ps1` then `powershell src/tools/serve_web.ps1`
(run-web skill).

## The examples

| Example | Shows |
| --- | --- |
| `examples/skirmish` | Square grid, faction turns, commander aura, troops dissolve when the commander falls, heal aura (an `AreaRule`), full-strength counters, facing, cavalry barred from forest, a sweep over a ruleset tunable |
| `examples/chess` | One action per turn, per-piece move enumeration, check and checkmate as the outcome, no hp and no damage model at all |
| `examples/breach` | XCOM-flavored, on a painted TileMapLayer map that is the source of truth: action points and dashes, directional cover from tile tags, hit rolls and misses, destructible cover, overwatch as a reaction fired from a hook, reinforcements spawning on flagged tiles, and its own presentation instead of the debug view |
| `examples/battlefield` | Heroes of Might and Magic style, on a painted half-offset-square map (Liberty or Death brick rows, hex adjacency): creature stacks whose count follows their hp pool, per-unit initiative with Wait, one retaliation a round, two-cell flyers that cross obstacles but cannot land on them, ranged shots with a distance penalty, a lich death cloud that hits friends too, Defend, and its own presentation with damage-and-kills hover readouts |
| `examples/frontier` | Hex grid, per-unit initiative scheduler, gunpowder, entrenching, routing and capture, army supply that starves the attacker, a sweep with a visible knee |

Each is a ruleset, a few rules, an AI, a battle file and a suite under
`src/sim/suites/`. The AIs are deliberately simple; the point is the seams.

## Using the kit in a game

Copy or submodule `src/addons/tactical_battle_kit/` into the project, write a
`BattleRuleset`, load battles with `BattleLoader`, drive them with
`BattleRunner` in a scene or `BattleSimulator` headless. The consumer-facing
skills under `.github/skills/` walk through it; `docs/` has the reference.

## Docs

- `docs/core-model.md`: state, engine, events, determinism
- `docs/write-a-ruleset.md`: every seam, with the mechanic table
- `docs/write-a-sim-suite.md`: suite schema, metrics, sweeps
- `docs/battle-file.md`: battle JSON reference
- `docs/install-into-a-game.md`: consuming the addon
- `docs/presentation.md`: what a game's own view implements (TileMapLayer maps included)
- `ARCHITECTURE.md`: where things live; `CLAUDE.md`: how work happens here
