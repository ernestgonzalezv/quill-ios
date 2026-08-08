//
//  ProtoInteractorHTTP.swift
//  Quill
//
//  Created by Ernesto on 8/6/26.
//

public import Foundation

/// The narrowest useful networking seam: request in, status + bytes out.
///
/// Everything above it (decoding, auth, retry) is composed as decorators around
/// this one method, and everything below it is `URLSession`'s problem. Tests stub
/// this protocol directly instead of installing a global `URLProtocol`, so two
/// suites can run in parallel without fighting over shared session state.
public protocol ProtoInteractorHTTP: Sendable {
    func send(_ request: URLRequest) async throws -> HTTPResponse
}
public struct HTTPResponse: Hashable, Sendable {
    public let statusCode: Int
    public let body: Data

    public init(statusCode: Int, body: Data) {
        self.statusCode = statusCode
        self.body = body
    }

    public var isSuccess: Bool { (200..<300).contains(statusCode) }
}
/// Transport and protocol failures.
///
/// Carries `String` rather than the underlying `any Error` so the type is
/// `Sendable` and `Equatable` — tests assert on cases instead of on error
/// descriptions, and the value crosses actor boundaries without a wrapper.
public enum HTTPError: Error, Hashable, Sendable {
    /// A non-HTTP response, which for this API means a misconfigured base URL.
    case nonHTTPResponse
    /// The request completed but the server rejected it.
    case unacceptableStatus(code: Int)
    /// The request never completed. `isRetryable` distinguishes a flaky
    /// connection from a permanent failure like a bad certificate.
    case transport(message: String, isRetryable: Bool)
    case decoding(message: String)

    /// Whether retrying this exact request could plausibly succeed.
    ///
    /// 5xx and 429 are retryable; 4xx is not, because retrying a rejected
    /// payload just burns battery and rate limit.
    public var isRetryable: Bool {
        switch self {
        case .transport(_, let isRetryable):
            isRetryable
        case .unacceptableStatus(let code):
            code == 429 || (500..<600).contains(code)
        case .nonHTTPResponse, .decoding:
            false
        }
    }
}
