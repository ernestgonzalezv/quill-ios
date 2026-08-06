import Foundation

/// Triggering a sync, as the UI needs it.
///
/// The presentation layer must be able to ask for a refresh without importing
/// `QuillData` — otherwise every view model would transitively depend on
/// `URLSession` and SwiftData, and the feature module could no longer be built or
/// tested on its own. `SyncCoordinator` conforms to this from the other side.
public protocol NoteSynchronizing: Sendable {
    @discardableResult
    func sync() async throws -> SyncReport
}
