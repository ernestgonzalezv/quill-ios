//
//  Comparable+Clamped.swift
//  Quill
//
//  Created by Ernesto on 8/8/26.
//

public import Foundation

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
