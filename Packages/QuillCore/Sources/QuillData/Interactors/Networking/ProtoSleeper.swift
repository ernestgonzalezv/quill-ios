//
//  ProtoSleeper.swift
//  Quill
//
//  Created by Ernesto on 8/8/26.
//

public import Foundation

/// Suspends the current task. Injectable so tests run in microseconds instead of
/// actually sleeping through a backoff schedule.
public protocol ProtoSleeper: Sendable {
    func sleep(for duration: Duration) async throws
}
