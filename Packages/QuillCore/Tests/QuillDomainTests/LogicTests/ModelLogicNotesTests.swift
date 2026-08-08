//
//  ModelLogicNotesTests.swift
//  Quill
//
//  Created by Ernesto on 8/6/26.
//

import Foundation
import Testing
@testable import QuillDomain

@Suite("Note use cases")
struct NoteUseCaseTests {
    private let clock = MockDateProvider()

    @Test("Creating stamps both timestamps from the injected clock")
    func createStampsTimestamps() async throws {
        let repository = MockNotePersistence()
        let note = try await LogicCreateNote(repository: repository, dates: clock)(
            NoteDraft(title: "  Groceries  ", body: "Milk")
        )

        #expect(note.title == "Groceries") // normalised at the boundary
        #expect(note.createdAt == clock.now)
        #expect(note.updatedAt == clock.now)
        #expect(try await repository.note(id: note.id) == note)
    }

    @Test("A blank draft is refused")
    func createRejectsBlank() async {
        let create = LogicCreateNote(repository: MockNotePersistence(), dates: clock)

        await #expect(throws: NoteError.blankNote) {
            try await create(NoteDraft(title: "   ", body: "\n"))
        }
    }

    /// Without this, merely opening and closing the editor would bump `updatedAt`
    /// and win a sync conflict against a real edit made on another device.
    @Test("An edit that changes nothing does not touch updatedAt")
    func noOpEditDoesNotBumpTimestamp() async throws {
        let existing = Note.stub(title: "Same", body: "Body", updatedAt: 50)
        let repository = MockNotePersistence([existing])

        let result = try await LogicUpdateNote(repository: repository, dates: clock)(
            id: existing.id,
            draft: NoteDraft(note: existing)
        )

        #expect(result.updatedAt == existing.updatedAt)
        #expect(await repository.upsertCallCount == 0)
    }

    @Test("Emptying a note in the editor deletes it")
    func emptyingDeletes() async throws {
        let existing = Note.stub()
        let repository = MockNotePersistence([existing])

        let result = try await LogicUpdateNote(repository: repository, dates: clock)(
            id: existing.id,
            draft: NoteDraft(title: "", body: "  ")
        )

        #expect(result.isDeleted)
    }

    @Test("Deleting leaves a content-free tombstone")
    func deleteClearsContent() async throws {
        let existing = Note.stub(title: "Secret", body: "Sensitive")
        let repository = MockNotePersistence([existing])

        try await LogicDeleteNote(repository: repository, dates: clock)(id: existing.id)
        let stored = try await repository.note(id: existing.id)

        #expect(stored?.isDeleted == true)
        // Cleared so deleted text cannot leak via a cache or the Spotlight index.
        #expect(stored?.title.isEmpty == true)
        #expect(stored?.body.isEmpty == true)
    }

    @Test("Deleting twice succeeds without error")
    func deleteIsIdempotent() async throws {
        let existing = Note.stub()
        let repository = MockNotePersistence([existing])
        let delete = LogicDeleteNote(repository: repository, dates: clock)

        try await delete(id: existing.id)
        try await delete(id: existing.id) // a retry, or a double tap
    }

    @Test("Missing notes surface as notFound")
    func missingNoteThrows() async {
        let id = UUID()
        let update = LogicUpdateNote(repository: MockNotePersistence(), dates: clock)

        await #expect(throws: NoteError.notFound(id)) {
            try await update(id: id, draft: NoteDraft(title: "x"))
        }
    }

    @Test("Loading excludes tombstones, orders pinned first, then most recent")
    func loadOrdersAndFilters() async throws {
        let pinnedOld = Note.stub(title: "Pinned", isPinned: true, updatedAt: 10)
        let recent = Note.stub(title: "Recent", updatedAt: 300)
        let older = Note.stub(title: "Older", updatedAt: 200)
        let deleted = Note.stub(title: "Gone", updatedAt: 400, deletedAt: 400)

        let notes = try await LogicLoadNotes(repository: MockNotePersistence([recent, pinnedOld, older, deleted]))()

        #expect(notes.map(\.title) == ["Pinned", "Recent", "Older"])
    }

    @Test("Search ignores case and diacritics")
    func searchIsInsensitive() async throws {
        let cafe = Note.stub(title: "Café", body: "")
        let load = LogicLoadNotes(repository: MockNotePersistence([cafe, Note.stub(title: "Other", body: "")]))

        #expect(try await load(query: "cafe").map(\.title) == ["Café"])
        #expect(try await load(query: "CAFÉ").map(\.title) == ["Café"])
    }

    @Test("Toggling a pin flips it and stamps the edit")
    func togglePin() async throws {
        let existing = Note.stub(isPinned: false, updatedAt: 10)
        let repository = MockNotePersistence([existing])

        let result = try await LogicTogglePin(repository: repository, dates: clock)(id: existing.id)

        #expect(result.isPinned)
        #expect(result.updatedAt == clock.now)
    }

    @Test("Deep links do not resolve to deleted notes")
    func loadNoteSkipsTombstones() async throws {
        let tombstone = Note.stub(deletedAt: 100)
        let load = LogicLoadNote(repository: MockNotePersistence([tombstone]))

        #expect(try await load(id: tombstone.id) == nil)
    }
}
