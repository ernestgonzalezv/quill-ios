# ADR-001 — Modular Clean Architecture over a single app target

**Status:** Accepted · **Date:** 2026-08-06

## Context

A notes app of this size fits comfortably in one target with SwiftUI views talking
to SwiftData `@Query` directly. That is the shortest path to a working app, and for
a genuine weekend project it would be the right call.

The requirement here is different: the codebase has to demonstrate and hold up
under the constraints a production app has — parallel work on separate features,
tests that run in CI in seconds, and the ability to replace persistence or the
backend without a rewrite.

## Options considered

**1. Single app target, SwiftUI + `@Query`.**
Fastest to write. But views become coupled to `@Model` types, so any view test
needs a `ModelContainer`; business rules end up inside view bodies or SwiftData
predicates where they cannot be unit-tested; and there is no boundary to stop a
view from performing a network call.

**2. MVVM in one target, folders as layers.**
Better. View models are testable if the repository is a protocol. But "layers" are
only a convention — nothing prevents a view model from importing SwiftData, and in
practice something eventually does. The rule is unenforced.

**3. Local SPM package with separate `Domain` / `Data` / `Feature` targets.**
Chosen. The dependency rule becomes a compile error rather than a code-review
comment: `QuillFeature` does not list `QuillData` as a dependency, so a view model
*cannot* reach `URLSession` or a `ModelContext`.

## Decision

A local Swift package, `QuillCore`, with three library targets — `QuillDomain`,
`QuillData`, `QuillFeature` — and a thin app target that owns only the composition
root and OS integrations.

## Consequences

**Good**

- The dependency rule is compiler-enforced, not aspirational.
- `QuillDomain` imports only `Foundation`, so its tests are pure functions with no
  container, no simulator, no global `URLProtocol` registration.
- `QuillFeature` tests run against fakes in milliseconds.
- The core builds for macOS as well as iOS, which is what lets CI run the whole
  suite with `swift test` and no simulator boot.
- Replacing SwiftData or the backend is contained to one module plus the
  composition root.

**Bad, and accepted**

- Three representations of a note (`Note`, `NoteEntity`, `NoteDTO`) plus mapping.
  It reads as duplication; it is actually the seam that lets storage and wire
  formats change independently. For an app this small it is over-investment, made
  deliberately.
- More files and more indirection to navigate.
- Adding a use case touches the domain, the composition root, and the view model
  rather than one file.
- Public/internal access control has to be managed across module boundaries,
  including `public import` under `InternalImportsByDefault`.

## Revisit if

The app stays this small *and* the team stays at one person indefinitely — at
which point options 1 or 2 would ship features faster. The structure earns its
cost when more than one person is in the codebase, or when persistence/backend
choices are still in flux.
