//
//  JSONEncoder+Quill.swift
//  Quill
//
//  Created by Ernesto on 8/8/26.
//

import Foundation
internal import QuillDomain

extension JSONEncoder {
    static func quill() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        // Always sends fractional seconds. Millisecond precision is what makes
        // last-write-wins usable: whole-second timestamps make near-simultaneous
        // edits tie constantly and fall through to the tie-break rule.
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(ISO8601.format(date))
        }
        return encoder
    }
}
