//
//  URLSession+Quill.swift
//  Quill
//
//  Created by Ernesto on 8/8/26.
//

import Foundation
import SwiftData
import QuillDomain
import QuillData
import QuillFeature

extension URLSession {
    /// The app's session.
    ///
    /// Timeouts are set well below the system default of 60s: a note sync that has
    /// not answered in 15 seconds is not going to, and a shorter ceiling means the
    /// retry schedule actually gets to run inside a background-refresh window.
    static func quill() -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 60
        configuration.waitsForConnectivity = true
        // Sync always sends the full delta, so a cached 200 would be worse than a
        // round trip: it could hide notes written seconds ago.
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: configuration)
    }
}
