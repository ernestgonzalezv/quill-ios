//
//  ScreenNoteList.swift
//  Quill
//
//  Created by Ernesto on 8/6/26.
//

public import SwiftUI
internal import QuillDomain

/// The app's root screen: a searchable list of notes that pushes the editor.
///
/// The view is a pure function of `viewModel.state` — one `switch`, one branch per
/// case, no `if isLoading` chains. Adding a state to the enum breaks this switch
/// at compile time, which is the point.
public struct ScreenNoteList: View {
    private let factory: FactoryNote
    private let router: InteractorNoteDeepLink
    @State private var viewModel: ViewModelNoteList
    @State private var path: [Note] = []

    public init(factory: FactoryNote, router: InteractorNoteDeepLink) {
        self.factory = factory
        self.router = router
        // `State(wrappedValue:)` so the view model is created once, at first
        // render, and survives the view struct being recreated on every update.
        _viewModel = State(wrappedValue: factory.makeListViewModel())
    }

    public var body: some View {
        NavigationStack(path: $path) {
            content
                .navigationTitle(Text(textTitle))
                .searchable(text: $viewModel.searchQuery, prompt: Text(textSearchPrompt))
                .refreshable { await viewModel.refresh() }
                .toolbar { toolbarContent }
                .safeAreaInset(edge: .bottom) { syncBanner }
                .navigationDestination(for: Note.self) { note in
                    ScreenNoteEditor(viewModel: factory.makeEditorViewModel(note))
                }
        }
        // Cancelled automatically when the screen goes away, which is what tears
        // down the store observation loop inside `start()`.
        .task { await viewModel.start() }
        // Deep links (Spotlight, Siri) arrive as a router request rather than as a
        // path mutation, because the app layer has no access to `path`.
        .task(id: router.pendingNoteID) { await openPendingNoteIfNeeded() }
    }

    /// Pushes the deep-linked note, replacing the stack rather than appending, so
    /// repeated links cannot build a pile of editors.
    private func openPendingNoteIfNeeded() async {
        guard let id = router.consumePendingNoteID() else { return }
        guard let note = await viewModel.note(id: id) else { return }
        path = [note]
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loading:
            // No spinner on a local read: SwiftData returns in milliseconds and a
            // flashed spinner reads as jank. The blank list is the honest state.
            List {}
                .accessibilityHidden(true)

        case .loaded(let notes):
            List {
                ForEach(notes) { note in
                    NavigationLink(value: note) {
                        // Fijar y eliminar viven en la fila, con el view model como
                        // delegate: la pantalla no tiene por qué conocer los gestos
                        // de una celda.
                        ViewNoteRow(note: note, delegate: viewModel)
                    }
                }
            }
            .listStyle(.plain)

        case .empty(let reason):
            emptyView(for: reason)

        case .failed(let message):
            ContentUnavailableView {
                Label {
                    Text(textTryAgain)
                } icon: {
                    Image(systemName: "exclamationmark.triangle")
                }
            } description: {
                Text(message)
            } actions: {
                Button(textTryAgain) {
                    Task { await viewModel.reload() }
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    @ViewBuilder
    private func emptyView(for reason: TypeUINoteListEmpty) -> some View {
        switch reason {
        case .noNotes:
            ContentUnavailableView {
                Label { Text(textEmptyTitle) } icon: { Image(systemName: "note.text") }
            } description: {
                Text(textEmptyMessage)
            }
        case .noMatches(let query):
            // The system-provided search empty state already handles localisation
            // and the "for \"query\"" phrasing correctly in every language.
            ContentUnavailableView.search(text: query)
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                Task {
                    // Push only once the note actually exists, so the editor never
                    // has to represent a note that failed to be created.
                    if let note = await viewModel.createDraftNote() {
                        path.append(note)
                    }
                }
            } label: {
                Label { Text(textNewNote) } icon: { Image(systemName: "square.and.pencil") }
            }
            .accessibilityLabel(Text(textNewNote))
        }
    }

    @ViewBuilder
    private var syncBanner: some View {
        if case .failed(let message) = viewModel.syncStatus {
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(.bar)
                // Announced rather than silently drawn: a sighted user sees the
                // banner appear, a VoiceOver user otherwise would not.
                .accessibilityAddTraits(.isStaticText)
        }
    }

    // MARK: - Textos

    private var textTitle: String {
        Language.getLanguageString(key: "WORD_NOTES", comment: "Título de la pantalla principal de notas")
    }

    private var textSearchPrompt: String {
        Language.getLanguageString(key: "PHRASE_SEARCH_NOTES", comment: "Placeholder del campo de búsqueda de la lista")
    }

    private var textTryAgain: String {
        Language.getLanguageString(key: "PHRASE_TRY_AGAIN", comment: "Botón que reintenta la carga tras un error")
    }

    private var textEmptyTitle: String {
        Language.getLanguageString(key: "PHRASE_NO_NOTES_YET", comment: "Título del estado vacío cuando no hay ninguna nota")
    }

    private var textEmptyMessage: String {
        Language.getLanguageString(key: "PHRASE_WRITE_FIRST_NOTE", comment: "Estado vacío: cómo crear la primera nota")
    }

    private var textNewNote: String {
        Language.getLanguageString(key: "PHRASE_NEW_NOTE", comment: "Botón de la barra que crea una nota")
    }
}

#if DEBUG
#Preview("Lista") {
    ScreenNoteList(factory: .preview(), router: InteractorNoteDeepLink())
}

#Preview("Lista vacía") {
    ScreenNoteList(factory: .preview(notes: []), router: InteractorNoteDeepLink())
}
#endif
