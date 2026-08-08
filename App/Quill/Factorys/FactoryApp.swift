//
//  FactoryApp.swift
//  Quill
//
//  Created by Ernesto on 8/6/26.
//

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
final class FactoryApp {
    let router = InteractorNoteDeepLink()
    let featureFactory: FactoryNote
    let syncCoordinator: InteractorNoteSync
    let spotlightIndexer: InteractorSpotlight

    /// Non-nil when the on-disk store could not be opened and an in-memory
    /// fallback is in use. Surfaced in the UI so a session that will silently lose
    /// data on quit does not look normal.
    let storeFailureMessage: String?

    private let createNote: LogicCreateNote

    // MARK: - Construction

    static func live() -> FactoryApp {
        let configuration = ConstantsAPI.fromBundle()

        // A corrupt or unmigratable store must not be a launch crash. Falling back
        // to memory keeps the app usable for the session, and the banner tells the
        // user why their notes will not persist.
        do {
            return FactoryApp(
                container: try .quill(),
                configuration: configuration,
                storeFailureMessage: nil
            )
        } catch {
            let comment = "Aviso de que la base de datos local no abrió y las notas no se guardarán"
            let message = Language.getLanguageString(key: "PHRASE_STORE_UNAVAILABLE", comment: comment)
            // Si ni el contenedor en memoria se puede crear, no queda app que
            // degradar: es un fallo de configuración del esquema, no del disco.
            guard let container = try? ModelContainer.quill(inMemory: true) else {
                preconditionFailure("No se pudo crear el ModelContainer en memoria")
            }
            return FactoryApp(
                container: container,
                configuration: configuration,
                storeFailureMessage: message
            )
        }
    }

    private init(
        container: ModelContainer,
        configuration: ConstantsAPI,
        storeFailureMessage: String?
    ) {
        self.storeFailureMessage = storeFailureMessage

        let dates = InteractorSystemDate()
        let repository = InteractorNotePersistence(modelContainer: container)

        // Retry wraps the transport, not the sync engine: a 503 on the pull should
        // be retried transparently, while a *sync* that genuinely failed should be
        // reported once rather than silently attempted three more times.
        let http = InteractorHTTPRetrying(
            wrapping: InteractorHTTPURLSession(session: .quill()),
            policy: RetryPolicy(maxAttempts: 3)
        )
        let remote = InteractorNoteRemote(baseURL: configuration.apiBaseURL, client: http)

        let coordinator = InteractorNoteSync(
            syncNotes: LogicSyncNotes(
                repository: repository,
                remote: remote,
                cursor: InteractorSyncCursor()
            )
        )
        self.syncCoordinator = coordinator
        self.createNote = LogicCreateNote(repository: repository, dates: dates)
        self.spotlightIndexer = InteractorSpotlight(repository: repository, observing: repository)

        // Closures rather than stored use cases so each screen gets a fresh view
        // model, and so the feature module never learns the concrete types.
        self.featureFactory = FactoryNote(
            makeListViewModel: {
                ViewModelNoteList(
                    loadNotes: LogicLoadNotes(repository: repository),
                    loadNote: LogicLoadNote(repository: repository),
                    createNote: LogicCreateNote(repository: repository, dates: dates),
                    deleteNote: LogicDeleteNote(repository: repository, dates: dates),
                    togglePin: LogicTogglePin(repository: repository, dates: dates),
                    synchronizer: coordinator,
                    storeChanges: repository
                )
            },
            makeEditorViewModel: { note in
                ViewModelNoteEditor(
                    note: note,
                    updateNote: LogicUpdateNote(repository: repository, dates: dates)
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
    static let shared: FactoryApp = .live()
}
