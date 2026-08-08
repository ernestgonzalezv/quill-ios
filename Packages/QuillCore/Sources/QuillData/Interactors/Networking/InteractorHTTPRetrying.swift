//
//  InteractorHTTPRetrying.swift
//  Quill
//
//  Created by Ernesto on 8/6/26.
//

public import Foundation

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
