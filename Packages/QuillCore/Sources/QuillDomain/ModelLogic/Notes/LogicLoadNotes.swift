//
//  LogicLoadNotes.swift
//  Quill
//
//  Created by Ernesto on 8/8/26.
//

internal import Foundation

public struct LogicLoadNotes: Sendable {
    private let repository: any ProtoNoteRepository
    private let order: NoteOrder

    public init(repository: any ProtoNoteRepository, order: NoteOrder = .pinnedThenRecent) {
        self.repository = repository
        self.order = order
    }

    public func callAsFunction(query: String = "") async throws -> [Note] {
        let notes = try await repository.all(includingDeleted: false)
        return order.sort(notes.filter { $0.matches(query: query) })
    }
}
