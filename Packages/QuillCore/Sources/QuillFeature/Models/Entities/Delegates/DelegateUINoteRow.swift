//
//  DelegateUINoteRow.swift
//  Quill
//
//  Created by Ernesto on 8/8/26.
//

internal import QuillDomain

/// Cómo una fila de la lista avisa hacia arriba.
///
/// El patrón es delegate y no closure a propósito. Una `View` con
/// `var onDelete: (Note) -> Void = {}` se puede construir sin pasar la acción y
/// compila igual: el bug aparece en runtime, con un botón que no hace nada. Con
/// un protocolo, quien recibe los eventos declara explícitamente que los maneja,
/// y el conjunto de acciones de la fila queda listado en un solo sitio.
///
/// Los nombres de las funciones llevan el prefijo derivado del protocolo
/// (`DelegateUINoteRow` → `noteRow...`), para que en el implementador se lea de
/// dónde viene la llamada sin ir a buscar la declaración.
@MainActor
protocol DelegateUINoteRow: AnyObject {
    func noteRowTogglePin(_ note: Note)
    func noteRowDelete(_ note: Note)
}
