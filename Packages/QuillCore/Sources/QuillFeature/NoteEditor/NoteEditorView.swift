public import SwiftUI

/// Title + body editor with autosave.
///
/// There is no Save button by design — see ``NoteEditorViewModel``. The two places
/// text could otherwise be lost are both covered:
///
/// - `onDisappear` flushes when the user navigates back.
/// - A `.background` scene phase flushes when the app is swiped away or the device
///   locks, which `onDisappear` does *not* fire for.
public struct NoteEditorView: View {
    @State private var viewModel: NoteEditorViewModel
    @Environment(\.scenePhase) private var scenePhase
    @FocusState private var focus: Field?

    private enum Field: Hashable {
        case title
        case body
    }

    public init(viewModel: NoteEditorViewModel) {
        _viewModel = State(wrappedValue: viewModel)
    }

    public var body: some View {
        Form {
            Section {
                TextField(text: $viewModel.draft.title) {
                    Text(L10n.editorTitlePlaceholder)
                }
                .font(.headline)
                .focused($focus, equals: .title)
                // Sentence case, not the keyboard default, because a note title
                // is prose rather than a name.
                .textInputAutocapitalizationCompat()
                .submitLabel(.next)
                .onSubmit { focus = .body }
            }

            Section {
                TextEditor(text: $viewModel.draft.body)
                    .frame(minHeight: 240)
                    .focused($focus, equals: .body)
                    .accessibilityLabel(Text(L10n.editorBodyPlaceholder))
                    .overlay(alignment: .topLeading) {
                        // TextEditor has no placeholder API; this is the standard
                        // workaround, hidden from accessibility since the field
                        // already carries the same label.
                        if viewModel.draft.body.isEmpty {
                            Text(L10n.editorBodyPlaceholder)
                                .foregroundStyle(.tertiary)
                                .padding(.top, 8)
                                .allowsHitTesting(false)
                                .accessibilityHidden(true)
                        }
                    }
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle(navigationTitle)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Toggle(isOn: $viewModel.draft.isPinned) {
                    Label {
                        Text(viewModel.draft.isPinned ? L10n.notesUnpin : L10n.notesPin)
                    } icon: {
                        Image(systemName: viewModel.draft.isPinned ? "pin.fill" : "pin")
                    }
                }
                .toggleStyle(.button)
            }
        }
        .onDisappear {
            // Detached from the view's lifetime on purpose: `onDisappear` returns
            // immediately, so a Task tied to the view would be cancelled before the
            // write completed and the last edit would be lost.
            let viewModel = viewModel
            Task { await viewModel.flush() }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .background else { return }
            let viewModel = viewModel
            Task { await viewModel.flush() }
        }
    }

    private var navigationTitle: String {
        let trimmed = viewModel.draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? String(localized: L10n.editorNewTitle) : trimmed
    }
}

private extension View {
    /// `textInputAutocapitalization` is iOS/tvOS/watchOS only; this keeps the call
    /// site free of `#if` so the view body stays readable on both platforms.
    @ViewBuilder
    func textInputAutocapitalizationCompat() -> some View {
        #if os(iOS) || os(tvOS) || os(watchOS)
        self.textInputAutocapitalization(.sentences)
        #else
        self
        #endif
    }
}
