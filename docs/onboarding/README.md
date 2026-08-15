# WebHatchery Rust Games: collaborator onboarding

This is the starting point for a developer joining the WebHatchery Rust games
workspace. Complete the pages in order on the first setup; use the individual
pages as references afterward.

## First-day checklist

1. Read [workstation and workspace setup](01_WORKSPACE_SETUP.md).
2. Obtain GitHub access to the repositories you will work on.
3. Clone `rust_management`, `macroquad-toolkit`, and the assigned game as
   siblings under one `RustGames` directory.
4. Install the Rust WebAssembly target and verify the native toolchain.
5. Run the smoke-test commands in the assigned game.
6. Read [daily development](02_DAILY_DEVELOPMENT.md) and
   [toolkit and architecture](03_TOOLKIT_AND_ARCHITECTURE.md).
7. Ask the maintainer for deployment secrets only if publishing is part of your
   role; normal development needs none.
8. Agree on ownership of the first issue and follow the
   [Git collaboration workflow](05_GIT_COLLABORATION.md).

## What is where

The workspace is a collection of independent Git repositories arranged so that
Cargo path dependencies resolve:

```text
<workspace parent>/
└── RustGames/                    Cargo workspace; not a Git repository
    ├── Cargo.toml                shared Cargo workspace membership/profile
    ├── Cargo.lock                shared local dependency lock
    ├── .cargo/config.toml        shared WASM linker flags
    ├── publish.ps1               forwarding wrapper
    ├── macroquad-toolkit/        independent Git repository
    ├── rust_management/          this independent Git repository
    ├── <game-one>/               independent Git repository
    ├── <game-two>/               independent Git repository
    ├── target/                   shared build cache; generated
    ├── Release/                  catalog artifacts; generated
    └── publish-logs/             batch-publish logs; generated
```

There is no single monorepo commit or release. A toolkit change, management
change, and game change are separate commits in separate repositories.

## Reference set

| Need | Read |
| --- | --- |
| Install tools and lay out folders | [01_WORKSPACE_SETUP.md](01_WORKSPACE_SETUP.md) |
| Build, run, test, and validate | [02_DAILY_DEVELOPMENT.md](02_DAILY_DEVELOPMENT.md) |
| Understand toolkit and game structure | [03_TOOLKIT_AND_ARCHITECTURE.md](03_TOOLKIT_AND_ARCHITECTURE.md) |
| Configure and run publishing | [04_PUBLISHING.md](04_PUBLISHING.md) |
| Branch, commit, review, and coordinate | [05_GIT_COLLABORATION.md](05_GIT_COLLABORATION.md) |
| Diagnose common setup/build failures | [06_TROUBLESHOOTING.md](06_TROUBLESHOOTING.md) |
| Full code rules | [../CODE_STANDARDS.md](../CODE_STANDARDS.md) |
| Full development guide | [../GAME_DEVELOPMENT_GUIDE.md](../GAME_DEVELOPMENT_GUIDE.md) |
| Toolkit API/pattern reference | [../MACROQUAD_TOOLKIT.md](../MACROQUAD_TOOLKIT.md) |
| Commit-message convention | [../COMMIT_STYLE.md](../COMMIT_STYLE.md) |

## Access to request from the maintainer

- GitHub read/write access for the assigned game and, when needed,
  `macroquad-toolkit` and `rust_management`.
- The issue/feature brief and the person responsible for merging it.
- Deployment values only when the collaborator is authorized to publish.
- Any game-specific external-service credentials. These do not belong in Git.

Never send secrets in a commit, pull request, issue, screenshot, or chat log.
