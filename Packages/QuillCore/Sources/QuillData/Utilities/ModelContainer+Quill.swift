//
//  ModelContainer+Quill.swift
//  Quill
//
//  Created by Ernesto on 8/8/26.
//

public import Foundation
public import SwiftData
public import QuillDomain

public extension ModelContainer {
    /// The app's container.
    ///
    /// - Parameter inMemory: used by tests and previews. An in-memory container
    ///   is created per test so suites can run in parallel without sharing a file.
    static func quill(inMemory: Bool = false) throws -> ModelContainer {
        try ModelContainer(
            for: NoteEntity.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: inMemory)
        )
    }
}
