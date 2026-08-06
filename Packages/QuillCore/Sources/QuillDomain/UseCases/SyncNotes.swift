public import Foundation

/// One full sync round: pull, reconcile, write, push, advance the cursor.
///
/// The order matters and is the whole design:
///
/// 1. **Pull** the remote delta since the stored cursor.
/// 2. **Read** the complete local snapshot *including tombstones* — without them
///    a local delete looks like an absent note and the remote copy resurrects it.
/// 3. **Merge** via ``NoteMerger`` (pure, testable, no I/O).
/// 4. **Write** remote winners locally *before* pushing. If the push then fails,
///    the device is still strictly closer to the server than it was, and the
///    next round is smaller rather than starting over.
/// 5. **Push** local winners and persist the server's canonical response.
/// 6. **Advance the cursor to server time**, and only on success — a thrown error
///    leaves the watermark untouched so the next attempt re-pulls the same delta.
///    Every step is therefore idempotent: replaying a round converges.
public struct SyncNotes: Sendable {
    private let repository: any NoteRepository
    private let remote: any RemoteNoteStore
    private let cursor: any SyncCursorStore
    private let merger: NoteMerger
    private let tombstoneLifetime: TimeInterval

    /// - Parameter tombstoneLifetime: how long a tombstone is kept after a
    ///   successful sync. Must comfortably exceed the longest plausible offline
    ///   stretch for another device, or that device's stale copy will resurrect a
    ///   deleted note. 30 days by default.
    public init(
        repository: any NoteRepository,
        remote: any RemoteNoteStore,
        cursor: any SyncCursorStore,
        merger: NoteMerger = NoteMerger(),
        tombstoneLifetime: TimeInterval = 60 * 60 * 24 * 30
    ) {
        self.repository = repository
        self.remote = remote
        self.cursor = cursor
        self.merger = merger
        self.tombstoneLifetime = tombstoneLifetime
    }

    @discardableResult
    public func callAsFunction() async throws -> SyncReport {
        let since = await cursor.lastSyncedAt()
        let changeSet = try await remote.pull(since: since)

        let localSnapshot = try await repository.all(includingDeleted: true)
        let plan = merger.merge(local: localSnapshot, remote: changeSet.notes)

        if !plan.toStoreLocally.isEmpty {
            try await repository.upsert(plan.toStoreLocally)
        }

        var pushed: [Note] = []
        if !plan.toPushRemotely.isEmpty {
            pushed = try await remote.push(plan.toPushRemotely)
            // The server is authoritative on what it stored; write its version
            // back so local and remote agree byte-for-byte before the cursor moves.
            if !pushed.isEmpty {
                try await repository.upsert(pushed)
            }
        }

        await cursor.setLastSyncedAt(changeSet.serverTime)

        // Best-effort cleanup. A failure here means the store is slightly larger
        // than ideal, which must not fail a sync that already succeeded.
        try? await repository.purgeTombstones(
            deletedBefore: changeSet.serverTime.addingTimeInterval(-tombstoneLifetime)
        )

        return SyncReport(pulled: plan.toStoreLocally.count, pushed: pushed.count)
    }
}

public struct SyncReport: Hashable, Sendable {
    public var pulled: Int
    public var pushed: Int

    public init(pulled: Int = 0, pushed: Int = 0) {
        self.pulled = pulled
        self.pushed = pushed
    }

    public var didChangeAnything: Bool { pulled > 0 || pushed > 0 }
}
