//
//  RetryPolicy.swift
//  Quill
//
//  Created by Ernesto on 8/8/26.
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
