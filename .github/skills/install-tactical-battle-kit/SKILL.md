---
name: install-tactical-battle-kit
description: "Use when: adding the tactical battle kit to a Godot project as a submodule or copy, writing the first ruleset and battle file, wiring a scene, and running the first headless suite."
---

# Install Tactical Battle Kit

## Goal

Get a consuming Godot 4.5+ GDScript project from nothing to a playable
battle and a passing balance suite without editing the addon. The finished result of these steps is
`example-game/` in the kit repository, whose suites run in the kit's CI from
that project on every push; copy its shape. The traps below are the ones a
fresh project hits.

## Steps

1. Add the kit and link the addon into the project:

```powershell
git submodule add https://github.com/upta/tactical-battle-kit.git submodules/tactical_battle_kit
mkdir addons
cmd /c "mklink /D addons\tactical_battle_kit ..\submodules\tactical_battle_kit\src\addons\tactical_battle_kit"
```

   (Linux/macOS: `ln -s ../submodules/tactical_battle_kit/src/addons/tactical_battle_kit addons/tactical_battle_kit`.
   A copy of the addon folder also works.) Add `/addons/tactical_battle_kit`,
   `.godot/` and `/artifacts/` to `.gitignore`, and create `artifacts/.gdignore`
   so Godot never scans sim reports.
2. Create `rules/<game>_ruleset.gd` extending `BattleRuleset` with
   `action_rules()` returning `[MoveRule.new(), AttackRule.new(), WaitRule.new()]`.
3. Create `battles/first.json` naming that script, a small ASCII map, an
   inline `unit_defs` block, two factions and a few units.
4. Create `sim/suites/first_smoke.json` pointing at the battle with
   `runs: 20`, a `random` vs `random` matchup, and assertions
   `metrics.events.rejected eq 0` and `draw_rate lte 0.5`.
5. **Import once, then run headless.** A fresh project has no class cache,
   so every kit `class_name` is undeclared until the first import; without
   it the sim CLI fails to parse with "Identifier SimSuite not declared":

```powershell
godot --headless --import --path .
godot --headless --path . --script res://addons/tactical_battle_kit/sim/sim_cli.gd -- --suites res://sim/suites
```

   Expect a `RESULT {... "status":"pass" ...}` line per suite, a `SUMMARY`
   line, and exit 0; that second command is the whole test runner and is
   what the project's CI runs. Re-import after adding scripts with
   `class_name` or new scenes. The kit's `simulate.ps1` imports on every run
   for exactly that reason; copy it and pass `-ProjectPath .`.
6. In a scene, add a `BattleView` (debug) and a `BattleRunner` node; load
   the battle with `BattleLoader.load_file`, call `runner.setup(state)`, set
   `view.state`, and `await runner.step()` on a key press. Boot it headless
   with `--quit-after` and a printed marker to prove it before opening the
   editor.
7. Copy `.github/skills/author-battle-ruleset`, `run-balance-sim`,
   `author-sim-suite` and `run-sim-suite` from the kit into the project's
   `.claude/skills/`. The last two are the loop: ask a balance question,
   get a suite, run it, get a page with the reading in it.

## Checks

- The project still owns its main scene and its presentation.
- The addon is not edited; a mechanic with no seam is a kit proposal.
- `sim_cli.gd` writes `artifacts/sim/<suite>/<stamp>/report.md`.
- Every AI the game names is registered through the ruleset's `ai_scripts()`.
