//
//  LogicCreateNote.swift
//  Quill
//
//  Created by Ernesto on 8/8/26.
//

internal import Foundation

public struct LogicCreateNote: Sendable {
    private let repository: any ProtoNoteRepository
    private let dates: any ProtoDateProvider

    public init(repository: any ProtoNoteRepository, dates: any ProtoDateProvider) {
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
