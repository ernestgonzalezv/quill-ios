import Foundation
internal import QuillDomain

/// Wire representation of a note.
///
/// Separate from ``Note`` so the API can rename a field, add one, or change a
/// date format without a single line changing in the domain or the UI. The two
/// types drifting apart is the point, not duplication to be removed.
struct NoteDTO: Codable, Hashable, Sendable {
    let id: UUID
    let title: String
    let body: String
    let isPinned: Bool
    let createdAt: Date
    let updatedAt: Date
    let deletedAt: Date?

    init(note: Note) {
        self.id = note.id
        self.title = note.title
        self.body = note.body
        self.isPinned = note.isPinned
        self.createdAt = note.createdAt
        self.updatedAt = note.updatedAt
        self.deletedAt = note.deletedAt
    }

    var domainModel: Note {
        Note(
            id: id,
            title: title,
            body: body,
            isPinned: isPinned,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt
        )
    }
}

/// The `GET /notes` envelope.
struct NotePageDTO: Codable, Hashable, Sendable {
    let notes: [NoteDTO]
    /// The server's clock at the moment it computed this page. The sync cursor
    /// advances to this, never to the device's clock — see ``SyncNotes``.
    let serverTime: Date
}

struct NotePushRequestDTO: Codable, Hashable, Sendable {
    let notes: [NoteDTO]
}

extension JSONDecoder {
    static func quill() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        // Tolerates both `2026-08-06T12:00:00Z` and `...12:00:00.123Z`: servers
        // emit fractional seconds inconsistently, and `.iso8601` rejects them.
        decoder.dateDecodingStrategy = .custom { decoder in
            let raw = try decoder.singleValueContainer().decode(String.self)
            guard let date = ISO8601.parse(raw) else {
                throw DecodingError.dataCorrupted(
                    .init(codingPath: decoder.codingPath, debugDescription: "Unparseable date: \(raw)")
                )
            }
            return date
        }
        return decoder
    }
}

extension JSONEncoder {
    static func quill() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        // Always sends fractional seconds. Millisecond precision is what makes
        // last-write-wins usable: whole-second timestamps make near-simultaneous
        // edits tie constantly and fall through to the tie-break rule.
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(ISO8601.format(date))
        }
        return encoder
    }
}

/// ISO-8601 conversion for the wire format.
///
/// Uses `Date.ISO8601FormatStyle` rather than `ISO8601DateFormatter`: the format
/// style is a `Sendable` value type, so it can live in a `static let` under strict
/// concurrency. `ISO8601DateFormatter` is a mutable reference type and a shared
/// instance of it is a data race the Swift 6 compiler rejects outright.
enum ISO8601 {
    private static let fractional = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
    private static let whole = Date.ISO8601FormatStyle(includingFractionalSeconds: false)

    /// Always emits fractional seconds — millisecond precision is what keeps
    /// last-write-wins from tying on near-simultaneous edits.
    static func format(_ date: Date) -> String {
        fractional.format(date)
    }

    /// Fractional first, since that is what this API emits; whole-second as a
    /// fallback because plenty of servers omit the fraction inconsistently.
    static func parse(_ string: String) -> Date? {
        if let date = try? fractional.parse(string) { return date }
        return try? whole.parse(string)
    }
}
