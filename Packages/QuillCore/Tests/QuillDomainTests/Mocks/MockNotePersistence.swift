//
//  MockNotePersistence.swift
//  Quill
//
//  Created by Ernesto on 8/6/26.
//

import Foundation
@testable import QuillDomain

/// In-memory ``ProtoNoteRepository`` for domain tests.
///
/// An actor, matching the real implementation's isolation, so tests exercise the
/// same `await` boundaries production code does.
actor MockNotePersistence: ProtoNoteRepository {
    private var storage: [UUID: Note] = [:]
    /// Recorded so tests can assert on batching — a sync round should write once,
    /// not once per note.
    private(set) var upsertCallCount = 0

    init(_ notes: [Note] = []) {
        storage = Dictionary(notes.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    func all(includingDeleted: Bool) async throws -> [Note] {
        let notes = Array(storage.values)
        return includingDeleted ? notes : notes.filter { !$0.isDeleted }
    }

    func note(id: UUID) async throws -> Note? { storage[id] }

    func upsert(_ notes: [Note]) async throws {
        upsertCallCount += 1
        for note in notes { storage[note.id] = note }
    }

    func purgeTombstones(deletedBefore date: Date) async throws {
        storage = storage.filter { _, note in
            guard let deletedAt = note.deletedAt else { return true }
            return deletedAt >= date
        }
    }
}

/// Frozen clock. Every timestamp in the domain comes from a `ProtoDateProvider`, which
/// is what lets these tests assert exact ordering instead of sleeping.
struct MockDateProvider: ProtoDateProvider {
    let now: Date
    init(_ now: Date = Date(timeIntervalSince1970: 1_700_000_000)) { self.now = now }
}

extension Note {
    /// Builder so tests read as the case under test, not as boilerplate.
    static func stub(
        id: UUID = UUID(),
        title: String = "Title",
        body: String = "Body",
        isPinned: Bool = false,
        updatedAt: TimeInterval = 100,
        deletedAt: TimeInterval? = nil
    ) -> Note {
        Note(
            id: id,
            title: title,
            body: body,
            isPinned: isPinned,
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: updatedAt),
            deletedAt: deletedAt.map(Date.init(timeIntervalSince1970:))
        )
    }
}
