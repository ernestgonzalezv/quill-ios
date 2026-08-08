//
//  LogicDeleteNote.swift
//  Quill
//
//  Created by Ernesto on 8/8/26.
//

public import Foundation

public struct LogicDeleteNote: Sendable {
    private let repository: any ProtoNoteRepository
    private let dates: any ProtoDateProvider

    public init(repository: any ProtoNoteRepository, dates: any ProtoDateProvider) {
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
