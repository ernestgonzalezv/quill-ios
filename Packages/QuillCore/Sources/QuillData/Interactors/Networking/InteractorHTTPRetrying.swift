//
//  InteractorHTTPRetrying.swift
//  Quill
//
//  Created by Ernesto on 8/6/26.
//

public import Foundation

/// How many times to retry, and how long to wait between attempts.
///
/// Exponential backoff with **full jitter**. Jitter is not cosmetic: without it,
/// every client knocked offline by the same outage retries in lockstep and
/// hammers the server the instant it recovers.
public struct RetryPolicy: Hashable, Sendable {
    public var maxAttempts: Int
    public var baseDelay: Duration
    public var multiplier: Double
    public var maxDelay: Duration

    public init(
        maxAttempts: Int = 3,
        baseDelay: Duration = .milliseconds(300),
        multiplier: Double = 2.0,
        maxDelay: Duration = .seconds(8)
    ) {
        self.maxAttempts = max(1, maxAttempts)
        self.baseDelay = baseDelay
        self.multiplier = multiplier
        self.maxDelay = maxDelay
    }

    public static let none = Self(maxAttempts: 1)

    /// Delay before `attempt` (1-based).
    ///
    /// - Parameter randomness: the jitter fraction, in `0...1`. Injected rather
    ///   than drawn internally so tests are deterministic: pass `1` for the full
    ///   delay, `0` for none.
    public func delay(beforeAttempt attempt: Int, randomness: Double) -> Duration {
        guard attempt > 1 else { return .zero }

        let exponent = Double(attempt - 2)
        let seconds = baseDelay.seconds * pow(multiplier, exponent)
        let capped = min(seconds, maxDelay.seconds)
        return .seconds(capped * randomness.clamped(to: 0...1))
    }
}

/// Suspends the current task. Injectable so tests run in microseconds instead of
/// actually sleeping through a backoff schedule.
public protocol ProtoSleeper: Sendable {
    func sleep(for duration: Duration) async throws
}

public struct InteractorTaskSleeper: ProtoSleeper {
    public init() {}
    public func sleep(for duration: Duration) async throws {
        try await Task.sleep(for: duration)
    }
}

/// Adds retry-with-backoff to any ``ProtoInteractorHTTP``.
///
/// A decorator rather than a flag on `InteractorHTTPURLSession`, so retry can be
/// composed, reordered, or omitted per call site — and so the retry logic is
/// testable against a stub that fails a scripted number of times.
public struct InteractorHTTPRetrying: ProtoInteractorHTTP {
    private let wrapped: any ProtoInteractorHTTP
    private let policy: RetryPolicy
    private let sleeper: any ProtoSleeper
    private let randomness: @Sendable () -> Double

    public init(
        wrapping client: any ProtoInteractorHTTP,
        policy: RetryPolicy = RetryPolicy(),
        sleeper: any ProtoSleeper = InteractorTaskSleeper(),
        randomness: @escaping @Sendable () -> Double = { Double.random(in: 0...1) }
    ) {
        self.wrapped = client
        self.policy = policy
        self.sleeper = sleeper
        self.randomness = randomness
    }

    public func send(_ request: URLRequest) async throws -> HTTPResponse {
        var lastError: any Error = HTTPError.transport(message: "no attempt made", isRetryable: false)

        for attempt in 1...policy.maxAttempts {
            // Checked before sleeping and before sending so a cancelled sync
            // stops immediately instead of finishing its backoff schedule.
            try Task.checkCancellation()

            let delay = policy.delay(beforeAttempt: attempt, randomness: randomness())
            if delay > .zero {
                try await sleeper.sleep(for: delay)
            }

            do {
                let response = try await wrapped.send(request)
                guard response.isSuccess else {
                    throw HTTPError.unacceptableStatus(code: response.statusCode)
                }
                return response
            } catch let error as HTTPError where error.isRetryable {
                lastError = error
                continue
            }
            // Non-retryable errors and `CancellationError` propagate immediately.
        }

        throw lastError
    }
}

extension Duration {
    var seconds: Double {
        Double(components.seconds) + Double(components.attoseconds) / 1e18
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
