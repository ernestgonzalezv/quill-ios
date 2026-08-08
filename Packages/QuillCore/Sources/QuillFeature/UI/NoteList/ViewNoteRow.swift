//
//  ViewNoteRow.swift
//  Quill
//
//  Created by Ernesto on 8/6/26.
//

import SwiftUI
internal import QuillDomain

/// One row in the notes list.
///
/// Layout notes that are not cosmetic:
///
/// - No fixed heights or `.lineLimit(1)` on the title. The row grows with Dynamic
///   Type, so at accessibility text sizes the content is still readable rather
///   than clipped mid-word.
/// - The date/preview line switches from horizontal to vertical past the
///   accessibility size threshold, because two columns of large text do not fit.
/// - The whole row is one accessibility element with a composed label, so
///   VoiceOver reads "Pinned. Groceries. Milk, eggs. Edited 2 hours ago" as a
///   single utterance instead of four separate swipes.
struct ViewNoteRow: View {
    let note: Note
    /// Opcional para que un Preview pueda pasar `nil` y renderizar la fila sin
    /// montar el view model entero.
    let delegate: (any DelegateUINoteRow)?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                if note.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        // Decorative: the pinned state is already in the row's
                        // accessibility label, and reading it twice is noise.
                        .accessibilityHidden(true)
                }
                Text(title)
                    .font(.headline)
            }

            if !note.snippet().isEmpty {
                Text(note.snippet(limit: 100))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Text(note.updatedAt, format: .relative(presentation: .named))
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, dynamicTypeSize.isAccessibilitySize ? 8 : 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                delegate?.noteRowDelete(note)
            } label: {
                Label { Text(textDelete) } icon: { Image(systemName: "trash") }
            }
        }
        .swipeActions(edge: .leading) {
            Button {
                delegate?.noteRowTogglePin(note)
            } label: {
                Label { Text(textPin) } icon: { Image(systemName: note.isPinned ? "pin.slash" : "pin") }
            }
            .tint(.orange)
        }
        // Los swipes son invisibles para VoiceOver y Switch Control, así que las
        // mismas dos acciones se exponen también como acciones de accesibilidad.
        .accessibilityActions {
            Button(textPin) { delegate?.noteRowTogglePin(note) }
            Button(textDelete) { delegate?.noteRowDelete(note) }
        }
    }

    private var title: String {
        // Falls back so a body-only note is never an empty-looking row.
        let untitled = Language.getLanguageString(key: "WORD_UNTITLED", comment: "Título por defecto de una nota sin título")
        return note.displayTitle.isEmpty ? untitled : note.displayTitle
    }

    private var textDelete: String {
        Language.getLanguageString(key: "WORD_DELETE", comment: "Acción de eliminar una nota")
    }

    private var textPin: String {
        let key = note.isPinned ? "WORD_UNPIN" : "WORD_PIN"
        return Language.getLanguageString(key: key, comment: "Acción de fijar o dejar de fijar una nota en la lista")
    }

    private var accessibilityLabel: String {
        var parts: [String] = []
        if note.isPinned {
            parts.append(Language.getLanguageString(key: "WORD_PINNED", comment: "Estado fijado, leído por VoiceOver"))
        }
        parts.append(title)
        let snippet = note.snippet(limit: 100)
        if !snippet.isEmpty { parts.append(snippet) }
        parts.append(note.updatedAt.formatted(.relative(presentation: .named)))
        return parts.joined(separator: ". ")
    }
}

#if DEBUG
// El delegate va en `nil`: la fila se dibuja sin montar el view model, que es
// exactamente para lo que se declaró Optional.
#Preview("Fila") {
    List {
        ForEach(Note.previewSamples) { note in
            ViewNoteRow(note: note, delegate: nil)
        }
    }
}

#Preview("Fila · texto grande") {
    List {
        ViewNoteRow(note: .preview, delegate: nil)
    }
    .environment(\.dynamicTypeSize, .accessibility3)
}
#endif
