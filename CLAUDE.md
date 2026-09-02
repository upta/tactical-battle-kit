# CLAUDE.md

Tactical Battle Kit: a GDScript grid-tactics rules engine (Godot 4.7.1, GL
Compatibility) with a headless balance simulator, consumed by games as an
addon. Where things live and what words mean: ARCHITECTURE.md. Design intent:
SPEC.md. Contested calls: DECISIONS.md. This file is how we work.

## Truth hierarchy

When two sources disagree, the higher one wins and the lower one is a bug to
fix or delete:

1. **Code, sim suites and validation scenarios**: what the kit actually does
2. **ARCHITECTURE.md and this file**: where things live and how we work
3. **Active entries in DECISIONS.md**: contested calls the code can't explain
4. **Never: closed tasks or bugs.md.** The bug ledger is transient
   work-tracking that goes stale by design. Read it for leads, never as law;
   the suite or scenario is the memory.

A doc that contradicts the code is a doc bug. Fix it or delete it; do not
annotate it as historical.

## Proof-first

Humans play the viewer for feel and read reports for design questions.
Proving the code works is your job, before any human looks. Two artifacts,
picked by what the claim is about (validate-gameplay skill):

- **Sim suite** (`src/sim/suites/`, `./simulate.ps1`): rules, scheduling, AI,
  determinism, balance, loader, sweeps. Headless; runs in CI.
- **Validation scenario** (`src/validation/scenarios/`, `./validate.ps1`): the
  view, the runner, input bridging, anything a screenshot can catch.

A proof that has never failed proves nothing. Confirm it goes RED before the
implementation makes it green. A bug found by a human means proof had a gap:
reproduce it in a suite or scenario first, then fix.

## No silent architecture

Before writing code for a **major change**, invoke the architecture-proposal
skill: state concretely how you intend to build it against the seam catalog,
then stop and wait for explicit approval. Major = a new abstract type or a
new method on `BattleRuleset` / `ActionRule` / `AiController` / `DamageModel`;
a new field on `BattleUnit`, `BattleState`, `BattleGrid` or a def; a change to
a public contract (battle JSON, suite JSON, event keys, report shape, exit
codes); a new addon subdirectory; a new dependency; 5+ files; **or any
pattern the codebase does not already have, even in one file** (the skill has
the catalog). Small changes that follow an existing pattern skip it: say in
one line which pattern, and if you cannot name one it is major. Structural
deviation from an approved proposal means stop and re-propose; tactical
deviations are logged and reported in an "Architecture deviations" section.
This applies to ad-hoc requests, not just `/build`.

## Definition of Done

Stated once, here. Every command references it; none restate it.

1. **Proof exists** for the change: a suite or scenario asserting the intended
   behavior, not just the happy path, and it was seen RED first.
2. **Sim suites green**: `./simulate.ps1`, and you read the `report.md` tables
   and said what they show.
3. **Scenario suite green with screenshots reviewed**: `./validate.ps1` when
   anything under `src/app`, the addon's `view/`, or `src/validation` changed;
   the six-point rubric is in the validate-gameplay skill.
4. **Viewer boots clean**: run-game skill; the `[Kit] Battle ready:` marker
   appears and the runtime log has zero ERROR lines.
5. **Scripts compile and scenes load**: `src/tools/check_scripts.ps1`. There is
   no style gate: gdformat/gdlint were dropped (D12); agents write the code.
6. **`.uid` sidecars committed**: run the import before committing; no
   unstaged `.uid` files left behind.
7. **Conventional commit in value language**, and `git push origin` at the end
   of every work batch.

## Planning and tasks

Work items are disposable. Documentation is not.

- `tasks/phase-<N>.md` is the one ticket for a lane in flight, ~40 lines.
  At most two lanes; a third `phase-*.md` is an error the docs hook enforces.
  Deleted when closed, not archived.
- `tasks/todo.md` is the current checklist; the final unchecked item is always
  the human checkpoint.
- Ids are frozen. Task numbers, decision ids (`D<n>`), bug ids (`B-<n>`):
  never renumber, never reuse, never delete an id.

## Commands

| Command | Purpose |
| --- | --- |
| `/spec` | Interview-first design intent, folded into SPEC.md in place |
| `/plan` | Write the next phase ticket; read-only for code |
| `/build` | Land the next unchecked task; proposal first if major |
| `/test` | Unplanned verification: reproduce a bug, backfill coverage |
| `/review` | Cheap single-pass five-axis review, mid-phase |
| `/ship` | The phase gate: three reviewers fan out, DoD verified, GO/NO-GO |
| `/merge` | Fast-forward-only landing on main |

## Boundaries

- **Ask first:** any change inside `submodules/agentic_godot_validation/`
  (shared across projects); adding addons; changing the exit-code contracts.
- **Never:** edit `src/addons/agentic_godot_validation/**` (a symlink into
  the submodule); put game logic in `core/` or nodes in anything but `view/`;
  hand-author `uid://` values; delete or weaken a failing suite or scenario to
  get green; hold closures in a `static var`; kill a running godot with
  Stop-Process (a 0-byte log reads as a clean pass).
- **`tools/` is a symlink into the submodule**: the validation kit's runners,
  not ours. Repo-owned scripts live in `src/tools/` or at the repo root.

## Known issues

- Godot mono builds sometimes exit with `-1073741819` (access violation)
  during teardown after every artifact is written. `simulate.ps1` trusts the
  `RESULT` line over the process exit code for this reason. If a scenario
  run shows that code with `summary.json` saying pass, suspect a static var
  holding an object or closure (B-1).

## Style

- Typed GDScript everywhere: parameter and return types on every function,
  `Array[T]` and `Dictionary[K, V]` wherever the element type is known,
  `:=` for inferred locals. `Variant` only for genuinely open values.
  Two blank lines between functions.
- Comments only where the code can't say it: constraints and traps, not
  narration. Doc comments (`##`) on every class and every public seam.
- No em-dashes in docs or comments; use a colon, a semicolon, or a new
  sentence.
- PowerShell scripts: UTF-8 **with BOM** (Windows PowerShell 5.1 misparses
  BOM-less UTF-8), and `Start-Process -Wait` for godot.exe.
