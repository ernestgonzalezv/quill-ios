//
//  TypeUINoteSyncStatus.swift
//  Quill
//
//  Created by Ernesto on 8/8/26.
//

/// En qué punto va la sincronización.
///
/// Vive aparte de ``TypeUINoteListState`` a propósito: un fallo de red no debe
/// poder reemplazar la lista que ya está en pantalla, porque esas notas siguen
/// siendo datos locales válidos.
public enum TypeUINoteSyncStatus: Equatable, Sendable {
    case idle
    case syncing
    case failed(message: String)
}
