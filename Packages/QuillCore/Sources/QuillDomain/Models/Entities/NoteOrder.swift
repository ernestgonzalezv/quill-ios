//
//  NoteOrder.swift
//  Quill
//
//  Created by Ernesto on 8/6/26.
//

import Foundation

/// The one place that decides how notes are ordered on screen.
///
/// Sorting is a product rule, not a database detail, so it lives here and is
/// unit-tested directly. Putting it in a SwiftData `SortDescriptor` would tie it
/// to the store and make it untestable without a container.
public enum NoteOrder: Sendable {
    /// Pinned notes first, then most recently edited. Ties break on `id` so the
    /// order is total and the list never reshuffles between identical renders.
    case pinnedThenRecent

    public func sort(_ notes: [Note]) -> [Note] {
        switch self {
        case .pinnedThenRecent:
            notes.sorted { lhs, rhs in
                if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
                if lhs.updatedAt != rhs.updatedAt { return lhs.updatedAt > rhs.updatedAt }
                return lhs.id.uuidString < rhs.id.uuidString
            }
        }
    }
}
