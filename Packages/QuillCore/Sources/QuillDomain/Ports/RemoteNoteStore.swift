public import Foundation

/// The backend, as the domain needs it.
///
/// Deliberately narrow: two calls, both batched, both expressed in domain types.
/// HTTP verbs, JSON shapes, pagination and auth headers are the adapter's
/// problem, not the sync engine's.
public protocol RemoteNoteStore: Sendable {
    /// Everything changed on the server since `since` (all of it, when `nil`).
    ///
    /// Returns the server's own clock alongside the notes. The cursor advances to
    /// *server* time, never to device time — device clocks are wrong often enough
    /// that trusting them silently drops records from the next delta.
    func pull(since date: Date?) async throws -> RemoteChangeSet

    /// Uploads local changes and returns the notes as the server accepted them,
    /// so any server-side normalisation is written back locally.
    func push(_ notes: [Note]) async throws -> [Note]
}

public struct RemoteChangeSet: Hashable, Sendable {
    public var notes: [Note]
    public var serverTime: Date

    public init(notes: [Note], serverTime: Date) {
        self.notes = notes
        self.serverTime = serverTime
    }
}

/// Where the "last successful sync" watermark is kept.
///
/// Its own port because it has a different lifetime and failure mode from the
/// note store: losing the cursor should degrade to a full resync, not to data loss.
public protocol SyncCursorStore: Sendable {
    func lastSyncedAt() async -> Date?
    func setLastSyncedAt(_ date: Date?) async
}
