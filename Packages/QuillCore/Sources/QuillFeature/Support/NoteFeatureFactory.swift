public import QuillDomain

/// How the app hands built view models to this module.
///
/// The feature module owns its views and view models but must not own the object
/// graph: it has no way to construct a `SwiftDataNoteRepository` (it cannot import
/// `QuillData`) and no business deciding what the base URL is. The app's
/// composition root fills in these closures, and previews and tests fill in
/// fakes — with no service locator or global singleton in between.
@MainActor
public struct NoteFeatureFactory: Sendable {
    public var makeListViewModel: @MainActor () -> NoteListViewModel
    public var makeEditorViewModel: @MainActor (Note) -> NoteEditorViewModel

    public init(
        makeListViewModel: @escaping @MainActor () -> NoteListViewModel,
        makeEditorViewModel: @escaping @MainActor (Note) -> NoteEditorViewModel
    ) {
        self.makeListViewModel = makeListViewModel
        self.makeEditorViewModel = makeEditorViewModel
    }
}
