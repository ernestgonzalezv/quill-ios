//
//  LogicUpdateNote.swift
//  Quill
//
//  Created by Ernesto on 8/8/26.
//

public import Foundation

public struct LogicUpdateNote: Sendable {
    private let repository: any ProtoNoteRepository
    private let dates: any ProtoDateProvider

    public init(repository: any ProtoNoteRepository, dates: any ProtoDateProvider) {
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
