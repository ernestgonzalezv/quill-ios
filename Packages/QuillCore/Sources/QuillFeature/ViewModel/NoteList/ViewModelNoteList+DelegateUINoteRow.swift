//
//  ViewModelNoteList+DelegateUINoteRow.swift
//  Quill
//
//  Created by Ernesto on 8/8/26.
//

internal import QuillDomain

/// Las acciones de la fila entran por aquí.
///
/// El protocolo es síncrono porque quien llama es un botón de SwiftUI, que no
/// tiene dónde esperar un `await`; el trabajo real se delega al método `async`
/// correspondiente, que ya sabe recargar y reportar el error en `state`.
extension ViewModelNoteList: DelegateUINoteRow {
    func noteRowTogglePin(_ note: Note) {
        Task { await togglePin(note) }
    }

    func noteRowDelete(_ note: Note) {
        Task { await delete(note) }
    }
}
