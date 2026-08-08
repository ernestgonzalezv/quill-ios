//
//  InteractorTaskSleeper.swift
//  Quill
//
//  Created by Ernesto on 8/8/26.
//

public import Foundation

public struct InteractorTaskSleeper: ProtoSleeper {
    public init() {}
    public func sleep(for duration: Duration) async throws {
        try await Task.sleep(for: duration)
    }
}
