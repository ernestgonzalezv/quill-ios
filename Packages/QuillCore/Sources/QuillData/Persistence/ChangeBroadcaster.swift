import Foundation
import Synchronization

/// Fan-out of "the store changed" notifications to any number of listeners.
///
/// `AsyncStream` is single-consumer: a second `for await` on the same stream
/// competes for elements instead of receiving its own copy. Since both the list
/// screen and the Spotlight indexer need to react to every write, each caller
/// gets its own stream and this type multiplexes into all of them.
///
/// Uses `Mutex` rather than an actor because `send` is called from synchronous,
/// already-isolated repository code — making the broadcaster an actor would force
/// those call sites to `await` and reorder notifications relative to the writes
/// that caused them.
final class ChangeBroadcaster: Sendable {
    private struct State {
        var continuations: [UUID: AsyncStream<Void>.Continuation] = [:]
    }

    private let state = Mutex(State())

    /// A fresh stream for one consumer. Buffers a single element and drops the
    /// rest: listeners re-read the full state on every tick, so N queued ticks
    /// and one tick lead to the same result, and an idle listener cannot make the
    /// buffer grow without bound.
    func stream() -> AsyncStream<Void> {
        let id = UUID()
        return AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            state.withLock { $0.continuations[id] = continuation }
            continuation.onTermination = { [weak self] _ in
                self?.state.withLock { $0.continuations[id] = nil }
            }
        }
    }

    func send() {
        // Copy under the lock, yield outside it: `yield` can synchronously resume
        // a consumer, and resuming while holding the lock risks re-entrancy.
        let listeners = state.withLock { Array($0.continuations.values) }
        for listener in listeners { listener.yield() }
    }

    func finish() {
        let listeners = state.withLock { state -> [AsyncStream<Void>.Continuation] in
            let all = Array(state.continuations.values)
            state.continuations.removeAll()
            return all
        }
        for listener in listeners { listener.finish() }
    }
}
