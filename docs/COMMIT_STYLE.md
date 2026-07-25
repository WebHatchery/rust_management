# Git Commit Style — Rust Games

**Exemplar**: `mytherra` · **Scope**: the RustGames catalog · **Status**: reference (not one of the synced docs)

This codifies the commit-message convention used across the Rust games, with **Mytherra**
as the worked example. The signature idea is simple:

> A commit's **subject narrates the change in the game's own voice**; a parenthetical
> **grounds it in plain technical terms**; the **body explains the change as honest prose**.

Copy the *shape*, not Mytherra's specific metaphors — every game speaks in its own fiction.
A starship game narrates in the voice of the ship and its crew; a dungeon game in the voice
of the dungeon. The method is the same; the vocabulary is yours.

Why bother? The log becomes a readable chronicle of the game's making — each line says what
changed *and* what it means in the world — instead of a wall of `fix: bug` / `chore: deps`.
It rewards the reader, and it keeps the author thinking about the change in the player's
terms, not just the compiler's.

---

## The shape at a glance

```
<A sentence in the game's diegetic voice> (<plain technical tag>)
<blank line>
<Prose body: the problem, the change, and the reasoning — honestly. Wrapped at
~76 columns. Code identifiers in `backticks`. Design-doc sections referenced by
number. Tests/verification noted. Caveats and follow-ups stated, not hidden.>
<blank line>
Co-Authored-By: <AI pair> <email>
```

Real example, in full:

```
The world is widened to hold the many gods it was built for (GDD 9 content targets)

Author the §9 content-complete world: six new regions, each fully populated,
lifting every axis over its full target — 10 regions, 32 settlements, 44 heroes,
28 landmarks, 42 resource nodes, 8 starter artifacts, 12 trade routes. The new
lands exercise the climates and culture the seed never used (arid/tropical/
frozen, mercantile), so all six climates, five cultures, six hero roles, and six
resource types now appear.

Two adjustments ride along: the frontier growth cap, tuned for a four-region
seed, is rescaled to sit above the authored ceiling so the larger world can
still grow (GDD 5.2); and a civilization test that assumed four regions were the
whole world is made hermetic. A new content-integrity test guards the §9 count
floors and asserts every seed's region reference resolves.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
```

---

## 1. The subject line

**1.1 Speak in the game's diegetic voice.** The subject is a full sentence narrating what
the change *means inside the world*, as the game's own fiction would put it — not what files
moved. Present tense, declarative, no trailing period.

- ✅ `Many deities may now watch one world, each with a purse of their own`
- ✅ `The herald notices when the god falls silent, and waits for its return`
- ❌ `feat: add concurrent player support`
- ❌ `Fix reconnect bug in online.rs`

**1.2 Ground the metaphor with a parenthetical tag.** Every subject ends with a plain-terms
tag in parentheses so the diegetic line is never cryptic. The tag carries the *what/where*:
a subsystem, a design-doc section, and/or a milestone.

```
… (GDD 7.3 account linking, server side)
… (M2: concurrent players)
… (per-entity dirty tracking)
… (GDD 10 / 5.1)
… (docs refresh)
```

The rule of thumb: a reader who skips the metaphor and reads only the parenthetical should
still know exactly what the commit does. The metaphor is the *why-it-matters*; the
parenthetical is the *what*.

**1.3 One line.** It will run longer than the traditional 50-character subject — a full
sentence plus a tag is usually 60–100 chars — and that's fine. Keep it to a single line and
don't wrap it. If you can't fit the idea in one line, the commit is probably doing too much.

**1.4 Map each technical concept to the fiction, once, and stay consistent.** The power of
the style is a stable metaphor set: readers learn that "the herald" is the client and "the
chronicle" is the event log, and every later commit reuses those. Mytherra's mapping, as a
model — build your game's own table before your first commit:

| Technical concept | Mytherra's fiction |
| --- | --- |
| the client | the herald |
| the authority server / shared world | the world; scripture; stone |
| a player / account | a god / deity |
| configuration | scripture (*named*, "not carved into its bones") |
| persistence / the database | written into stone; the world's own book |
| the per-player projection / view | the god's window onto the world |
| the event log | the chronicle |
| networking / the wire | down the wire; the veil |
| betting / speculation | the Observatory; wagers |
| divine favor / the economy | the god's purse / income |
| standing / progression tiers | the ranks of godhood |

**1.5 Don'ts.**
- No Conventional-Commits prefixes (`feat:`, `fix:`, `chore:`, `refactor:`).
- No bare ticket/issue numbers as the subject; weave context into the tag if needed.
- Don't drop the parenthetical — a metaphor with no anchor is a riddle, not a subject.
- Don't force a metaphor onto trivial mechanical commits; a plain, quiet subject with a
  clear tag is better than a strained one (e.g. `The scriptures are set right to match the
  world as it now stands (docs refresh)` — light touch, honest tag).

---

## 2. The body

Present when the change is more than trivial (most feature/fix/refactor commits carry one).

**2.1 Prose, not bullet-dumps.** Write paragraphs. The body reads like a short technical
note, lightly colored by the same voice as the subject ("a death still precedes the
sainthood it enables", "two deities would race on one column"). Bullet lists are allowed
sparingly for genuine enumerations, but the default is prose.

**2.2 Lead with the problem or the motivation**, then the change, then the reasoning. Many
of the best commits open by naming what was wrong or missing, so the fix reads as an answer:

> *The chronicle clumped by kind because every subsystem records in a fixed order each tick
> … A review found no artificial yearly-rotation generating batches …*

**2.3 Be concrete and technical.** Name the real identifiers in `backticks`
(`WORLD_COLLECTIONS`, `canonizations_per_tick`, `ally_id`), reference design-doc sections by
number (§6, §7.7), and give real figures (`10 regions, 32 settlements`). The metaphor lives
in the phrasing, never at the expense of precision.

**2.4 State verification.** If tests were added or the change was checked, say so briefly
("a persistence test pins the invariant…", "verified end-to-end against the live server…").

**2.5 Be honest about tradeoffs and follow-ups.** Where a change is partial, a decision was
deliberate, or something is deferred, say it plainly in a closing paragraph rather than
leaving it for the reader to discover:

> *Refugee flights remain a per-tick Region-kind emission … several flights in one year
> still group within the Region draws — a finer split or a summary line is a possible
> follow-up.*

**2.6 Wrap at ~76 columns.** Consistent with the existing history and readable in a terminal.

---

## 3. The footer

End every commit with a co-authorship trailer for the AI pair, on its own line after a blank
line, in standard git-trailer form:

```
Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
```

Use whatever model/name string the working environment specifies; the important part is that
AI-assisted commits are attributed with a `Co-Authored-By:` trailer.

---

## 4. Worked examples, by kind of change

**Feature**
```
A god may sign its name to the world and find it again anywhere (GDD 7.3 account linking, server side)
Many deities may now watch one world, each with a purse of their own (M2: concurrent players)
A returning god is told only what changed while away (M1: GET /events)
```

**Fix / behavior correction**
```
A year's chronicle reads as the mixture it was, and its saints as a procession (GDD 10 / 5.1)
No land bends wholly to the richest god in a single turning (GDD 7.5 nudge cap)
The herald acts on the world the god shows it, not the one it remembers (online target resolution, GDD 7.7)
```

**Refactor / architecture**
```
The world is unmade into its many parts, and the gods are set apart from it (persistence crate; world/player dissociation)
Only the parts of the world that stirred are rewritten (per-entity dirty tracking)
One hand writes the deed, god and herald both stay it (M1: shared apply)
```

**Config / infra / docs** (lighter touch — the metaphor stays modest)
```
The god's dwelling place is named in scripture, not carved into its bones (M2: server address to config)
A minimal rite to raise the god's server on one desk (local run script + guide)
The scriptures are set right to match the world as it now stands (docs refresh)
```

---

## 5. Checklist before you commit

- [ ] Subject is one sentence, in the game's voice, present tense, no trailing period.
- [ ] Subject ends with a plain-terms `(tag)` — subsystem, GDD §, and/or milestone.
- [ ] A reader who ignores the metaphor still knows what the commit does.
- [ ] Body (if any) is prose: problem → change → reasoning, honest about tradeoffs.
- [ ] Real identifiers in `backticks`; design sections referenced by number; figures given.
- [ ] Verification/tests noted where relevant.
- [ ] `Co-Authored-By:` trailer present.
- [ ] The metaphor set matches earlier commits (same fiction for the same concepts).
