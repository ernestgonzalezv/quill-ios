//
//  InteractorNoteRemote.swift
//  Quill
//
//  Created by Ernesto on 8/6/26.
//

public import Foundation
public import QuillDomain

/// HTTP adapter implementing the domain's ``ProtoRemoteNoteStore`` port.
///
/// Owns request building, auth injection and decoding. The sync engine that uses
/// it never sees a URL, a header or a status code.
public struct InteractorNoteRemote: ProtoRemoteNoteStore {
    private let client: any ProtoInteractorHTTP
    private let baseURL: URL
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    /// Resolved per request rather than captured once, so a token refreshed
    /// mid-session is picked up without rebuilding the object graph.
    private let accessToken: @Sendable () async -> String?

    public init(
        baseURL: URL,
        client: any ProtoInteractorHTTP,
        accessToken: @escaping @Sendable () async -> String? = { nil }
    ) {
        self.baseURL = baseURL
        self.client = client
        self.accessToken = accessToken
        self.decoder = .quill()
        self.encoder = .quill()
    }

    public func pull(since date: Date?) async throws -> RemoteChangeSet {
        var components = URLComponents(
            url: baseURL.appending(path: "notes"),
            resolvingAgainstBaseURL: false
        )
        if let date {
            components?.queryItems = [
                URLQueryItem(name: "updated_since", value: ISO8601.format(date))
            ]
        }
        guard let url = components?.url else {
            throw HTTPError.transport(message: "Could not build pull URL", isRetryable: false)
        }

        let response = try await client.send(await authorized(URLRequest(url: url)))
        let page: NotePageDTO = try decode(response.body)
        return RemoteChangeSet(notes: page.notes.map(\.domainModel), serverTime: page.serverTime)
    }

    public func push(_ notes: [Note]) async throws -> [Note] {
        // Guard rather than trust the caller: an empty POST would still cost a
        // round trip and advance server-side rate limits for no reason.
        guard !notes.isEmpty else { return [] }

        var request = URLRequest(url: baseURL.appending(path: "notes/batch"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(NotePushRequestDTO(notes: notes.map(NoteDTO.init(note:))))

        let response = try await client.send(await authorized(request))
        let page: NotePageDTO = try decode(response.body)
        return page.notes.map(\.domainModel)
    }

    private func authorized(_ request: URLRequest) async -> URLRequest {
        var request = request
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token = await accessToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    /// Maps decoding failures into ``HTTPError`` so callers handle one error
    /// domain instead of also unwrapping `DecodingError`.
    private func decode<T: Decodable>(_ data: Data) throws -> T {
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw HTTPError.decoding(message: String(describing: error))
        }
    }
}
