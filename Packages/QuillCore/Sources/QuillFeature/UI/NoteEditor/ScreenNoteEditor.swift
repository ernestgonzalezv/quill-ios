//
//  ScreenNoteEditor.swift
//  Quill
//
//  Created by Ernesto on 8/6/26.
//

public import SwiftUI

/// Title + body editor with autosave.
///
/// There is no Save button by design — see ``ViewModelNoteEditor``. The two places
/// text could otherwise be lost are both covered:
///
/// - `onDisappear` flushes when the user navigates back.
/// - A `.background` scene phase flushes when the app is swiped away or the device
///   locks, which `onDisappear` does *not* fire for.
public struct ScreenNoteEditor: View {
    @State private var viewModel: ViewModelNoteEditor
    @Environment(\.scenePhase) private var scenePhase
    @FocusState private var focus: Field?

    private enum Field: Hashable {
        case title
        case body
    }

    public init(viewModel: ViewModelNoteEditor) {
        _viewModel = State(wrappedValue: viewModel)
    }

    public var body: some View {
        Form {
            Section {
                TextField(text: $viewModel.draft.title) {
                    Text(textTitlePlaceholder)
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
                    .accessibilityLabel(Text(textBodyPlaceholder))
                    .overlay(alignment: .topLeading) {
                        // TextEditor has no placeholder API; this is the standard
                        // workaround, hidden from accessibility since the field
                        // already carries the same label.
                        if viewModel.draft.body.isEmpty {
                            Text(textBodyPlaceholder)
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
                        Text(textPin)
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
        let fallback = Language.getLanguageString(key: "PHRASE_NEW_NOTE_TITLE", comment: "Título de navegación del editor sin título")
        return trimmed.isEmpty ? fallback : trimmed
    }

    // MARK: - Textos

    private var textTitlePlaceholder: String {
        Language.getLanguageString(key: "WORD_TITLE", comment: "Placeholder del campo de título en el editor")
    }

    private var textBodyPlaceholder: String {
        Language.getLanguageString(key: "PHRASE_START_WRITING", comment: "Placeholder del cuerpo de la nota en el editor")
    }

    private var textPin: String {
        let key = viewModel.draft.isPinned ? "WORD_UNPIN" : "WORD_PIN"
        return Language.getLanguageString(key: key, comment: "Acción de fijar o dejar de fijar la nota abierta")
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
