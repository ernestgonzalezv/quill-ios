//
//  TypeUINoteListEmpty.swift
//  Quill
//
//  Created by Ernesto on 8/8/26.
//

/// Por qué la lista salió vacía.
///
/// Distinguir los dos vacíos importa: "escribe tu primera nota" es un consejo
/// activamente equivocado cuando el usuario tiene 200 notas y una búsqueda mal
/// tecleada.
public enum TypeUINoteListEmpty: Equatable, Sendable {
    case noNotes
    case noMatches(query: String)
}
