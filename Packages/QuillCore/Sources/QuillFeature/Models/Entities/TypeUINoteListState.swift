//
//  TypeUINoteListState.swift
//  Quill
//
//  Created by Ernesto on 8/8/26.
//

public import QuillDomain

/// Lo que la lista de notas puede estar mostrando.
///
/// Un único valor en vez de banderas paralelas. `isLoading` + `notes` + `error`
/// permite estados sin sentido — cargando *y* fallado a la vez — y obliga a cada
/// vista a inventarse una precedencia. Así los estados ilegales no se pueden
/// ni escribir, y la vista es una función total de este enum.
public enum TypeUINoteListState: Equatable, Sendable {
    case loading
    case loaded([Note])
    case empty(TypeUINoteListEmpty)
    case failed(message: String)
}
