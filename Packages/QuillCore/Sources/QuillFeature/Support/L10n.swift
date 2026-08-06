import Foundation

/// Type-safe access to the module's localised strings.
///
/// Two reasons this is an enum of constants rather than raw `"some.key"` literals
/// at call sites:
///
/// 1. A renamed or deleted key becomes a **compile error** instead of a string
///    that silently renders as its own key in production.
/// 2. Strings in a Swift package do not resolve against `Bundle.main`. Every
///    lookup has to name `Bundle.module`, and centralising that means no view can
///    forget it and ship an untranslated screen.
enum L10n {
    static let notesTitle = resource("notes.title")
    static let notesSearchPrompt = resource("notes.search.prompt")
    static let notesEmptyTitle = resource("notes.empty.title")
    static let notesEmptyMessage = resource("notes.empty.message")
    static let notesNoResultsTitle = resource("notes.noResults.title")
    static let notesNewNote = resource("notes.newNote")
    static let notesDelete = resource("notes.delete")
    static let notesPin = resource("notes.pin")
    static let notesUnpin = resource("notes.unpin")
    static let notesRetry = resource("notes.retry")
    static let notesUntitled = resource("notes.untitled")
    static let notesPinnedBadge = resource("notes.pinned.badge")

    static let editorTitlePlaceholder = resource("editor.title.placeholder")
    static let editorBodyPlaceholder = resource("editor.body.placeholder")
    static let editorDone = resource("editor.done")
    static let editorNewTitle = resource("editor.new.title")
    static let editorNoteDeletedElsewhere = resource("editor.error.deletedElsewhere")

    static let syncSyncing = resource("sync.syncing")
    static let syncUpToDate = resource("sync.upToDate")

    static func notesCount(_ count: Int) -> LocalizedStringResource {
        // Pluralisation lives in the string catalog's variations, not in Swift —
        // `count == 1 ? "note" : "notes"` is wrong in most languages.
        LocalizedStringResource("notes.count", defaultValue: "\(count)", bundle: .atURL(Bundle.module.bundleURL))
    }

    private static func resource(_ key: String.LocalizationValue) -> LocalizedStringResource {
        LocalizedStringResource(key, bundle: .atURL(Bundle.module.bundleURL))
    }
}
