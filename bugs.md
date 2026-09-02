# Bugs

Transient work-tracking. Ids are frozen (`B-<n>`), never reused. A fixed bug
closes with one line pointing at the suite or scenario that guards it; a
fixed bug with no proof is a coverage gap, not tidying.

## Open

(none)

## Closed

- **B-1** Both the sim CLI and scenario runs exited with `-1073741819`
  (access violation) after every artifact was written and every assertion
  passed. Cause: `AiRegistry` held lambdas in a `static var`; the closures
  kept ruleset instances alive past engine shutdown. Fixed by registering
  scripts (D10) and clearing the registry before `quit()`. Guard: every sim
  suite now reports exit 0 through `simulate.ps1`, and the scenario suite
  returns engine exit 0 (`./validate.ps1 -RepeatCount 3`, 6/6 green).
- **B-2** The scenario harness stepped the battle twice per `sim_step`
  press: the validation runtime re-asserts a held action every physics
  frame, so `is_action_just_pressed` fired on each. Fixed with rising-edge
  detection on `is_action_pressed`. Guard: `attack_reduces_defender_hp`
  asserts `step_count eq 1` after one press.
- **B-3** `BattleLoader.set_path` shadowed `Resource.set_path` when called
  statically through the script object; every sweep errored. Renamed to
  `set_dotted_path`. Guard: `skirmish_aura_sweep` runs four sweep cells.
