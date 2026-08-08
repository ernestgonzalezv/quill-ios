//
//  FactoryNote.swift
//  Quill
//
//  Created by Ernesto on 8/6/26.
//

public import QuillDomain

/// How the app hands built view models to this module.
///
/// The feature module owns its views and view models but must not own the object
/// graph: it has no way to construct a `InteractorNotePersistence` (it cannot import
/// `QuillData`) and no business deciding what the base URL is. The app's
/// composition root fills in these closures, and previews and tests fill in
/// fakes — with no service locator or global singleton in between.
// `Sendable` no hace falta: al estar aislado al main actor, el compilador ya
// garantiza que no cruza fronteras de aislamiento sin sincronizar.
@MainActor
public struct FactoryNote {
    public var makeListViewModel: @MainActor () -> ViewModelNoteList
    public var makeEditorViewModel: @MainActor (Note) -> ViewModelNoteEditor

    public init(
        makeListViewModel: @escaping @MainActor () -> ViewModelNoteList,
        makeEditorViewModel: @escaping @MainActor (Note) -> ViewModelNoteEditor
    ) {
        self.makeListViewModel = makeListViewModel
        self.makeEditorViewModel = makeEditorViewModel
    }
}
