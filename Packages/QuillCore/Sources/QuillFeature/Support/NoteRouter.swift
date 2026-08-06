public import Foundation

/// Lets code outside the view hierarchy ask for a note to be opened.
///
/// Deep links arrive at the `App` level — a Spotlight result, a Siri shortcut —
/// where there is no access to the navigation path held privately by
/// ``NoteListView``. Rather than lifting the whole path into the app layer (which
/// would leak navigation structure into the composition root), the app publishes
/// an *intent to navigate* here and the view reacts to it.
///
/// The request is consumed rather than merely read, so returning to the list does
/// not immediately re-push the same note.
@MainActor
@Observable
public final class NoteRouter {
    public private(set) var pendingNoteID: UUID?

    public init() {}

    public func requestOpen(noteID: UUID) {
        pendingNoteID = noteID
    }

    /// Returns the pending id exactly once.
    public func consumePendingNoteID() -> UUID? {
        defer { pendingNoteID = nil }
        return pendingNoteID
    }
}
