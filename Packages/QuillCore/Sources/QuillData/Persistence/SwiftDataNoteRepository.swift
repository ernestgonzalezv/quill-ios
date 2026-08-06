public import Foundation
public import SwiftData
public import QuillDomain

/// SwiftData-backed ``NoteRepository``.
///
/// `@ModelActor` gives the type its own serial executor and a `ModelContext`
/// pinned to it, which is the supported way to touch SwiftData off the main
/// thread: all reads and writes are serialised by actor isolation, so no lock or
/// queue of our own is needed and Swift 6 can prove there is no race.
///
/// Every method returns value-type ``Note`` rather than `NoteEntity` — see
/// `NoteEntity` for why that boundary is not optional.
@ModelActor
public actor SwiftDataNoteRepository: NoteRepository, NoteRepositoryObserving {
    /// `nonisolated` so `changes` can be read without hopping onto the actor —
    /// subscribing is not a database operation and should not queue behind one.
    private nonisolated let broadcaster = ChangeBroadcaster()

    public nonisolated var changes: AsyncStream<Void> { broadcaster.stream() }

    public func all(includingDeleted: Bool) throws -> [Note] {
        var descriptor = FetchDescriptor<NoteEntity>()
        if !includingDeleted {
            descriptor.predicate = #Predicate { $0.deletedAt == nil }
        }
        // Ordering is a domain rule (`NoteOrder`), so it is deliberately not a
        // SortDescriptor here.
        return try modelContext.fetch(descriptor).map(\.domainModel)
    }

    public func note(id: UUID) throws -> Note? {
        try entity(id: id)?.domainModel
    }

    /// Insert-or-update in a single transaction.
    ///
    /// Existing rows are fetched with one `IN`-style query rather than one query
    /// per note, so a 500-note sync round costs two statements instead of a
    /// thousand.
    public func upsert(_ notes: [Note]) throws {
        guard !notes.isEmpty else { return }

        let ids = notes.map(\.id)
        let existing = try modelContext.fetch(
            FetchDescriptor<NoteEntity>(predicate: #Predicate { ids.contains($0.id) })
        )
        var index = Dictionary(existing.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        for note in notes {
            if let entity = index[note.id] {
                entity.apply(note)
            } else {
                let entity = NoteEntity(note: note)
                modelContext.insert(entity)
                index[note.id] = entity
            }
        }

        try commit()
    }

    public func purgeTombstones(deletedBefore date: Date) throws {
        // Filtered in Swift rather than in the predicate on purpose: SwiftData
        // cannot compile a comparison against a force-unwrapped optional
        // (`deletedAt! < date` fails at *runtime* with `unsupportedPredicate`, not
        // at compile time — which is exactly the kind of bug a test has to catch).
        // Materialising tombstones is irrelevant at personal-notes scale.
        let tombstones = try modelContext.fetch(
            FetchDescriptor<NoteEntity>(predicate: #Predicate { $0.deletedAt != nil })
        )
        for entity in tombstones {
            guard let deletedAt = entity.deletedAt, deletedAt < date else { continue }
            modelContext.delete(entity)
        }
        try commit()
    }

    private func entity(id: UUID) throws -> NoteEntity? {
        var descriptor = FetchDescriptor<NoteEntity>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    /// Saves, then notifies. Notifying only after a successful `save()` means a
    /// listener that re-reads can never observe a change that was rolled back.
    private func commit() throws {
        guard modelContext.hasChanges else { return }
        do {
            try modelContext.save()
        } catch {
            // Leaving a failed context dirty would make the next unrelated save
            // retry this one and fail again.
            modelContext.rollback()
            throw error
        }
        broadcaster.send()
    }
}

public extension ModelContainer {
    /// The app's container.
    ///
    /// - Parameter inMemory: used by tests and previews. An in-memory container
    ///   is created per test so suites can run in parallel without sharing a file.
    static func quill(inMemory: Bool = false) throws -> ModelContainer {
        try ModelContainer(
            for: NoteEntity.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: inMemory)
        )
    }
}
