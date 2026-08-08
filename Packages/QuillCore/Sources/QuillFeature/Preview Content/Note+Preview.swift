//
//  Note+Preview.swift
//  Quill
//
//  Created by Ernesto on 8/8/26.
//

#if DEBUG
internal import QuillDomain
import Foundation

extension Note {
    /// Notas de ejemplo para los Previews.
    ///
    /// Con fechas fijas y no `Date()`: un preview que se redibuja cada segundo
    /// porque el "hace 2 minutos" cambió no deja mirar el layout con calma.
    static let previewSamples: [Note] = [
        Note(
            title: "Compras",
            body: "Leche, huevos, café",
            isPinned: true,
            createdAt: Date(timeIntervalSince1970: 1_754_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_754_600_000)
        ),
        Note(
            title: "",
            body: "Una nota sin título, para ver que la fila no se queda vacía",
            createdAt: Date(timeIntervalSince1970: 1_754_100_000),
            updatedAt: Date(timeIntervalSince1970: 1_754_500_000)
        ),
        Note(
            title: "Ideas para el car wash",
            body: "Túnel expreso, membresía mensual, medir el tráfico de la avenida a las 7am",
            createdAt: Date(timeIntervalSince1970: 1_754_200_000),
            updatedAt: Date(timeIntervalSince1970: 1_754_400_000)
        )
    ]

    static var preview: Note { previewSamples[0] }
}
#endif
