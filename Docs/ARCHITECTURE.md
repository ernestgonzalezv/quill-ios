# Architecture

## The dependency rule

Four layers. Dependencies point inward only.

```
        ┌──────────────────────────────────────────┐
        │  Quill (app target)                      │
        │  composition root, App Intents,          │
        │  Spotlight, scene lifecycle              │
        └───────┬───────────────┬──────────────────┘
                │               │
        ┌───────▼──────┐  ┌─────▼────────────────┐
        │ QuillFeature │  │ QuillData            │
        │ SwiftUI      │  │ SwiftData, URLSession│
        │ view models  │  │ sync engine          │
        └───────┬──────┘  └─────┬────────────────┘
                │               │
        ┌───────▼───────────────▼──────────────────┐
        │  QuillDomain                             │
        │  entities · ports · use cases            │
        │  imports nothing but Foundation          │
        └──────────────────────────────────────────┘
```

`QuillFeature` and `QuillData` do not know each other exists. They meet only at
the app's composition root, through protocols the domain declares.

This is enforced by SwiftPM target dependencies, not by convention. A view model
that tries to `import QuillData` fails to compile.

## Why this shape

The usual justification for Clean Architecture is testability, which is true but
undersells it. The concrete wins here:

**Test speed and honesty.** `QuillDomainTests` runs pure functions. No container
to spin up, no `URLProtocol` to register globally, no simulator. The suite runs on
a Linux-less macOS CI job in seconds, and nothing is flaky because nothing is
shared.

**The compiler enforces capability.** `ViewModelNoteList`'s initialiser lists
exactly what it can do: load, create, delete, pin, sync. It has no repository
reference, so it cannot invent a query or forge an `updatedAt`. Reading the
initialiser tells you the screen's full blast radius.

**Change is local.** Swapping SwiftData for Core Data, or this REST backend for
CloudKit, touches one module and the composition root. Nothing in the domain or
the UI moves.

The cost is real and worth naming: more files, more indirection, and a mapping
layer (`Note` ↔ `NoteEntity` ↔ `NoteDTO`) that looks like duplication. For an app
this size that is a deliberate over-investment — the point of the repo is the
structure. See [ADR-001](ADR-001-modular-clean-architecture.md).

## Layer by layer

### QuillDomain

Pure Swift. `import Foundation` and nothing else — no SwiftData, no SwiftUI, no
`URLSession`.

- **Entities** — `Note`, `NoteDraft`, `NoteOrder`. Value types. All mutation goes
  through methods that stamp `updatedAt` (`edited(with:at:)`, `pinned(_:at:)`,
  `deleted(at:)`), so a timestamp can never silently drift out of date and break
  conflict resolution.
- **Ports** — `ProtoNoteRepository`, `ProtoNoteRepositoryObserving`, `ProtoRemoteNoteStore`,
  `ProtoSyncCursorStore`, `ProtoNoteSynchronizing`. Protocols the outer layers implement.
- **Use cases** — `LogicCreateNote`, `LogicUpdateNote`, `LogicDeleteNote`, `LogicTogglePin`,
  `LogicLoadNotes`, `LogicLoadNote`, `LogicSyncNotes`. Small structs with one
  `callAsFunction`, so a call site reads `try await createNote(draft)` and each
  one is independently constructible in a test.
- **Support** — `ProtoDateProvider` (injectable "now"), `LogicNoteMerger` (conflict
  resolution), `NoteError`.

Notable: **sorting, search matching and blank-note rules live here**, not in
SwiftData predicates. They are product rules, they must behave identically
offline and online, and as predicates they would be untestable without a store.

### QuillData

The adapters.

- `InteractorNotePersistence` — a `@ModelActor`. All store access is serialised by
  actor isolation. `NoteEntity` is `internal`: `@Model` objects are bound to their
  `ModelContext` and are not `Sendable`, so they are mapped to `Note` before
  crossing the module boundary. That makes the classic "passed a managed object to
  another thread" bug unrepresentable.
- `InteractorChangeBroadcaster` — fans store-change notifications out to multiple
  consumers, because `AsyncStream` is single-consumer and both the list and the
  Spotlight indexer need every tick. Uses `Mutex` rather than an actor so `send`
  stays synchronous and notifications cannot reorder relative to the writes that
  caused them.
- `ProtoInteractorHTTP` / `InteractorHTTPURLSession` / `InteractorHTTPRetrying` — retry is a
  **decorator**, not a flag, so it composes and can be tested against a stub that
  fails a scripted number of times. Backoff uses full jitter with an injected
  randomness closure.
- `NoteDTO` — separate from `Note` on purpose. The wire format drifting from the
  domain model is the feature.
- `InteractorNoteSync` — coalesces concurrent sync triggers into one in-flight round.

### QuillFeature

SwiftUI and `@Observable` view models. Depends on `QuillDomain` only.

Both view models are `@MainActor` on the whole type, so the compiler proves UI
state is never touched off-main — instead of a `DispatchQueue.main.async` per
assignment and hope.

State is modelled as **one enum, not parallel flags**:

```swift
enum State: Equatable {
    case loading
    case loaded([Note])
    case empty(EmptyReason)
    case failed(message: String)
}
```

`isLoading` + `notes` + `error` permits nonsense (loading *and* failed), forces
every view to invent a precedence, and grows a new illegal combination with each
flag. One value makes the view a total function of state, and adding a case
breaks the view's `switch` at compile time.

`InteractorNoteDeepLink` is how deep links get in. Spotlight and Siri arrive at the app layer,
which has no access to the navigation path; they publish an intent to navigate and
the view consumes it exactly once.

### Quill (app target)

The composition root — the only place concrete types are named. No DI container:
the graph is small enough that initialiser injection is clearer, checked at
compile time, and cannot be misconfigured at runtime.

`FactoryApp.shared` is the single global, and it exists for one reason: the
system instantiates `AppIntent` values itself, so there is no initialiser to
inject through. It is documented as such at the declaration.

## Concurrency model

Swift 6 language mode, `SWIFT_STRICT_CONCURRENCY: complete`, zero warnings.

| Component | Isolation | Why |
|---|---|---|
| View models | `@MainActor` | UI state; compiler-proven no tearing |
| `InteractorNotePersistence` | `@ModelActor` | Serialises store access without a lock |
| `InteractorNoteSync` | `actor` | Guards the in-flight task |
| `InteractorSpotlight` | `@MainActor` | `CSSearchableItem` is non-`Sendable` |
| Use cases, DTOs, entities | `Sendable` values | Cross boundaries freely |
| `InteractorChangeBroadcaster` | `Mutex` | Synchronous `send` from isolated code |

Two details that took thought:

**No `deinit` cancelling debounce tasks.** Under Swift 6 `deinit` is nonisolated
and cannot touch main-actor state. The debounce tasks capture `self` weakly, so
once the view model is gone the task wakes, finds `nil`, and returns.

**`onDisappear` uses a detached task.** `onDisappear` returns immediately, so a
task tied to the view's lifetime would be cancelled before the autosave write
completed. The view model is captured directly instead.

## Data flow: a sync round

```
                 ┌─ cursor.lastSyncedAt() ──────────────┐
                 ▼                                      │
    remote.pull(since:) ──► RemoteChangeSet              │
                 │                                       │
    repository.all(includingDeleted: true)               │
                 │         ▲                             │
                 │         └── tombstones REQUIRED       │
                 ▼                                       │
         LogicNoteMerger.merge(local:remote:)                 │
                 │                                       │
        ┌────────┴────────┐                              │
        ▼                 ▼                              │
  toStoreLocally     toPushRemotely                      │
        │                 │                              │
  repository.upsert   remote.push ──► canonical notes    │
        │                 │              │               │
        └─────────────────┴──────────────┘               │
                          ▼                              │
              cursor.setLastSyncedAt(serverTime) ────────┘
                          ▼
                 purgeTombstones (best effort)
```

Ordering choices that matter:

1. **Tombstones must be in the local snapshot.** Without them a locally-deleted
   note looks absent, the remote copy is treated as new, and the delete
   resurrects. This is the single most common offline-sync bug.
2. **Write remote winners before pushing.** If the push then fails, the device is
   still strictly closer to the server, and the next round is smaller rather than
   starting over.
3. **Advance the cursor last, and only on success.** A thrown error leaves the
   watermark untouched, so the next attempt re-pulls the same delta. Combined with
   idempotent upserts, replaying a round always converges.
4. **The cursor holds server time.** Device clocks are wrong often enough that
   trusting one silently drops records from the next delta.
5. **Tombstone purge is best-effort.** A failure there means the store is slightly
   larger than ideal; it must not fail a sync that already succeeded.

## Testing strategy

| Target | What it covers | Test doubles |
|---|---|---|
| `QuillDomainTests` | Merge rules, use-case behaviour, ordering, search | In-memory repository, frozen `ProtoDateProvider` |
| `QuillDataTests` | Retry schedules, DTO round-trips, real SwiftData | Stub `ProtoInteractorHTTP`, fake `ProtoSleeper`, in-memory `ModelContainer` |
| `QuillFeatureTests` | View-model state transitions, debounce, failure isolation | Fakes for every port |

Time, randomness and sleeping are all injected, so no test sleeps and none flake.
The in-memory `ModelContainer` is created per test, so suites run in parallel
without sharing a file.
