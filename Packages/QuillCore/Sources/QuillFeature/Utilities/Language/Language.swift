//
//  Language.swift
//  Quill
//
//  Created by Ernesto on 8/8/26.
//

import Foundation

/// Único punto de acceso a los textos traducidos.
///
/// Dos razones para que todo pase por aquí en vez de escribir `String(localized:)`
/// suelto en cada vista:
///
/// 1. Las strings de un paquete Swift no resuelven contra `Bundle.main`. Cada
///    lookup tiene que nombrar `Bundle.module`, y centralizarlo es lo que impide
///    que una vista se olvide y publique una pantalla sin traducir.
/// 2. El `comment` viaja con la key hasta el catálogo, que es el contexto que el
///    traductor necesita para elegir entre "fijar una nota" y "fijar un precio".
///
/// Convención de keys: `WORD_<MAYÚSCULA>` para una palabra suelta y
/// `PHRASE_<MAYÚSCULA_CON_GUIONES_BAJOS>` para dos o más. Antes de crear una key
/// nueva, greppea el catálogo: reusar la existente es siempre preferible.
public enum Language {
    /// Devuelve el texto traducido al idioma activo del sistema.
    ///
    /// Pasa SIEMPRE el `comment`: es lo único que ve quien traduce.
    public static func getLanguageString(key: String, comment: String) -> String {
        NSLocalizedString(key, bundle: .module, comment: comment)
    }

    /// Variante para las keys con plural declarado en el catálogo.
    ///
    /// La pluralización vive en las variations del `.xcstrings`, no en Swift:
    /// `count == 1 ? "nota" : "notas"` es incorrecto en la mayoría de los idiomas.
    public static func getLanguageString(key: String, count: Int, comment: String) -> String {
        let format = NSLocalizedString(key, bundle: .module, comment: comment)
        return String(format: format, count)
    }
}
