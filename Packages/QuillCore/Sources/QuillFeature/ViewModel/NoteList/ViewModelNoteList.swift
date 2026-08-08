//
//  ViewModelNoteList.swift
//  Quill
//
//  Created by Ernesto on 8/6/26.
//

public import Foundation
public import QuillDomain

/// Drives the notes list.
///
/// Three deliberate choices here:
///
/// - **`@MainActor` on the whole type.** UI state is only ever read and written on
///   the main actor, so the compiler proves there is no torn state — instead of a
///   `DispatchQueue.main.async` sprinkled at each assignment and hoped for.
/// - **One `state` enum, not parallel flags.** `isLoading` + `notes` + `error`
///   permits nonsense (loading *and* failed), and every view then has to guess a
///   precedence. A single value makes the illegal states unrepresentable and the
///   view a total function of it.
/// - **Injected use cases, not a repository.** The view model can create, delete
///   and pin; it cannot invent a query or write a timestamp. Its capabilities are
///   exactly what its initialiser lists.
@MainActor
@Observable
public final class ViewModelNoteList {
    public enum State: Equatable, Sendable {
        case loading
        case loaded([Note])
        case empty(EmptyReason)
        case failed(message: String)
    }

    public enum EmptyReason: Equatable, Sendable {
        case noNotes
        case noMatches(query: String)
    }

    public enum SyncStatus: Equatable, Sendable {
        case idle
        case syncing
        case failed(message: String)
    }

    public private(set) var state: State = .loading
    public private(set) var syncStatus: SyncStatus = .idle

    /// Bound directly by `.searchable`, so it must tolerate a mutation per
    /// keystroke. The debounce lives in `didSet` rather than in the view: a second
    /// screen binding the same view model must not be able to skip it.
    public var searchQuery: String = "" {
        didSet {
            guard searchQuery != oldValue else { return }
            scheduleSearch()
        }
    }

    private let loadNotes: LogicLoadNotes
    private let loadNote: LogicLoadNote
    private let createNote: LogicCreateNote
    private let deleteNote: LogicDeleteNote
    private let togglePin: LogicTogglePin
    private let synchronizer: (any ProtoNoteSynchronizing)?
    private let storeChanges: (any ProtoNoteRepositoryObserving)?
    private let searchDebounce: Duration

    private var searchTask: Task<Void, Never>?

    public init(
        loadNotes: LogicLoadNotes,
        loadNote: LogicLoadNote,
        createNote: LogicCreateNote,
        deleteNote: LogicDeleteNote,
        togglePin: LogicTogglePin,
        synchronizer: (any ProtoNoteSynchronizing)? = nil,
        storeChanges: (any ProtoNoteRepositoryObserving)? = nil,
        searchDebounce: Duration = .milliseconds(250)
    ) {
        self.loadNotes = loadNotes
        self.loadNote = loadNote
        self.createNote = createNote
        self.deleteNote = deleteNote
        self.togglePin = togglePin
        self.synchronizer = synchronizer
        self.storeChanges = storeChanges
        self.searchDebounce = searchDebounce
    }

    // No `deinit` cancelling `searchTask`: under Swift 6 `deinit` is nonisolated
    // and cannot touch main-actor state. It is not needed either — the debounce
    // task captures `self` weakly, so once this object is gone the task wakes,
    // finds `nil`, and returns without doing work.

    // MARK: - Lifecycle

    /// Loads, kicks off a sync, then observes the store until cancelled.
    ///
    /// Intended for SwiftUI's `.task {}`, which cancels on disappear — that
    /// cancellation is what tears down the observation loop, so there is no
    /// manual unsubscribe to forget.
    public func start() async {
        await reload()

        // Not awaited: a slow or offline sync must never delay first paint. Its
        // result arrives through the store-change stream like any other write.
        Task { await self.refresh() }

        await observeStoreChanges()
    }

    /// Re-reads from the local store. The single path through which `state`
    /// changes, so there is one place to reason about transitions.
    public func reload() async {
        do {
            let notes = try await loadNotes(query: searchQuery)
            state = resolveState(for: notes)
        } catch {
            state = .failed(message: error.localizedDescription)
        }
    }

    /// Pulls from the server. Failure is reported in ``syncStatus`` and never
    /// replaces ``state``: the notes on screen are still valid local data, and
    /// blanking a working list because the network blipped is a bug, not caution.
    public func refresh() async {
        guard let synchronizer else { return }

        syncStatus = .syncing
        do {
            try await synchronizer.sync()
            syncStatus = .idle
            await reload()
        } catch is CancellationError {
            syncStatus = .idle
        } catch {
            syncStatus = .failed(message: error.localizedDescription)
        }
    }

    // MARK: - Actions

    /// Creates an empty note and returns it for immediate presentation.
    ///
    /// Returns `nil` on failure rather than throwing: the caller is a SwiftUI
    /// button with nowhere to put an error, and the message is already surfaced
    /// through `state`.
    public func createDraftNote() async -> Note? {
        do {
            // A placeholder title, because `LogicCreateNote` rejects blank drafts —
            // the store should never hold a row the list cannot render.
            let untitled = Language.getLanguageString(key: "WORD_UNTITLED", comment: "Título por defecto de una nota sin título")
            let note = try await createNote(NoteDraft(title: untitled))
            await reload()
            return note
        } catch {
            state = .failed(message: error.localizedDescription)
            return nil
        }
    }

    /// Resolves a deep link. Returns `nil` when the note is gone — a Spotlight
    /// result can outlive the note it points at, and the list simply stays put.
    public func note(id: UUID) async -> Note? {
        try? await loadNote(id: id)
    }

    public func delete(_ note: Note) async {
        await perform { try await self.deleteNote(id: note.id) }
    }

    public func togglePin(_ note: Note) async {
        await perform { try await self.togglePin(id: note.id) }
    }

    // MARK: - Internals

    /// Runs a mutation, then reloads. Reloading from the store rather than
    /// patching the in-memory array keeps the list honest: sort order, search
    /// filtering and any server-side normalisation are reapplied every time.
    private func perform(_ action: @Sendable () async throws -> Void) async {
        do {
            try await action()
            await reload()
        } catch {
            state = .failed(message: error.localizedDescription)
        }
    }

    private func resolveState(for notes: [Note]) -> State {
        guard notes.isEmpty else { return .loaded(notes) }
        // Distinguishing the two empties matters: "write your first note" is
        // actively wrong advice when the user has 200 notes and a typo'd query.
        let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        return .empty(trimmed.isEmpty ? .noNotes : .noMatches(query: trimmed))
    }

    /// Coalesces keystrokes so a 12-character query is one store read, not twelve.
    private func scheduleSearch() {
        searchTask?.cancel()
        searchTask = Task { [weak self, searchDebounce] in
            try? await Task.sleep(for: searchDebounce)
            guard !Task.isCancelled else { return }
            await self?.reload()
        }
    }

    private func observeStoreChanges() async {
        guard let storeChanges else { return }
        // Reacting to store notifications rather than reloading at each call site
        // means an edit made in the editor, by a sync round, or by a Siri shortcut
        // all refresh the list through the same path.
        for await _ in storeChanges.changes {
            await reload()
        }
    }
}

// MARK: - DelegateUINoteRow
