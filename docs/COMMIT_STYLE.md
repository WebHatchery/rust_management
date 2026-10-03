# Git Commit Style - Rust Games

Catalog-wide message reference, not synced into games. Read this when composing
a commit; [AGENTS.md](AGENTS.md#commits) governs slice cadence, ownership, and
staging. [Validation](CODE_STANDARDS.md#83-validation) governs required checks.

## The shape at a glance

```text
<A present-tense sentence in the game's voice> (<plain technical tag>)

<Problem, change, reasoning, verification, and honest caveats in prose.>

Co-Authored-By: <AI pair> <email>
```

Read `mytherra` or `stellar_legacy` history before the first commit in a new
game; then match that game's vocabulary. Copy the shape, not another game's
fiction. Commit each small, coherent, buildable feature slice after review and
checks; do not accumulate several major features or commit broken code for cadence.

## 1. The subject line

- One present-tense declarative sentence, no trailing period. Narrate what the
  change means in the game's world. A single line of 60-100 characters is fine;
  if it cannot hold the idea, consider whether the slice is too broad.
- End with a clear parenthetical subsystem, GDD section, or milestone. A reader
  ignoring the fiction must still understand the technical change.
- Use stable metaphors for the same concepts. Establish the game's vocabulary
  before its first commit: Mytherra calls its client the herald, shared world
  the world/scripture, persistence stone, per-player projection a god's window,
  and event log the chronicle. Another game needs its own terms.
- No Conventional-Commits prefixes (`feat:`, `fix:`, `chore:`, `refactor:`), bare
  issue-number subjects, or unexplained metaphors without a tag.
- Mechanical/configuration/documentation work can use a plain, quiet subject;
  do not force fiction onto it.

## 2. The body

Non-trivial feature/fix/refactor commits need an explanatory body. Lead with the
problem or motivation, then the change and reasoning. Use connected prose;
bullets are for genuine enumerations. Wrap around 76 columns.

Name real identifiers in backticks, design sections by number, and meaningful
figures. Fiction must never obscure technical precision. State the checks
actually run and their outcome, plus limitations, deliberate tradeoffs, and
follow-ups. Do not claim unrun checks or hide a baseline failure.

## 3. The footer

End AI-assisted commits with an accurate standard trailer, separated by a blank
line. Use the working environment's model/name and suitable attribution email:

```text
Co-Authored-By: Codex <noreply@openai.com>
```

## 4. Worked examples, by kind of change

| Kind | Subject |
| --- | --- |
| Feature | A returning god is told only what changed while away (M1: GET /events) |
| Fix | No land bends wholly to the richest god in a single turning (GDD 7.5 nudge cap) |
| Refactor | Only the parts of the world that stirred are rewritten (per-entity dirty tracking) |
| Mechanical | Shared instructions name the checks for each slice (docs refresh) |

Example body beneath a save-migration subject:

```text
Old saves omitted the alloy ledger. Loading now supplies the documented
initial value and migrates the schema before gameplay reads it. The public
save API remains unchanged. A regression covers the previous version;
formatting, Clippy, source-size gates, full tests, and preview publish pass.

Co-Authored-By: Codex <noreply@openai.com>
```

The verification sentence is an example, not a result to copy without checking.

## 5. Checklist before you commit

Review the complete staged slice and message: clear sentence/tag, consistent
voice, concrete explanatory body where needed, honest verification/caveats,
and AI attribution. Follow the ownership and final-status rules in AGENTS;
local commits do not authorize a push or external publication.
