//
//  LogicTogglePin.swift
//  Quill
//
//  Created by Ernesto on 8/8/26.
//

public import Foundation

public struct LogicTogglePin: Sendable {
    private let repository: any ProtoNoteRepository
    private let dates: any ProtoDateProvider

    public init(repository: any ProtoNoteRepository, dates: any ProtoDateProvider) {
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
