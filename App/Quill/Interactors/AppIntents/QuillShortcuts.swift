//
//  QuillShortcuts.swift
//  Quill
//
//  Created by Ernesto on 8/8/26.
//

import AppIntents
import QuillDomain

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
