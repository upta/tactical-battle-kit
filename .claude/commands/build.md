# /build

The default working command: take the next unchecked task in `tasks/todo.md`
and land it. "Build the next phase" while the previous phase still has
unchecked engineering tasks means surface those instead.

- The Definition of Done in CLAUDE.md is the contract; meet it, don't restate
  it.
- **Major change? Proposal first.** CLAUDE.md § No silent architecture
  defines major. If the task is one, invoke the architecture-proposal skill,
  stop for approval, then build. If it is borderline, say in one line why it
  follows an existing pattern (name the pattern from ARCHITECTURE.md) and
  proceed.
- Proof first, confirm it FAILS (validate-gameplay skill), then implement to
  green. Pick the proof by what the claim is about: a sim suite for rules,
  AI and balance; an in-engine scenario for anything a screenshot can catch.
- A contested call made along the way goes to DECISIONS.md in the same commit.
- Run the import so `.uid` sidecars exist; commit them with the change.
- Check the task off in todo.md: `✅ <date> (<one-line outcome>)`.
- Commit conventionally, in value language: what a game author or the kit
  gained, not which files changed. Push at the end of the batch.
- End with **Try it**: how a human sees this change (`godot --path src`, or
  `./simulate.ps1 -Suite <x>` and which table to read). If the change has no
  visible surface, say so rather than inventing one.
