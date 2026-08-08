//
//  NoteDraft.swift
//  Quill
//
//  Created by Ernesto on 8/6/26.
//

import Foundation

/// The editable surface of a note.
///
/// The editor binds to a draft rather than to a ``Note`` so that unsaved typing
/// can never reach the store, and so `id`/`createdAt`/`updatedAt` stay
/// unforgeable from the UI layer.
public struct NoteDraft: Hashable, Sendable {
    public var title: String
    public var body: String
    public var isPinned: Bool

    public init(title: String = "", body: String = "", isPinned: Bool = false) {
        self.title = title
        self.body = body
        self.isPinned = isPinned
    }

    public init(note: Note) {
        self.init(title: note.title, body: note.body, isPinned: note.isPinned)
    }

    public var isBlank: Bool {
        title.trimmedOrNil == nil && body.trimmedOrNil == nil
    }

    /// Normalises user input once, at the boundary, instead of trimming
    /// defensively at every read site.
    public var normalized: Self {
        Self(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            body: body.trimmingCharacters(in: .whitespacesAndNewlines),
            isPinned: isPinned
        )
    }
}
