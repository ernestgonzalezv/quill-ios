//
//  Error+UserFacingMessage.swift
//  Quill
//
//  Created by Ernesto on 8/8/26.
//

public import Foundation
public import QuillDomain

extension Error {
    /// A short message safe to show a user.
    ///
    /// Deliberately vague about server internals: a 500's body can contain stack
    /// traces or identifiers that should not reach a screenshot.
    var userFacingMessage: String {
        switch self {
        case let error as HTTPError:
            switch error {
            case .transport:
                "You appear to be offline. Your notes are saved on this device."
            case .unacceptableStatus(let code) where code == 401 || code == 403:
                "Your session expired. Sign in again to keep syncing."
            case .unacceptableStatus, .nonHTTPResponse, .decoding:
                "Sync is unavailable right now. Your notes are safe on this device."
            }
        default:
            "Sync is unavailable right now. Your notes are safe on this device."
        }
    }
}
