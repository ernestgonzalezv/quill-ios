public import Foundation

/// Injectable source of "now".
///
/// Named `DateProvider` rather than `Clock` to avoid colliding with the standard
/// library's `Clock` protocol. Every timestamp in the app comes from here, which
/// is what makes last-write-wins conflict resolution testable: a test can pin
/// time and assert exact ordering instead of sleeping.
public protocol DateProvider: Sendable {
    var now: Date { get }
}

public struct SystemDateProvider: DateProvider {
    public init() {}
    public var now: Date { Date() }
}
