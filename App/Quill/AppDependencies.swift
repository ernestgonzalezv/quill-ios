import Foundation
import SwiftData
import QuillDomain
import QuillData
import QuillFeature

/// The composition root: the single place where concrete types are chosen and
/// wired together.
///
/// Everything below this line talks to protocols. That is what lets `QuillFeature`
/// be built and tested without SwiftData or `URLSession`, and what makes swapping
/// the backend a change to this one file.
///
/// There is no DI container and no third-party framework — the object graph is
/// small enough that plain initialiser injection is clearer, checked at compile
/// time, and impossible to misconfigure at runtime.
@MainActor
final class AppDependencies {
    let router = NoteRouter()
    let featureFactory: NoteFeatureFactory
    let syncCoordinator: SyncCoordinator
    let spotlightIndexer: SpotlightIndexer

    /// Non-nil when the on-disk store could not be opened and an in-memory
    /// fallback is in use. Surfaced in the UI so a session that will silently lose
    /// data on quit does not look normal.
    let storeFailureMessage: String?

    private let createNote: CreateNote

    // MARK: - Construction

    static func live() -> AppDependencies {
        let configuration = AppConfiguration.fromBundle()

        // A corrupt or unmigratable store must not be a launch crash. Falling back
        // to memory keeps the app usable for the session, and the banner tells the
        // user why their notes will not persist.
        do {
            return AppDependencies(
                container: try .quill(),
                configuration: configuration,
                storeFailureMessage: nil
            )
        } catch {
            return AppDependencies(
                container: try! .quill(inMemory: true),
                configuration: configuration,
                storeFailureMessage: "Quill could not open its database, so notes will not be saved after you close the app."
            )
        }
    }

    private init(
        container: ModelContainer,
        configuration: AppConfiguration,
        storeFailureMessage: String?
    ) {
        self.storeFailureMessage = storeFailureMessage

        let dates = SystemDateProvider()
        let repository = SwiftDataNoteRepository(modelContainer: container)

        // Retry wraps the transport, not the sync engine: a 503 on the pull should
        // be retried transparently, while a *sync* that genuinely failed should be
        // reported once rather than silently attempted three more times.
        let http = RetryingHTTPClient(
            wrapping: URLSessionHTTPClient(session: .quill()),
            policy: RetryPolicy(maxAttempts: 3)
        )
        let remote = RemoteNoteAPI(baseURL: configuration.apiBaseURL, client: http)

        let coordinator = SyncCoordinator(
            syncNotes: SyncNotes(
                repository: repository,
                remote: remote,
                cursor: UserDefaultsSyncCursorStore()
            )
        )
        self.syncCoordinator = coordinator
        self.createNote = CreateNote(repository: repository, dates: dates)
        self.spotlightIndexer = SpotlightIndexer(repository: repository, observing: repository)

        // Closures rather than stored use cases so each screen gets a fresh view
        // model, and so the feature module never learns the concrete types.
        self.featureFactory = NoteFeatureFactory(
            makeListViewModel: {
                NoteListViewModel(
                    loadNotes: LoadNotes(repository: repository),
                    loadNote: LoadNote(repository: repository),
                    createNote: CreateNote(repository: repository, dates: dates),
                    deleteNote: DeleteNote(repository: repository, dates: dates),
                    togglePin: TogglePin(repository: repository, dates: dates),
                    synchronizer: coordinator,
                    storeChanges: repository
                )
            },
            makeEditorViewModel: { note in
                NoteEditorViewModel(
                    note: note,
                    updateNote: UpdateNote(repository: repository, dates: dates)
                )
            }
        )
    }

    // MARK: - Entry points used outside the view hierarchy

    /// Creates a note from a Siri shortcut or App Intent, then syncs.
    @discardableResult
    func createNoteFromIntent(text: String) async throws -> Note {
        let note = try await createNote(NoteDraft(body: text))
        await syncCoordinator.syncInBackground()
        return note
    }

    /// Shared instance for App Intents.
    ///
    /// The system instantiates an `AppIntent` itself, so there is no initialiser to
    /// inject through — a process-wide accessor is the only available seam. It is
    /// confined to `@MainActor`, created once, and deliberately *not* used by
    /// anything the app constructs itself, which all takes injection instead.
    static let shared: AppDependencies = .live()
}

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
