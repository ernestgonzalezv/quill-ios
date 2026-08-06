public import Foundation

// Use cases are small structs with a single `callAsFunction`, so a call site
// reads `try await createNote(draft)` and a view model can declare exactly the
// capabilities it needs instead of taking a fat service object. Each one is
// independently constructible in a test with fakes for its two or three deps.

/// Creates a note from user input, rejecting blank drafts.
public struct CreateNote: Sendable {
    private let repository: any NoteRepository
    private let dates: any DateProvider

    public init(repository: any NoteRepository, dates: any DateProvider) {
        self.repository = repository
        self.dates = dates
    }

    @discardableResult
    public func callAsFunction(_ draft: NoteDraft) async throws -> Note {
        let draft = draft.normalized
        guard !draft.isBlank else { throw NoteError.blankNote }

        let now = dates.now
        let note = Note(
            title: draft.title,
            body: draft.body,
            isPinned: draft.isPinned,
            createdAt: now,
            updatedAt: now
        )
        try await repository.upsert([note])
        return note
    }
}

/// Applies an edit to an existing note.
///
/// A draft that has been emptied deletes the note rather than leaving a blank
/// row behind — matching how Apple Notes behaves, and avoiding a state where the
/// list shows an untappable empty cell.
public struct UpdateNote: Sendable {
    private let repository: any NoteRepository
    private let dates: any DateProvider

    public init(repository: any NoteRepository, dates: any DateProvider) {
        self.repository = repository
        self.dates = dates
    }

    @discardableResult
    public func callAsFunction(id: UUID, draft: NoteDraft) async throws -> Note {
        guard let existing = try await repository.note(id: id), !existing.isDeleted else {
            throw NoteError.notFound(id)
        }

        let draft = draft.normalized

        // Compared *before* stamping, and on the draft rather than the note.
        // `edited(with:at:)` always writes a fresh `updatedAt`, so comparing the
        // resulting notes would never find them equal — and merely opening and
        // closing the editor would bump the timestamp and win a sync conflict
        // against a real edit made on another device.
        guard NoteDraft(note: existing) != draft else { return existing }

        let updated = draft.isBlank
            ? existing.deleted(at: dates.now)
            : existing.edited(with: draft, at: dates.now)

        try await repository.upsert([updated])
        return updated
    }
}

/// Soft-deletes a note, leaving a tombstone for sync to propagate.
public struct DeleteNote: Sendable {
    private let repository: any NoteRepository
    private let dates: any DateProvider

    public init(repository: any NoteRepository, dates: any DateProvider) {
        self.repository = repository
        self.dates = dates
    }

    public func callAsFunction(id: UUID) async throws {
        guard let existing = try await repository.note(id: id) else {
            throw NoteError.notFound(id)
        }
        // Deleting twice is a no-op, not an error: the second tap of a delete
        // button, or a retry after a dropped connection, should both succeed.
        guard !existing.isDeleted else { return }

        try await repository.upsert([existing.deleted(at: dates.now)])
    }
}

public struct TogglePin: Sendable {
    private let repository: any NoteRepository
    private let dates: any DateProvider

    public init(repository: any NoteRepository, dates: any DateProvider) {
        self.repository = repository
        self.dates = dates
    }

    @discardableResult
    public func callAsFunction(id: UUID) async throws -> Note {
        guard let existing = try await repository.note(id: id), !existing.isDeleted else {
            throw NoteError.notFound(id)
        }
        let updated = existing.pinned(!existing.isPinned, at: dates.now)
        try await repository.upsert([updated])
        return updated
    }
}

/// Reads the visible notes, filtered and ordered.
///
/// Filtering happens in the domain rather than as a store query so the exact
/// same rule applies to a SwiftData-backed run and to a test with a fake — and
/// so search behaviour is not silently different from `Note.matches(query:)`.
public struct LoadNotes: Sendable {
    private let repository: any NoteRepository
    private let order: NoteOrder

    public init(repository: any NoteRepository, order: NoteOrder = .pinnedThenRecent) {
        self.repository = repository
        self.order = order
    }

    public func callAsFunction(query: String = "") async throws -> [Note] {
        let notes = try await repository.all(includingDeleted: false)
        return order.sort(notes.filter { $0.matches(query: query) })
    }
}
