//
//  String+TrimmedOrNil.swift
//  Quill
//
//  Created by Ernesto on 8/8/26.
//

public import Foundation

extension String {
    /// `nil` instead of `""` for whitespace-only input, so callers can use
    /// `if let` rather than repeating `.trimmingCharacters(in:).isEmpty`.
    var trimmedOrNil: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
