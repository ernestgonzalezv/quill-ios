//
//  LogicLoadNote.swift
//  Quill
//
//  Created by Ernesto on 8/6/26.
//

public import Foundation

/// Reads a single note by id.
///
/// Exists as its own use case because deep links — a Spotlight result, a Siri
/// shortcut, a future widget tap — arrive with an id and nothing else, and must
/// not be able to reach the repository directly just to resolve one row.
///
/// Tombstones are filtered out here rather than by the caller: opening an editor
/// on a deleted note is never correct, and forgetting the check at one of several
/// deep-link entry points would be easy.
public struct LogicLoadNote: Sendable {
    private let repository: any ProtoNoteRepository

    public init(repository: any ProtoNoteRepository) {
        self.repository = repository
    }

    public func callAsFunction(id: UUID) async throws -> Note? {
        guard let note = try await repository.note(id: id), !note.isDeleted else { return nil }
        return note
    }
}
