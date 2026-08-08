//
//  ISO8601.swift
//  Quill
//
//  Created by Ernesto on 8/8/26.
//

import Foundation
internal import QuillDomain

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
