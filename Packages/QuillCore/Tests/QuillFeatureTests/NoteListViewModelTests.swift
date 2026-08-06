import Foundation
import Testing
import QuillDomain
@testable import QuillFeature

/// These run without SwiftData or `URLSession` — the whole point of `QuillFeature`
/// depending on `QuillDomain` only. Fakes below are the only infrastructure needed.
@Suite("NoteListViewModel")
@MainActor
struct NoteListViewModelTests {

    // MARK: - Fakes

    private actor FakeRepository: NoteRepository {
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

    private struct FixedDates: DateProvider {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
    }

    private struct FailingSynchronizer: NoteSynchronizing {
        func sync() async throws -> SyncReport {
            throw HTTPStubError.offline
        }
    }

    private enum HTTPStubError: Error { case offline }

    private func makeSUT(
        notes: [Note] = [],
        synchronizer: (any NoteSynchronizing)? = nil
    ) -> NoteListViewModel {
        let repository = FakeRepository(notes)
        let dates = FixedDates()
        return NoteListViewModel(
            loadNotes: LoadNotes(repository: repository),
            loadNote: LoadNote(repository: repository),
            createNote: CreateNote(repository: repository, dates: dates),
            deleteNote: DeleteNote(repository: repository, dates: dates),
            togglePin: TogglePin(repository: repository, dates: dates),
            synchronizer: synchronizer,
            searchDebounce: .zero
        )
    }

    private func stub(title: String = "T", isPinned: Bool = false, updatedAt: TimeInterval = 100) -> Note {
        Note(
            id: UUID(), title: title, body: "Body", isPinned: isPinned,
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: updatedAt)
        )
    }

    // MARK: - State machine

    @Test("Starts in loading")
    func initialState() {
        #expect(makeSUT().state == .loading)
    }

    @Test("An empty store resolves to the no-notes empty state")
    func emptyStore() async {
        let sut = makeSUT()
        await sut.reload()

        // Not `.loaded([])`: the view needs to tell "write your first note" apart
        // from "your search matched nothing".
        #expect(sut.state == .empty(.noNotes))
    }

    @Test("Notes load ordered, pinned first")
    func loadsOrdered() async {
        let sut = makeSUT(notes: [stub(title: "Old", updatedAt: 10), stub(title: "Pinned", isPinned: true, updatedAt: 5), stub(title: "New", updatedAt: 900)])
        await sut.reload()

        guard case .loaded(let notes) = sut.state else {
            Issue.record("expected .loaded, got \(sut.state)")
            return
        }
        #expect(notes.map(\.title) == ["Pinned", "New", "Old"])
    }

    @Test("A query with no matches is a distinct empty state")
    func noSearchMatches() async {
        let sut = makeSUT(notes: [stub(title: "Groceries")])
        sut.searchQuery = "invoices"
        await sut.reload()

        #expect(sut.state == .empty(.noMatches(query: "invoices")))
    }

    @Test("Search filters the list")
    func searchFilters() async {
        let sut = makeSUT(notes: [stub(title: "Groceries"), stub(title: "Invoices")])
        sut.searchQuery = "groc"
        await sut.reload()

        guard case .loaded(let notes) = sut.state else {
            Issue.record("expected .loaded, got \(sut.state)")
            return
        }
        #expect(notes.map(\.title) == ["Groceries"])
    }

    @Test("A whitespace-only query is treated as no query")
    func whitespaceQueryIsNotASearch() async {
        let sut = makeSUT()
        sut.searchQuery = "   "
        await sut.reload()

        #expect(sut.state == .empty(.noNotes))
    }

    // MARK: - Actions

    @Test("Creating a note yields it and refreshes the list")
    func createsNote() async {
        let sut = makeSUT()
        let note = await sut.createDraftNote()

        #expect(note != nil)
        guard case .loaded(let notes) = sut.state else {
            Issue.record("expected .loaded, got \(sut.state)")
            return
        }
        #expect(notes.count == 1)
    }

    @Test("Deleting removes the note from the list")
    func deletesNote() async {
        let note = stub()
        let sut = makeSUT(notes: [note])
        await sut.reload()

        await sut.delete(note)

        #expect(sut.state == .empty(.noNotes))
    }

    @Test("Toggling a pin is reflected after reload")
    func togglesPin() async {
        let note = stub(isPinned: false)
        let sut = makeSUT(notes: [note])
        await sut.reload()

        await sut.togglePin(note)

        guard case .loaded(let notes) = sut.state else {
            Issue.record("expected .loaded, got \(sut.state)")
            return
        }
        #expect(notes.first?.isPinned == true)
    }

    @Test("Deep links do not resolve deleted notes")
    func deepLinkMissingNote() async {
        #expect(await makeSUT().note(id: UUID()) == nil)
    }

    // MARK: - Failure isolation

    /// The bug this guards against: blanking a perfectly good list because the
    /// network blipped. Local data is still valid — only the sync banner changes.
    @Test("A sync failure never replaces a loaded list")
    func syncFailureKeepsNotesOnScreen() async {
        let sut = makeSUT(notes: [stub(title: "Kept")], synchronizer: FailingSynchronizer())
        await sut.reload()

        await sut.refresh()

        guard case .loaded(let notes) = sut.state else {
            Issue.record("expected state to stay .loaded, got \(sut.state)")
            return
        }
        #expect(notes.map(\.title) == ["Kept"])

        guard case .failed = sut.syncStatus else {
            Issue.record("expected syncStatus to be .failed, got \(sut.syncStatus)")
            return
        }
    }

    @Test("With no synchronizer, refresh is a no-op")
    func refreshWithoutSynchronizer() async {
        let sut = makeSUT(notes: [stub()])
        await sut.reload()

        await sut.refresh()

        #expect(sut.syncStatus == .idle)
    }
}

@Suite("NoteRouter")
@MainActor
struct NoteRouterTests {
    @Test("A pending note id is delivered exactly once")
    func consumesOnce() {
        let router = NoteRouter()
        let id = UUID()

        router.requestOpen(noteID: id)

        // Consumed rather than merely read, so navigating back does not re-push.
        #expect(router.consumePendingNoteID() == id)
        #expect(router.consumePendingNoteID() == nil)
    }
}
