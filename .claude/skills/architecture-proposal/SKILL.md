---
name: architecture-proposal
description: Use BEFORE writing code for any major change (CLAUDE.md § No silent architecture defines major). State concretely how you intend to build it against the seam catalog, then stop for approval. Also use when a task looks like it needs a seam the kit does not have.
---

# Architecture proposal

The kit has a small number of seams (ARCHITECTURE.md § Seams, and the
author-battle-ruleset skill's mechanic table). Most work fits one. This skill exists
so that when work does NOT fit, the new shape is stated and agreed before it
lands, instead of appearing in a diff.

## When

Major, per CLAUDE.md: a new abstract type or a new method on `BattleRuleset`,
`ActionRule`, `AiController` or `DamageModel`; a new field on `BattleUnit`,
`BattleState`, `BattleGrid` or the defs; a change to a public contract (battle
JSON, suite JSON, an event's keys, the report shape, exit codes); a new
subdirectory under the addon; a new dependency; five or more files; or any
pattern the codebase does not already have, even in one file. When in doubt,
write the one-line "follows pattern X" justification; if you cannot name X,
it is major.

## The proposal (post it, then stop)

```markdown
## Proposal: <change>

**Problem.** <what cannot be expressed today, with the concrete game or suite that needs it>

**Seam.** <existing seam it extends, or the new seam, named the way ARCHITECTURE.md names them>

**Shape.**
- <type / method / field, with full signature and where it lives>
- <who calls it, when, and what the default does so existing games are unaffected>
- <events emitted, if any, with keys>

**Contracts touched.** <battle JSON / suite JSON / events / report / none>

**Proof.** <the sim suite or scenario that will show it RED then GREEN>

**Rejected.** <one or two alternatives and the sentence that kills each>

**Cost.** <files touched, examples updated, docs rows added>
```

Then wait for explicit approval. Do not start the implementation in the same
turn, even "just the easy part".

## During implementation

- A *structural* deviation from the approved shape (a different seam, a
  different signature, a contract change not listed) means stop and re-propose
  that part.
- A *tactical* deviation (a helper, a rename, a default value) is logged as it
  happens and reported in an **Architecture deviations** section at the end of
  the turn, with one line each.
- The proposal's Proof section becomes the RED step of the validate-gameplay
  loop; if the proof changes, say so.

## Catalog of existing patterns (name these instead of proposing)

- Strategy through the ruleset: a `func` on `BattleRuleset` with a default,
  overridden by the game (movement_cost, are_enemies, check_outcome).
- Template rule: a concrete `ActionRule` with overridable steps
  (AttackRule.resolve/after_attack, AreaRule.affect/after_apply).
- Hook with engine access: `on_event(state, engine, event)` that calls back
  into the engine (skirmish dissolve, frontier entrench-clearing).
- Runtime bag: `unit.custom` / `state.custom` for game-only state; typed
  subclass for def fields.
- Data through the loader: a new battle-file key handled in
  `BattleLoader.build_with_ruleset` and documented in its header.
- Metric through events: emit an event, fold it in `summarize` or let the
  kit's `fold_metrics` count it.
- Registry of scripts: `AiRegistry` (never closures).
