import Foundation
import SwiftData
internal import QuillDomain

/// The SwiftData row backing a ``Note``.
///
/// Kept `internal` on purpose: no consumer outside this module should ever hold a
/// `@Model` object. `@Model` instances are bound to the `ModelContext` that
/// fetched them and are not `Sendable`, so leaking one across an actor boundary
/// is a data race the type system cannot always catch. The repository maps to
/// value-type ``Note`` before returning, which makes that mistake impossible.
@Model
final class NoteEntity {
    /// Enforced by the store rather than by convention, so a bug in `upsert`
    /// surfaces as a constraint violation instead of silently duplicating a note.
    #Unique<NoteEntity>([\.id])

    /// Indexed because every list read filters on `deletedAt` and orders on
    /// `updatedAt`; without these the store table-scans on each keystroke.
    #Index<NoteEntity>([\.updatedAt], [\.deletedAt])

    private(set) var id: UUID
    var title: String
    var bodyText: String
    var isPinned: Bool
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?

    init(note: Note) {
        self.id = note.id
        self.title = note.title
        self.bodyText = note.body
        self.isPinned = note.isPinned
        self.createdAt = note.createdAt
        self.updatedAt = note.updatedAt
        self.deletedAt = note.deletedAt
    }
}

extension NoteEntity {
    var domainModel: Note {
        Note(
            id: id,
            title: title,
            body: bodyText,
            isPinned: isPinned,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt
        )
    }

    /// Overwrites mutable columns from a domain value. `id` and `createdAt` are
    /// identity and are never reassigned — a note that changed either would be a
    /// different note.
    func apply(_ note: Note) {
        title = note.title
        bodyText = note.body
        isPinned = note.isPinned
        updatedAt = note.updatedAt
        deletedAt = note.deletedAt
    }
}
