//
//  NoteError.swift
//  Quill
//
//  Created by Ernesto on 8/6/26.
//

public import Foundation

/// Errors the domain itself can raise.
///
/// Deliberately small and `Equatable` so tests assert on cases rather than on
/// error strings. Infrastructure failures (HTTP, disk) are *not* modelled here —
/// adapters in `QuillData` map those into their own error types, and the UI
/// treats anything it does not recognise as a generic retryable failure.
public enum NoteError: Error, Equatable, Sendable {
    /// A note id reached a use case but no longer exists locally — normally the
    /// result of a delete racing an edit on another device.
    case notFound(UUID)

    /// Refused to create a note with neither a title nor a body.
    case blankNote
}
