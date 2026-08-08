//
//  Note.swift
//  Quill
//
//  Created by Ernesto on 8/6/26.
//

public import Foundation

/// A note as the rest of the app understands it.
///
/// This is a value type with no persistence or transport concerns attached: no
/// `@Model`, no `Codable`. SwiftData and JSON representations live in `QuillData`
/// and map to and from this type, which keeps storage and API changes from
/// leaking into the domain rules or the UI.
///
/// Deletes are **soft**. A note with a non-nil ``deletedAt`` is a tombstone: it
/// stays in the store so the sync engine can propagate the deletion to other
/// devices instead of the note reappearing on the next pull.
public struct Note: Identifiable, Hashable, Sendable {
    public let id: UUID
    public var title: String
    public var body: String
    public var isPinned: Bool
    public let createdAt: Date
    public var updatedAt: Date
    public var deletedAt: Date?

    public init(
        id: UUID = UUID(),
        title: String = "",
        body: String = "",
        isPinned: Bool = false,
        createdAt: Date,
        updatedAt: Date,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.isPinned = isPinned
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
    }
}

public extension Note {
    var isDeleted: Bool { deletedAt != nil }

    /// True when the user has typed nothing worth keeping. Used to discard
    /// notes opened and abandoned in the editor.
    var isBlank: Bool {
        title.trimmedOrNil == nil && body.trimmedOrNil == nil
    }

    /// What the list shows as a heading. Falls back to the first non-empty line
    /// of the body so a note is never rendered as a blank row.
    var displayTitle: String {
        if let title = title.trimmedOrNil { return title }
        if let firstLine = body.split(whereSeparator: \.isNewline).first,
           let trimmed = String(firstLine).trimmedOrNil {
            return trimmed
        }
        return ""
    }

    /// Single-line preview, collapsed and clipped for the list row.
    func snippet(limit: Int = 120) -> String {
        let collapsed = body
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
        guard collapsed.count > limit else { return collapsed }
        return String(collapsed.prefix(limit)) + "…"
    }

    /// Case- and diacritic-insensitive match, so `cafe` finds `Café`.
    /// Matching lives in the domain because it is a rule, not a SwiftData
    /// predicate detail — and it is the same rule offline and online.
    func matches(query: String) -> Bool {
        guard let needle = query.trimmedOrNil else { return true }
        let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
        return title.range(of: needle, options: options) != nil
            || body.range(of: needle, options: options) != nil
    }

    /// Returns a copy stamped as edited at `date`. Every mutation goes through a
    /// method like this so `updatedAt` can never silently drift out of date —
    /// which would break last-write-wins conflict resolution.
    func edited(with draft: NoteDraft, at date: Date) -> Note {
        var copy = self
        copy.title = draft.title
        copy.body = draft.body
        copy.isPinned = draft.isPinned
        copy.updatedAt = date
        return copy
    }

    func pinned(_ value: Bool, at date: Date) -> Note {
        var copy = self
        copy.isPinned = value
        copy.updatedAt = date
        return copy
    }

    /// Turns the note into a tombstone. Content is cleared so a deleted note
    /// cannot leak its text through a stale cache or a search index.
    func deleted(at date: Date) -> Note {
        var copy = self
        copy.title = ""
        copy.body = ""
        copy.isPinned = false
        copy.deletedAt = date
        copy.updatedAt = date
        return copy
    }
}

extension String {
    /// `nil` instead of `""` for whitespace-only input, so callers can use
    /// `if let` rather than repeating `.trimmingCharacters(in:).isEmpty`.
    var trimmedOrNil: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
