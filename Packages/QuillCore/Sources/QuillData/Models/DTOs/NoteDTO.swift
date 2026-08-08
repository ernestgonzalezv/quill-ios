//
//  NoteDTO.swift
//  Quill
//
//  Created by Ernesto on 8/6/26.
//

import Foundation
internal import QuillDomain

/// Wire representation of a note.
///
/// Separate from ``Note`` so the API can rename a field, add one, or change a
/// date format without a single line changing in the domain or the UI. The two
/// types drifting apart is the point, not duplication to be removed.
struct NoteDTO: Codable, Hashable, Sendable {
    let id: UUID
    let title: String
    let body: String
    let isPinned: Bool
    let createdAt: Date
    let updatedAt: Date
    let deletedAt: Date?

    init(note: Note) {
        self.id = note.id
        self.title = note.title
        self.body = note.body
        self.isPinned = note.isPinned
        self.createdAt = note.createdAt
        self.updatedAt = note.updatedAt
        self.deletedAt = note.deletedAt
    }

    var domainModel: Note {
        Note(
            id: id,
            title: title,
            body: body,
            isPinned: isPinned,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt
        )
    }
}
/// The `GET /notes` envelope.
struct NotePageDTO: Codable, Hashable, Sendable {
    let notes: [NoteDTO]
    /// The server's clock at the moment it computed this page. The sync cursor
    /// advances to this, never to the device's clock — see ``LogicSyncNotes``.
    let serverTime: Date
}
struct NotePushRequestDTO: Codable, Hashable, Sendable {
    let notes: [NoteDTO]
}
