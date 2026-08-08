//
//  FactoryNote+Preview.swift
//  Quill
//
//  Created by Ernesto on 8/8/26.
//

#if DEBUG
internal import QuillDomain

extension FactoryNote {
    /// La misma factory que usa la app, cableada contra el store en memoria.
    ///
    /// Los view models y los casos de uso son los de producción: lo único
    /// sustituido es el adaptador de persistencia. Así un preview muestra el
    /// comportamiento real, no una maqueta que puede divergir del código.
    @MainActor
    static func preview(notes: [Note] = Note.previewSamples) -> FactoryNote {
        let repository = MockNotePersistencePreview(notes: notes)
        let dates = InteractorSystemDate()

        return FactoryNote(
            makeListViewModel: {
                ViewModelNoteList(
                    loadNotes: LogicLoadNotes(repository: repository),
                    loadNote: LogicLoadNote(repository: repository),
                    createNote: LogicCreateNote(repository: repository, dates: dates),
                    deleteNote: LogicDeleteNote(repository: repository, dates: dates),
                    togglePin: LogicTogglePin(repository: repository, dates: dates),
                    storeChanges: repository
                )
            },
            makeEditorViewModel: { note in
                ViewModelNoteEditor(note: note, updateNote: LogicUpdateNote(repository: repository, dates: dates))
            }
        )
    }
}
#endif
