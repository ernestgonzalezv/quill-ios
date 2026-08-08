//
//  InteractorSystemDate.swift
//  Quill
//
//  Created by Ernesto on 8/8/26.
//

public import Foundation

public struct InteractorSystemDate: ProtoDateProvider {
    public init() {}
    public var now: Date { Date() }
}
