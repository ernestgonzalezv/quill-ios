//
//  CreateNoteIntent.swift
//  Quill
//
//  Created by Ernesto on 8/6/26.
//

import AppIntents
import QuillDomain

/// "Hey Siri, create a note in Quill."
///
/// Also appears in Shortcuts, on the Action button, and in Spotlight's actions
/// row — one `AppIntent` covers all of them.
///
/// `openAppWhenRun = false` is the interesting part: the note is written by
/// running the same ``LogicCreateNote`` use case the UI uses, against the same store,
/// without launching the app. That only works because the domain and data layers
/// have no dependency on a view hierarchy being alive.
struct CreateNoteIntent: AppIntent {
    static let title: LocalizedStringResource = "Create Note"
    static let description = IntentDescription(
        "Saves a new note in Quill without opening the app.",
        categoryName: "Notes"
    )
    static let openAppWhenRun = false

    @Parameter(
        title: "Note",
        inputOptions: String.IntentInputOptions(capitalizationType: .sentences, multiline: true),
        requestValueDialog: "What would you like the note to say?"
    )
    var text: String

    /// `@MainActor` because the composition root is main-actor isolated. The
    /// actual write happens on the repository's own actor, so nothing blocks here.
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            // Thrown rather than silently ignored so Siri asks again instead of
            // reporting success for a note that was never created.
            throw $text.needsValueError("What would you like the note to say?")
        }

        try await FactoryApp.shared.createNoteFromIntent(text: trimmed)
        return .result(dialog: "Saved to Quill.")
    }
}

/// Registers the intent as a zero-setup Siri phrase.
///
/// `\(.applicationName)` is required by App Intents — phrases must contain the app
/// name so Siri can disambiguate between apps offering similar actions.
struct QuillShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CreateNoteIntent(),
            phrases: [
                "Create a note in \(.applicationName)",
                "New note in \(.applicationName)",
                "Take a note with \(.applicationName)"
            ],
            shortTitle: "New Note",
            systemImageName: "square.and.pencil"
        )
    }
}
