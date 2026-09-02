# /ship

The phase gate. Three parts, in order.

**A — Review fan-out.** Spawn the three reviewers
(`.claude/agents/code-reviewer.md`, `.claude/agents/test-engineer.md`,
`.claude/agents/balance-analyst.md`) as subagents IN ONE MESSAGE; sequential
spawns lose the parallelism. Work their Critical and Important findings.

**B — Verify the Definition of Done yourself.** Never on a subagent's word.
Both gates: `./simulate.ps1` and `./validate.ps1`. A re-run may be skipped
only if the newest `src/artifacts/sim/latest_suite.json` and
`src/artifacts/latest_suite.json` are both newer than every change under
`src/` (the validation addon symlink, artifacts, tools excluded), and always
re-run after Phase A prompted a fix: a green run from before the fix proves
nothing about it.

**C — GO / NO-GO.** Report the verdict with evidence: sim suite table, scenario
suite result, boot marker, which screenshots you reviewed and what they
showed. NO-GO names what's left.
