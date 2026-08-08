# Contributing

## Branching model — GitFlow

```
main       ●────────────────────────●──────────────●   tagged releases only
            \                      /              /
release/*    \              ●─────●        ●─────●     stabilise, bump version
              \            /              /
develop     ●──●──●──●────●──●──●──●─────●            integration branch
               /  /  /       /  /  /
feature/*     ●  ●  ●       ●  ●  ●                   one branch per unit of work
```

| Branch | Cut from | Merges into | Purpose |
|---|---|---|---|
| `main` | — | — | Released code only. Every commit is a tagged release. |
| `develop` | `main` | — | Integration. The default branch for day-to-day work. |
| `feature/*` | `develop` | `develop` | One feature or layer per branch. |
| `release/*` | `develop` | `main` **and** `develop` | Version bump and stabilisation. |
| `hotfix/*` | `main` | `main` **and** `develop` | Urgent production fix. |

Merges into `develop` and `main` use `--no-ff`, so each branch stays a visible
unit of work in the history rather than being flattened away. `git log --graph`
then reads as the actual sequence of decisions.

### A feature

```bash
git switch develop && git pull
git switch -c feature/note-attachments
# … commit …
make verify                      # lint + test + build, same as CI
git switch develop
git merge --no-ff feature/note-attachments
git branch -d feature/note-attachments
```

### A release

```bash
git switch -c release/1.1.0 develop
# bump MARKETING_VERSION in project.yml, then `make project`
git switch main && git merge --no-ff release/1.1.0
git tag -a v1.1.0 -m "Release 1.1.0"
git switch develop && git merge --no-ff release/1.1.0   # keep the bump on develop
git branch -d release/1.1.0
```

Releasing into `main` *and* back into `develop` is the step most often skipped;
missing it means the version bump only exists on `main` and the next release
branch reintroduces the conflict.

## Commits

En español, con guion delante y el verbo en participio: `- Added ...`,
`- Updated ...`, `- Fixed ...`, `- Moved ...`, `- Removed ...`.

El resumen dice **qué** cambió; el cuerpo, **por qué**. Un commit que solo
repita el diff no aporta nada que `git show` no diga ya.

Hasta la 1.0.0 el repo usó Conventional Commits; la historia se conserva tal
cual y la convención nueva aplica de ahí en adelante.

## Before opening a PR

```bash
make verify
```

Runs SwiftLint in strict mode, the full test suite, and an app build — the same
three jobs CI runs.

## Where code goes

| Change | Module |
|---|---|
| A rule, entity, or use case | `QuillDomain` — must not import anything but `Foundation` |
| Persistence, networking, sync | `QuillData` |
| Views, view models | `QuillFeature` — must **not** import `QuillData` |
| Wiring, App Intents, Spotlight | `App/Quill` |

If a change seems to need `QuillFeature` to import `QuillData`, the missing piece
is a port in `QuillDomain`. See [Docs/ARCHITECTURE.md](Docs/ARCHITECTURE.md).

Structural decisions get an ADR in [`Docs/`](Docs/) — context, options weighed,
decision, and the consequences you are accepting.
