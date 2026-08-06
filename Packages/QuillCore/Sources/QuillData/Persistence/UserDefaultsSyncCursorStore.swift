public import Foundation
public import QuillDomain

/// Stores the sync watermark in `UserDefaults`.
///
/// `UserDefaults` rather than the SwiftData store because the cursor must be
/// readable and writable even when the store is mid-migration or failed to open,
/// and because losing it is designed to be recoverable: a missing cursor means
/// "full resync", which is slow but always correct.
public struct UserDefaultsSyncCursorStore: SyncCursorStore {
    /// `UserDefaults` is documented as thread-safe but is not marked `Sendable`,
    /// so the exemption is stated explicitly here rather than by making the whole
    /// type an actor for a two-field read.
    private nonisolated(unsafe) let defaults: UserDefaults
    private let key: String

    public init(defaults: UserDefaults = .standard, key: String = "sync.notes.lastSyncedAt") {
        self.defaults = defaults
        self.key = key
    }

    public func lastSyncedAt() async -> Date? {
        // `object(forKey:)` distinguishes "never synced" from "synced at epoch";
        // `double(forKey:)` returns 0 for both and would silently skip the delta.
        guard let seconds = defaults.object(forKey: key) as? Double else { return nil }
        return Date(timeIntervalSince1970: seconds)
    }

    public func setLastSyncedAt(_ date: Date?) async {
        guard let date else {
            defaults.removeObject(forKey: key)
            return
        }
        defaults.set(date.timeIntervalSince1970, forKey: key)
    }
}
