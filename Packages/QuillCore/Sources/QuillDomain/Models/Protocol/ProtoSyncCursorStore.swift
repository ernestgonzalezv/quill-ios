//
//  ProtoSyncCursorStore.swift
//  Quill
//
//  Created by Ernesto on 8/8/26.
//

public import Foundation

/// Where the "last successful sync" watermark is kept.
///
/// Its own port because it has a different lifetime and failure mode from the
/// note store: losing the cursor should degrade to a full resync, not to data loss.
public protocol ProtoSyncCursorStore: Sendable {
    func lastSyncedAt() async -> Date?
    func setLastSyncedAt(_ date: Date?) async
}
