//
//  InteractorHTTPURLSession.swift
//  Quill
//
//  Created by Ernesto on 8/8/26.
//

public import Foundation

public struct InteractorHTTPURLSession: ProtoInteractorHTTP {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func send(_ request: URLRequest) async throws -> HTTPResponse {
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw HTTPError.nonHTTPResponse
            }
            return HTTPResponse(statusCode: http.statusCode, body: data)
        } catch let error as HTTPError {
            throw error
        } catch let error as URLError {
            throw HTTPError.transport(
                message: error.localizedDescription,
                isRetryable: Self.retryableURLErrorCodes.contains(error.code)
            )
        } catch is CancellationError {
            // Cancellation is not a failure to retry — it is the caller's
            // decision, and swallowing it into `.transport` would make a
            // retrying decorator fight the task that cancelled it.
            throw CancellationError()
        }
    }

    /// Codes that indicate a transient network condition rather than a
    /// misconfiguration. Notably excludes TLS and bad-URL errors, which will fail
    /// identically forever.
    private static let retryableURLErrorCodes: Set<URLError.Code> = [
        .timedOut,
        .cannotConnectToHost,
        .networkConnectionLost,
        .notConnectedToInternet,
        .dnsLookupFailed,
        .cannotFindHost,
        .internationalRoamingOff,
        .callIsActive,
        .dataNotAllowed
    ]
}
