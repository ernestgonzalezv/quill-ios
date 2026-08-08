//
//  JSONDecoder+Quill.swift
//  Quill
//
//  Created by Ernesto on 8/8/26.
//

import Foundation
internal import QuillDomain

extension JSONDecoder {
    static func quill() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        // Tolerates both `2026-08-06T12:00:00Z` and `...12:00:00.123Z`: servers
        // emit fractional seconds inconsistently, and `.iso8601` rejects them.
        decoder.dateDecodingStrategy = .custom { decoder in
            let raw = try decoder.singleValueContainer().decode(String.self)
            guard let date = ISO8601.parse(raw) else {
                throw DecodingError.dataCorrupted(
                    .init(codingPath: decoder.codingPath, debugDescription: "Unparseable date: \(raw)")
                )
            }
            return date
        }
        return decoder
    }
}
