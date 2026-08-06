# ADR-003 — SwiftData behind a repository port

**Status:** Accepted · **Date:** 2026-08-06

## Context

The app needs a local store that is the source of truth, queryable for search,
and safe to write from a background context during sync.

## Options considered

**1. Core Data.** Mature, fully controllable migrations, well-understood
concurrency story. Verbose, and `NSManagedObject`'s threading rules are a
long-standing source of bugs.

**2. SwiftData.** Chosen. Much less ceremony, `@ModelActor` gives a supported way
to do background work, and `#Unique` / `#Index` express constraints the store
enforces rather than the code hoping for. Less mature: migration control is
coarser and some predicate forms are unsupported.

**3. GRDB / SQLite directly.** Best query control and migration story of the
three. Adds a third-party dependency and hand-written mapping for what is
ultimately a simple schema.

**4. CloudKit as the store.** Would remove the sync engine entirely. Rejected
because building the sync engine *is* part of the point of this repo, and CloudKit
locks the data to Apple accounts.

## Decision

SwiftData, reached only through the `NoteRepository` port.

Two rules make the choice reversible:

1. **`NoteEntity` is `internal` to `QuillData`.** No consumer outside the module
   ever holds a `@Model` object. `@Model` instances are bound to the
   `ModelContext` that fetched them and are not `Sendable`, so leaking one across
   an actor boundary is a data race. The repository maps to value-type `Note`
   before returning, which makes that mistake impossible rather than merely
   discouraged.
2. **No query logic escapes the module.** Sorting (`NoteOrder`), search matching
   (`Note.matches(query:)`) and blank-note rules live in the domain as pure
   functions. They are product rules, they must behave identically offline and
   online, and as SwiftData predicates they would be untestable without a
   container.

Access is via `@ModelActor`, so all reads and writes are serialised by actor
isolation — no lock, no queue, and Swift 6 can prove there is no race.

## Consequences

**Good**

- Far less boilerplate than Core Data, with `#Unique` making the upsert
  contract enforced by the store: a bug in `upsert` surfaces as a constraint
  violation instead of silently duplicating a note.
- `@ModelActor` is the supported background-write story, and it composes with the
  rest of the concurrency model.
- Swapping to Core Data or GRDB is contained to `QuillData` — the domain, the UI
  and every test above the port are unaffected.
- Tests use an in-memory `ModelContainer` per test, so suites run in parallel
  without sharing a file.

**Bad, and accepted**

- Migration control is coarser than Core Data's. A schema change beyond
  lightweight migration will need `SchemaMigrationPlan` and real care.
- Some predicates SwiftData cannot express have to be done in Swift after
  fetching. Acceptable at personal-notes scale; not at hundreds of thousands of
  rows.
- Requires iOS 17+ for SwiftData and iOS 18+ for `#Index`, which sets the
  deployment floor.
- Mapping `NoteEntity` ↔ `Note` is real code that must stay in step with the
  schema.

## Revisit if

The store grows past what in-Swift filtering can handle, or a migration needs
finer control than SwiftData offers. The port means that change is a module-local
rewrite, not an app-wide one.
