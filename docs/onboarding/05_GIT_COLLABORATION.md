# Git collaboration workflow

Each game, `macroquad-toolkit`, and `rust_management` is an independent Git
repository. Always check the current directory and repository before staging or
committing.

## Branching

The long-lived branch is currently `master` in the established repositories.
Confirm rather than assume:

```powershell
git remote show origin
git branch --show-current
git status --short
```

For shared work, use a short-lived branch from the latest remote default branch:

```powershell
git fetch origin
git switch master
git pull --ff-only origin master
git switch -c <your-name>/<short-purpose>
```

If the team standardizes a different prefix, use it consistently. Do not commit
directly to the shared default branch unless the maintainer has explicitly
chosen that workflow.

## Divide work before editing

- Assign an issue/feature and name the owning repository.
- Avoid two people editing the same source module or shared JSON file at once.
- Announce toolkit and management changes because they affect multiple games.
- Keep refactors separate from feature work unless the refactor is required for
  the feature.
- For multi-repository work, state the dependency order and link all pull
  requests.

Recommended merge order:

```text
management/toolkit prerequisite -> dependent game -> catalog-wide sync
```

## Commit scope and message style

Commits should be focused and leave the repository buildable. Before committing:

```powershell
cargo fmt -- --check
cargo test
cargo clippy --all-targets --all-features -- -D warnings
git status --short
git diff --check
git diff
```

Game commits follow [../COMMIT_STYLE.md](../COMMIT_STYLE.md):

- a present-tense subject in the game's own voice;
- a plain technical parenthetical at the end;
- no Conventional Commit prefix such as `feat:` or `fix:`;
- a prose body for non-trivial work: problem, change, reasoning, verification;
- an AI co-author trailer when AI materially authored the change.

Example shape:

```text
The foundry remembers every alloy entrusted to it (save migration and tests)

Old saves omitted the newly introduced alloy ledger. Loading now supplies the
documented default and migrates the schema before gameplay reads it. A focused
persistence test covers the previous version, and the preview publish passes.
```

Read a game's recent history before the first commit so its metaphors remain
consistent:

```powershell
git log -10 --format=fuller
```

Do not put secrets, generated `target/` output, local `.env` files, or unrelated
editor settings in a commit.

## Pull requests and handoff

Push the branch and open a pull request:

```powershell
git push -u origin HEAD
gh pr create --fill
```

The PR should state:

- player-facing outcome and technical scope;
- important design decisions or intentional non-goals;
- tests and exact publish command/result;
- screenshots for UI changes;
- save compatibility or asset impact;
- linked prerequisite PRs/commits in other repositories; and
- follow-up work that is deliberately deferred.

Reviewers should reproduce the focused tests and inspect touch controls, text
bounds, common browser sizes, and save migration when relevant.

## Staying current and resolving conflicts

Fetch frequently. Before final review, incorporate the updated default branch
using the team's chosen merge/rebase policy. Never rewrite someone else's
published branch without agreement.

For JSON/content conflicts, do not accept one entire side blindly: preserve
valid entries from both authors, then run content validation/tests. For Cargo
conflicts, resolve `Cargo.toml` deliberately and regenerate/verify the applicable
lockfile through Cargo rather than hand-merging dependency checksums.

After merging, delete the feature branch if it is no longer needed and tell the
other collaborator which commit is safe to build on.

## Coordinating toolkit changes

A game can compile locally against an unpushed toolkit branch, but nobody else
can reproduce it. Therefore:

1. commit and push the toolkit branch;
2. record its commit hash in the game PR;
3. validate an affected game against that exact toolkit state;
4. merge toolkit first; and
5. update/retest the game branch against the merged toolkit branch.

Because the dependency is a sibling path rather than a pinned Git revision,
clear communication is the reproducibility mechanism.
