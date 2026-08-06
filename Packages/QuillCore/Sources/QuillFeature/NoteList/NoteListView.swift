public import SwiftUI
internal import QuillDomain

/// The app's root screen: a searchable list of notes that pushes the editor.
///
/// The view is a pure function of `viewModel.state` — one `switch`, one branch per
/// case, no `if isLoading` chains. Adding a state to the enum breaks this switch
/// at compile time, which is the point.
public struct NoteListView: View {
    private let factory: NoteFeatureFactory
    private let router: NoteRouter
    @State private var viewModel: NoteListViewModel
    @State private var path: [Note] = []

    public init(factory: NoteFeatureFactory, router: NoteRouter) {
        self.factory = factory
        self.router = router
        // `State(wrappedValue:)` so the view model is created once, at first
        // render, and survives the view struct being recreated on every update.
        _viewModel = State(wrappedValue: factory.makeListViewModel())
    }

    public var body: some View {
        NavigationStack(path: $path) {
            content
                .navigationTitle(Text(L10n.notesTitle))
                .searchable(text: $viewModel.searchQuery, prompt: Text(L10n.notesSearchPrompt))
                .refreshable { await viewModel.refresh() }
                .toolbar { toolbarContent }
                .safeAreaInset(edge: .bottom) { syncBanner }
                .navigationDestination(for: Note.self) { note in
                    NoteEditorView(viewModel: factory.makeEditorViewModel(note))
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
                        NoteRowView(note: note)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            Task { await viewModel.delete(note) }
                        } label: {
                            Label { Text(L10n.notesDelete) } icon: { Image(systemName: "trash") }
                        }
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            Task { await viewModel.togglePin(note) }
                        } label: {
                            Label { Text(pinLabel(for: note)) } icon: { Image(systemName: note.isPinned ? "pin.slash" : "pin") }
                        }
                        .tint(.orange)
                    }
                    // Swipes are invisible to VoiceOver and Switch Control, so the
                    // same two actions are exposed as accessibility actions.
                    .accessibilityActions {
                        Button(pinLabel(for: note)) { Task { await viewModel.togglePin(note) } }
                        Button(String(localized: L10n.notesDelete)) { Task { await viewModel.delete(note) } }
                    }
                }
            }
            .listStyle(.plain)

        case .empty(let reason):
            emptyView(for: reason)

        case .failed(let message):
            ContentUnavailableView {
                Label {
                    Text(L10n.notesRetry)
                } icon: {
                    Image(systemName: "exclamationmark.triangle")
                }
            } description: {
                Text(message)
            } actions: {
                Button(String(localized: L10n.notesRetry)) {
                    Task { await viewModel.reload() }
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    @ViewBuilder
    private func emptyView(for reason: NoteListViewModel.EmptyReason) -> some View {
        switch reason {
        case .noNotes:
            ContentUnavailableView {
                Label { Text(L10n.notesEmptyTitle) } icon: { Image(systemName: "note.text") }
            } description: {
                Text(L10n.notesEmptyMessage)
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
                Label { Text(L10n.notesNewNote) } icon: { Image(systemName: "square.and.pencil") }
            }
            .accessibilityLabel(Text(L10n.notesNewNote))
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

    private func pinLabel(for note: Note) -> LocalizedStringResource {
        note.isPinned ? L10n.notesUnpin : L10n.notesPin
    }
}
