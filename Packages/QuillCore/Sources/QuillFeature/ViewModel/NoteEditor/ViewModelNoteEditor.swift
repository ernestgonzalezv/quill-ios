//
//  ViewModelNoteEditor.swift
//  Quill
//
//  Created by Ernesto on 8/6/26.
//

public import Foundation
public import QuillDomain

/// Drives the note editor, with debounced autosave.
///
/// Autosave rather than an explicit Save button, because a notes app that can lose
/// text to a force-quit is broken. The debounce exists so a paragraph of typing is
/// a handful of writes instead of one per character, and ``flush()`` guarantees
/// the last keystroke is committed even if the user leaves inside the debounce
/// window.
@MainActor
@Observable
public final class ViewModelNoteEditor {
    public private(set) var noteID: UUID
    public var draft: NoteDraft {
        didSet {
            guard draft != oldValue else { return }
            scheduleAutosave()
        }
    }

    public private(set) var errorMessage: String?
    /// Surfaces the moment the last successful write landed, so the view can show
    /// a subtle "Saved" affordance instead of leaving the user unsure.
    public private(set) var lastSavedAt: Date?

    private let updateNote: LogicUpdateNote
    private let autosaveDelay: Duration
    private var autosaveTask: Task<Void, Never>?

    public init(
        note: Note,
        updateNote: LogicUpdateNote,
        autosaveDelay: Duration = .milliseconds(600)
    ) {
        self.noteID = note.id
        self.draft = NoteDraft(note: note)
        self.updateNote = updateNote
        self.autosaveDelay = autosaveDelay
    }

    // See `ViewModelNoteList` for why there is no `deinit` here: the autosave task
    // holds `self` weakly, and `flush()` is the real guarantee that pending text
    // is committed.

    /// Cancels any pending autosave and writes immediately.
    ///
    /// Must be called from `onDisappear` and on scene backgrounding. Without it,
    /// the debounce window is exactly the window in which typing is lost.
    public func flush() async {
        autosaveTask?.cancel()
        autosaveTask = nil
        await save()
    }

    public func save() async {
        do {
            try await updateNote(id: noteID, draft: draft)
            lastSavedAt = Date()
            errorMessage = nil
        } catch NoteError.notFound {
            // Deleted underneath us — from another device, or by a swipe in the
            // list while this screen was still open. Recreating it would resurrect
            // a note the user deleted, so the edit is dropped and said out loud.
            let comment = "Error cuando la nota se borró en otro dispositivo mientras se editaba"
            errorMessage = Language.getLanguageString(key: "PHRASE_NOTE_DELETED_ELSEWHERE", comment: comment)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func scheduleAutosave() {
        autosaveTask?.cancel()
        autosaveTask = Task { [weak self, autosaveDelay] in
            try? await Task.sleep(for: autosaveDelay)
            guard !Task.isCancelled else { return }
            await self?.save()
        }
    }
}
