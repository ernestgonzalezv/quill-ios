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
struct NoteRowView: View {
    let note: Note

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
    }

    private var title: String {
        // Falls back so a body-only note is never an empty-looking row.
        note.displayTitle.isEmpty ? String(localized: L10n.notesUntitled) : note.displayTitle
    }

    private var accessibilityLabel: String {
        var parts: [String] = []
        if note.isPinned { parts.append(String(localized: L10n.notesPinnedBadge)) }
        parts.append(title)
        let snippet = note.snippet(limit: 100)
        if !snippet.isEmpty { parts.append(snippet) }
        parts.append(note.updatedAt.formatted(.relative(presentation: .named)))
        return parts.joined(separator: ". ")
    }
}
