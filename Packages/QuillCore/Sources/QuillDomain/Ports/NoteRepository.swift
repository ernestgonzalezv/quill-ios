public import Foundation

/// The local store, as the domain needs it.
///
/// This is a *port*: the domain declares the shape, `QuillData` supplies the
/// SwiftData implementation, and tests supply an in-memory one. Nothing in this
/// file knows SwiftData exists — that inversion is what lets the persistence
/// layer be swapped (or the domain be tested) without touching a use case.
///
/// `Sendable` because implementations are actors reached from `@MainActor` view
/// models; under Swift 6 the compiler enforces that this is safe.
public protocol NoteRepository: Sendable {
    /// All notes. Tombstones are excluded unless explicitly requested — only the
    /// sync engine has a reason to see them.
    func all(includingDeleted: Bool) async throws -> [Note]

    func note(id: UUID) async throws -> Note?

    /// Insert-or-update, batched. One call per sync round instead of one per
    /// note, so a 500-note pull is a single transaction rather than 500.
    func upsert(_ notes: [Note]) async throws

    /// Drops tombstones older than `date`. Called after a successful sync so the
    /// store does not grow forever; a tombstone only needs to outlive the window
    /// in which another device might still be offline.
    func purgeTombstones(deletedBefore date: Date) async throws
}

/// A stream of change notifications, kept separate from ``NoteRepository`` so a
/// store that cannot observe (a fake, a read-only mirror) is not forced to fake it.
public protocol NoteRepositoryObserving: Sendable {
    /// Emits once per committed write. Carries no payload: observers re-read
    /// through the repository, which keeps a single source of truth instead of
    /// letting the stream become a second, racier one.
    var changes: AsyncStream<Void> { get }
}
