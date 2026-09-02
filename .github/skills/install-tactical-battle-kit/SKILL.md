---
name: install-tactical-battle-kit
description: "Use when: adding the tactical battle kit to a Godot project as a submodule or copy, writing the first ruleset and battle file, wiring a scene, and running the first headless suite."
---

# Install Tactical Battle Kit

## Goal

Get a consuming Godot 4.5+ GDScript project from nothing to a playable
battle and a passing balance suite without editing the addon.

## Steps

1. Add the kit: `git submodule add https://github.com/upta/tactical-battle-kit.git submodules/tactical_battle_kit`,
   then link `addons/tactical_battle_kit` to
   `submodules/tactical_battle_kit/src/addons/tactical_battle_kit`
   (a copy of the addon folder also works).
2. Create `rules/<game>_ruleset.gd` extending `BattleRuleset` with
   `action_rules()` returning `[MoveRule.new(), AttackRule.new(), WaitRule.new()]`.
3. Create `battles/first.json` naming that script, a small ASCII map, an
   inline `unit_defs` block, two factions and a few units.
4. Create `sim/suites/first_smoke.json` pointing at the battle with
   `runs: 20`, a `random` vs `random` matchup, and assertions
   `metrics.events.rejected eq 0` and `draw_rate lte 0.5`.
5. Run it headless: `godot --headless --path . --script res://addons/tactical_battle_kit/sim/sim_cli.gd -- --suite res://sim/suites/first_smoke.json`.
   Expect `RESULT {... "status":"pass" ...}` and exit 0.
6. In a scene, add a `BattleView` (debug) and a `BattleRunner` node; load
   the battle with `BattleLoader.load_file`, call `runner.setup(state)`, set
   `view.state`, and `await runner.step()` on a key press.
7. Copy `.github/skills/author-battle-ruleset` and
   `.github/skills/run-balance-sim` from the kit into the project's
   `.claude/skills/`.

## Checks

- The project still owns its main scene and its presentation.
- The addon is not edited; a mechanic with no seam is a kit proposal.
- `sim_cli.gd` writes `artifacts/sim/<suite>/<stamp>/report.md`.
- Every AI the game names is registered through the ruleset's `ai_scripts()`.
