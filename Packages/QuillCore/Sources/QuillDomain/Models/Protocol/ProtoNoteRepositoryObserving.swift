//
//  ProtoNoteRepositoryObserving.swift
//  Quill
//
//  Created by Ernesto on 8/8/26.
//

public import Foundation

/// A stream of change notifications, kept separate from ``ProtoNoteRepository`` so a
/// store that cannot observe (a fake, a read-only mirror) is not forced to fake it.
public protocol ProtoNoteRepositoryObserving: Sendable {
    /// Emits once per committed write. Carries no payload: observers re-read
    /// through the repository, which keeps a single source of truth instead of
    /// letting the stream become a second, racier one.
    var changes: AsyncStream<Void> { get }
}
