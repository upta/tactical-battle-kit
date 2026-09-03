---
name: validate-gameplay
description: Use for ANY change to kit, example or viewer code, or to reproduce a bug before fixing it. The red→green→gate→look loop, which of the two proof artifacts a change needs, the harness rules, and the screenshot rubric.
---

# Validate gameplay

Two proof artifacts, both under `src/`, both gates in the Definition of Done:

| Claim is about | Proof | Gate | Runs in CI |
| --- | --- | --- | --- |
| Rules, scheduling, AI, determinism, balance, loader, sweeps | Sim suite: `src/sim/suites/<name>.json` | `./simulate.ps1` | yes |
| The view, the runner, input bridging, anything a screenshot can catch | Scenario: `src/validation/scenarios/<name>.json` + harness | `./validate.ps1` | no |

Schema references: the run-balance-sim skill for suites, the kit's
author-validation-scenario skill for scenarios. Reading failures:
`report.md` for suites, the debug-validation-failure skill for scenarios.

## The loop

1. **Red:** before (or alongside) implementing, write the suite or scenario
   asserting the new behavior. Run it; it must FAIL, proving it tests
   something real. For a suite that means an assertion on a metric that
   moves, not `rejected eq 0`.
2. **Green:** implement until it passes.
3. **Gate:** `./simulate.ps1` and, if anything under `src/app`, `src/addons/
   tactical_battle_kit/view` or `src/validation` changed, `./validate.ps1`.
   No regressions. Flakiness check when timing changed:
   `./validate.ps1 -RepeatCount 3`.
4. **Look:** for scenarios, read the checkpoint screenshots (Read tool on the
   PNGs). For suites, read `report.md` and say what the table shows; a green
   status with a table you did not read is a skipped review.

Single runs during iteration:

```powershell
./simulate.ps1 -Suite <suite_id> [-Runs 20] [-Seed 7] [-Trace]
pwsh tools/run_scenario.ps1 -Scenario validation/scenarios/<name>.json -ProjectPath src
```

Suite artifacts: `src/artifacts/sim/<suite_id>/<timestamp>/report.json`,
`report.md`, and `trace.json` with `-Trace`. Scenario artifacts:
`src/artifacts/<scenario_id>/<timestamp>/` with `summary.json`
(`failed_assertion` names the step, observed value and related screenshots),
`event_log.json`, `scene_tree.json`, `console.log`, `screenshots/*.png`.

## Screenshot review rubric

Every numeric assertion in a scenario can pass against a scene that renders
nothing. Answer these six, with specifics:

1. Is anything there at all?
2. Is the asserted subject actually in frame?
3. Do textures resolve (no blanks, no placeholder magenta)?
4. Did the frame change between checkpoints? Say WHICH pixels differ.
5. Does the picture agree with the number (hp bar length vs hp)?
6. Is anything stacked, clipped, or occluding?

## Harness rules

Harnesses live in `src/validation/harnesses/` with controllers in
`src/validation/scripts/harness_controllers/`, fixtures (small battle JSON)
in `src/validation/fixtures/`. A controller exposes `get_observed_state()
-> Dictionary` (semantic facts: hp, cells, status, view facts) and
`reset_harness()`, loads its fixture through `BattleLoader`, and drives a
`BattleRunner`.

- **The runtime presses InputMap actions and re-asserts a held action every
  physics frame.** Bridge with rising-edge detection on
  `Input.is_action_pressed` in `_physics_process`; `is_action_just_pressed`
  fires every frame the action is held and stepped a battle twice.
  Exemplar: `battle_view_harness_controller.gd`.
- Actions come from `src/app/root.gd` (`sim_step`, `sim_play`,
  `sim_restart`, `sim_next_battle`); add there, never in a harness.
- **`wait_frames` is physics frames; there is no wait_seconds.** Anything
  async (`await runner.step()`) uses `wait_until` polling instead.
- A flaky scenario is a design smell: make it deterministic (pin the seed in
  the harness), never delete or loosen it to go green.
- **`eq` on arrays never matches.** JSON numbers arrive as floats, so
  `[1, 2]` from a Vector2i never equals `[1.0, 2.0]`. Expose cells as
  `"x,y"` strings (or scalars) in `get_observed_state()`.
- **Record the first event, not the last.** The AI answers within its
  timer tick, so a harness field like `last_attack` gets overwritten before
  the checkpoint; capture the first occurrence when that is what the
  scenario asserts.

## Exit codes

Both gates: `0` pass · `1` assertion_failure · `2` runtime_error. Scenarios
add `3` timeout · `4` artifact_generation_error. Both runners print
`RESULT {json}` and `ARTIFACTS <path>`.
