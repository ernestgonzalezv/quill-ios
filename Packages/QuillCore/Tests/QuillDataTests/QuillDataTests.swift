import Foundation
import Testing
import SwiftData
import QuillDomain
@testable import QuillData

// MARK: - Test doubles

/// Replays a scripted sequence of outcomes, so retry behaviour can be tested
/// without a network or a real server.
private actor ScriptedHTTPClient: HTTPClient {
    private var outcomes: [Result<HTTPResponse, HTTPError>]
    private(set) var attempts = 0

    init(_ outcomes: [Result<HTTPResponse, HTTPError>]) { self.outcomes = outcomes }

    func send(_ request: URLRequest) async throws -> HTTPResponse {
        attempts += 1
        guard !outcomes.isEmpty else { return HTTPResponse(statusCode: 200, body: Data()) }
        return try outcomes.removeFirst().get()
    }
}

/// Records requested delays instead of sleeping, which keeps backoff tests
/// instant and lets them assert the actual schedule.
private actor RecordingSleeper: Sleeper {
    private(set) var delays: [Duration] = []
    func sleep(for duration: Duration) async throws { delays.append(duration) }
}

// MARK: - Retry

@Suite("Retry and backoff")
struct RetryingHTTPClientTests {
    @Test("A retryable failure is retried and can then succeed")
    func retriesThenSucceeds() async throws {
        let client = ScriptedHTTPClient([
            .failure(.transport(message: "flaky", isRetryable: true)),
            .success(HTTPResponse(statusCode: 200, body: Data("ok".utf8))),
        ])
        let sleeper = RecordingSleeper()
        let sut = RetryingHTTPClient(
            wrapping: client, policy: RetryPolicy(maxAttempts: 3),
            sleeper: sleeper, randomness: { 1 }
        )

        let response = try await sut.send(URLRequest(url: URL(string: "https://example.com")!))

        #expect(response.statusCode == 200)
        #expect(await client.attempts == 2)
        // One delay, before the second attempt only — never before the first.
        #expect(await sleeper.delays.count == 1)
    }

    @Test("A 4xx is not retried")
    func doesNotRetryClientErrors() async {
        let client = ScriptedHTTPClient([.success(HTTPResponse(statusCode: 422, body: Data()))])
        let sut = RetryingHTTPClient(
            wrapping: client, policy: RetryPolicy(maxAttempts: 3),
            sleeper: RecordingSleeper(), randomness: { 0 }
        )

        // Retrying a rejected payload only burns battery and rate limit.
        await #expect(throws: HTTPError.unacceptableStatus(code: 422)) {
            try await sut.send(URLRequest(url: URL(string: "https://example.com")!))
        }
        #expect(await client.attempts == 1)
    }

    @Test("Attempts are capped and the last error propagates")
    func stopsAtMaxAttempts() async {
        let failure = Result<HTTPResponse, HTTPError>.failure(.unacceptableStatus(code: 503))
        let client = ScriptedHTTPClient([failure, failure, failure, failure])
        let sut = RetryingHTTPClient(
            wrapping: client, policy: RetryPolicy(maxAttempts: 3),
            sleeper: RecordingSleeper(), randomness: { 0 }
        )

        await #expect(throws: HTTPError.unacceptableStatus(code: 503)) {
            try await sut.send(URLRequest(url: URL(string: "https://example.com")!))
        }
        #expect(await client.attempts == 3)
    }

    @Test("Backoff grows exponentially and is capped")
    func backoffSchedule() {
        let policy = RetryPolicy(
            maxAttempts: 6, baseDelay: .seconds(1), multiplier: 2, maxDelay: .seconds(4)
        )

        // No delay before the first attempt, then 1s, 2s, 4s, capped at 4s.
        #expect(policy.delay(beforeAttempt: 1, randomness: 1) == .zero)
        #expect(policy.delay(beforeAttempt: 2, randomness: 1) == .seconds(1))
        #expect(policy.delay(beforeAttempt: 3, randomness: 1) == .seconds(2))
        #expect(policy.delay(beforeAttempt: 4, randomness: 1) == .seconds(4))
        #expect(policy.delay(beforeAttempt: 5, randomness: 1) == .seconds(4))
    }

    @Test("Jitter scales the delay")
    func jitterScalesDelay() {
        let policy = RetryPolicy(maxAttempts: 3, baseDelay: .seconds(2), multiplier: 2)

        // Full jitter: without it, every client knocked offline by one outage
        // retries in lockstep the instant the server recovers.
        #expect(policy.delay(beforeAttempt: 2, randomness: 0) == .zero)
        #expect(policy.delay(beforeAttempt: 2, randomness: 0.5) == .seconds(1))
    }
}

// MARK: - Wire format

@Suite("DTO mapping")
struct NoteDTOTests {
    @Test("A note survives an encode/decode round trip")
    func roundTrip() throws {
        let note = Note(
            id: UUID(), title: "Café", body: "Line one\nLine two", isPinned: true,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_700_000_123.456),
            deletedAt: nil
        )

        let data = try JSONEncoder.quill().encode(NoteDTO(note: note))
        let decoded = try JSONDecoder.quill().decode(NoteDTO.self, from: data).domainModel

        #expect(decoded.id == note.id)
        #expect(decoded.title == note.title)
        #expect(decoded.body == note.body)
        #expect(decoded.isPinned == note.isPinned)
        #expect(decoded.deletedAt == nil)

        // Compared with a tolerance, not for equality: the wire format carries
        // milliseconds, so a `Date`'s sub-millisecond component does not survive a
        // round trip. That is a real property of the protocol and it is why
        // last-write-wins can still tie — two edits inside the same millisecond
        // are indistinguishable to the server and fall through to the tie-break
        // rule in `NoteMerger`.
        #expect(abs(decoded.updatedAt.timeIntervalSince(note.updatedAt)) < 0.001)
        #expect(abs(decoded.createdAt.timeIntervalSince(note.createdAt)) < 0.001)
    }

    @Test("Both ISO-8601 shapes parse")
    func acceptsBothDateShapes() throws {
        // Servers emit fractional seconds inconsistently; `.iso8601` rejects them.
        #expect(ISO8601.parse("2026-08-06T12:00:00.123Z") != nil)
        #expect(ISO8601.parse("2026-08-06T12:00:00Z") != nil)
        #expect(ISO8601.parse("not a date") == nil)
    }

    @Test("Encoding keeps millisecond precision")
    func encodesFractionalSeconds() {
        // Whole-second precision would make near-simultaneous edits tie constantly.
        #expect(ISO8601.format(Date(timeIntervalSince1970: 1_700_000_000.5)).contains(".500"))
    }

    @Test("Snake-cased server keys decode")
    func decodesSnakeCase() throws {
        let json = Data("""
        {"notes":[],"server_time":"2026-08-06T12:00:00.000Z"}
        """.utf8)

        let page = try JSONDecoder.quill().decode(NotePageDTO.self, from: json)
        #expect(page.notes.isEmpty)
    }
}

// MARK: - Persistence

@Suite("SwiftDataNoteRepository")
struct SwiftDataNoteRepositoryTests {
    /// A fresh in-memory container per test, so suites run in parallel without
    /// sharing a store file.
    private func makeRepository() throws -> SwiftDataNoteRepository {
        SwiftDataNoteRepository(modelContainer: try .quill(inMemory: true))
    }

    private func stub(id: UUID = UUID(), title: String = "T", updatedAt: TimeInterval = 100, deletedAt: TimeInterval? = nil) -> Note {
        Note(
            id: id, title: title, body: "B", isPinned: false,
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: updatedAt),
            deletedAt: deletedAt.map(Date.init(timeIntervalSince1970:))
        )
    }

    @Test("Round-trips a note through the store")
    func insertAndFetch() async throws {
        let sut = try makeRepository()
        let note = stub()

        try await sut.upsert([note])

        #expect(try await sut.note(id: note.id) == note)
    }

    /// The `#Unique` constraint on `id` is what makes this a guarantee rather than
    /// a hope: a bug in `upsert` would surface as a constraint violation.
    @Test("Upserting the same id updates rather than duplicates")
    func upsertDoesNotDuplicate() async throws {
        let sut = try makeRepository()
        let id = UUID()

        try await sut.upsert([stub(id: id, title: "First")])
        try await sut.upsert([stub(id: id, title: "Second", updatedAt: 200)])

        let all = try await sut.all(includingDeleted: true)
        #expect(all.count == 1)
        #expect(all.first?.title == "Second")
    }

    @Test("Tombstones are hidden from normal reads but visible to sync")
    func tombstoneVisibility() async throws {
        let sut = try makeRepository()
        try await sut.upsert([stub(title: "Live"), stub(title: "Gone", deletedAt: 100)])

        #expect(try await sut.all(includingDeleted: false).map(\.title) == ["Live"])
        #expect(try await sut.all(includingDeleted: true).count == 2)
    }

    @Test("Purging removes only tombstones older than the cutoff")
    func purgeRespectsCutoff() async throws {
        let sut = try makeRepository()
        try await sut.upsert([
            stub(title: "Old", deletedAt: 50),
            stub(title: "Recent", deletedAt: 500),
            stub(title: "Live"),
        ])

        try await sut.purgeTombstones(deletedBefore: Date(timeIntervalSince1970: 100))

        let remaining = try await sut.all(includingDeleted: true).map(\.title).sorted()
        #expect(remaining == ["Live", "Recent"])
    }

    @Test("A committed write notifies observers")
    func writeNotifiesObservers() async throws {
        let sut = try makeRepository()
        var iterator = sut.changes.makeAsyncIterator()

        try await sut.upsert([stub()])

        // Observers re-read through the repository, so the tick carries no payload.
        #expect(await iterator.next() != nil)
    }
}

// MARK: - Sync

@Suite("Sync engine")
struct SyncNotesTests {
    private actor StubRemote: RemoteNoteStore {
        let changeSet: RemoteChangeSet
        private(set) var pushed: [Note] = []
        private(set) var pullSince: Date??

        init(changeSet: RemoteChangeSet) { self.changeSet = changeSet }

        func pull(since date: Date?) async throws -> RemoteChangeSet {
            pullSince = date
            return changeSet
        }

        func push(_ notes: [Note]) async throws -> [Note] {
            pushed = notes
            return notes
        }
    }

    private actor StubCursor: SyncCursorStore {
        private var value: Date?
        init(_ value: Date? = nil) { self.value = value }
        func lastSyncedAt() async -> Date? { value }
        func setLastSyncedAt(_ date: Date?) async { value = date }
    }

    private func stub(id: UUID = UUID(), title: String = "T", updatedAt: TimeInterval = 100) -> Note {
        Note(
            id: id, title: title, body: "B", isPinned: false,
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: updatedAt)
        )
    }

    @Test("Remote notes are stored and local-only notes pushed")
    func fullRound() async throws {
        let serverTime = Date(timeIntervalSince1970: 9_000)
        let incoming = stub(title: "From server", updatedAt: 500)
        let localOnly = stub(title: "Local only", updatedAt: 400)

        let repository = InMemoryRepository([localOnly])
        let remote = StubRemote(changeSet: RemoteChangeSet(notes: [incoming], serverTime: serverTime))
        let cursor = StubCursor()

        let report = try await SyncNotes(repository: repository, remote: remote, cursor: cursor)()

        #expect(report.pulled == 1)
        #expect(report.pushed == 1)
        #expect(await remote.pushed.map(\.title) == ["Local only"])
        // The cursor tracks *server* time — device clocks are wrong often enough
        // that trusting one silently drops records from the next delta.
        #expect(await cursor.lastSyncedAt() == serverTime)
    }

    @Test("A failed pull leaves the cursor untouched")
    func failedPullDoesNotAdvanceCursor() async {
        let previous = Date(timeIntervalSince1970: 1_000)
        let cursor = StubCursor(previous)

        let sut = SyncNotes(repository: InMemoryRepository(), remote: FailingRemote(), cursor: cursor)

        await #expect(throws: (any Error).self) { try await sut() }
        // So the next attempt re-pulls the same delta rather than skipping it.
        #expect(await cursor.lastSyncedAt() == previous)
    }

    private actor FailingRemote: RemoteNoteStore {
        func pull(since date: Date?) async throws -> RemoteChangeSet {
            throw HTTPError.transport(message: "offline", isRetryable: true)
        }
        func push(_ notes: [Note]) async throws -> [Note] { [] }
    }

    private actor InMemoryRepository: NoteRepository {
        private var storage: [UUID: Note]
        init(_ notes: [Note] = []) {
            storage = Dictionary(notes.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        }
        func all(includingDeleted: Bool) async throws -> [Note] {
            let notes = Array(storage.values)
            return includingDeleted ? notes : notes.filter { !$0.isDeleted }
        }
        func note(id: UUID) async throws -> Note? { storage[id] }
        func upsert(_ notes: [Note]) async throws { for note in notes { storage[note.id] = note } }
        func purgeTombstones(deletedBefore date: Date) async throws {}
    }
}
