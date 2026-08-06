public import Foundation
public import QuillDomain

/// Serialises sync rounds so the app can ask for one freely.
///
/// Sync is triggered from several places — app foreground, pull-to-refresh, every
/// local write — and those triggers overlap. Running two rounds concurrently
/// would have both pull the same delta, both compute a plan against a snapshot
/// the other is about to invalidate, and race on the cursor.
///
/// This actor **coalesces**: callers arriving while a round is in flight join it
/// and receive the same result instead of starting a second one. That makes
/// "sync after every keystroke-driven save" a safe thing to write at the call site.
public actor SyncCoordinator: NoteSynchronizing {
    private let syncNotes: SyncNotes
    private var inFlight: Task<SyncReport, any Error>?

    /// Result of the last completed round, for the UI's "Updated just now" label.
    public private(set) var lastOutcome: Outcome?

    public enum Outcome: Sendable {
        case succeeded(SyncReport, at: Date)
        case failed(message: String, at: Date)
    }

    public init(syncNotes: SyncNotes) {
        self.syncNotes = syncNotes
    }

    /// Runs a round, or joins the one already running.
    ///
    /// The join is why this is not simply `Task { }` at each call site: `await`ing
    /// the shared task gives every caller the same answer with one network round.
    @discardableResult
    public func sync() async throws -> SyncReport {
        if let inFlight {
            return try await inFlight.value
        }

        let task = Task { [syncNotes] in
            try await syncNotes()
        }
        inFlight = task

        do {
            let report = try await task.value
            inFlight = nil
            lastOutcome = .succeeded(report, at: Date())
            return report
        } catch {
            inFlight = nil
            // Cancellation is not a sync failure and must not be surfaced as one
            // in the UI — the user backgrounded the app or navigated away.
            if !(error is CancellationError) {
                lastOutcome = .failed(message: error.userFacingMessage, at: Date())
            }
            throw error
        }
    }

    /// Fire-and-forget variant for triggers that must not block the UI, such as
    /// syncing after a local edit. Errors are recorded in ``lastOutcome`` rather
    /// than thrown, because there is no caller left to handle them.
    public func syncInBackground() {
        Task { try? await sync() }
    }

    public func cancelInFlight() {
        inFlight?.cancel()
        inFlight = nil
    }
}

extension Error {
    /// A short message safe to show a user.
    ///
    /// Deliberately vague about server internals: a 500's body can contain stack
    /// traces or identifiers that should not reach a screenshot.
    var userFacingMessage: String {
        switch self {
        case let error as HTTPError:
            switch error {
            case .transport:
                "You appear to be offline. Your notes are saved on this device."
            case .unacceptableStatus(let code) where code == 401 || code == 403:
                "Your session expired. Sign in again to keep syncing."
            case .unacceptableStatus, .nonHTTPResponse, .decoding:
                "Sync is unavailable right now. Your notes are safe on this device."
            }
        default:
            "Sync is unavailable right now. Your notes are safe on this device."
        }
    }
}
