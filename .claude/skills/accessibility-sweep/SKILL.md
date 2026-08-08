---
name: accessibility-sweep
description: 'Barrido de accesibilidad sobre una vista SwiftUI del proyecto Quill. Detecta elementos interactivos sin accessibilityLabel/accessibilityHint, acciones que solo existen como swipe, strings hardcodeadas y tamaños de fuente fijos; agrega textos localizados en los 4 idiomas reusando keys existentes y verifica con build. Usar cuando el desarrollador pida "completar accesibilidad", "/accessibility-sweep <archivo>", o cuando una vista nueva requiera cobertura a11y.'
---

# Accessibility Sweep

## Cuándo usar este skill

Aplicar a una vista SwiftUI de `Packages/QuillCore/Sources/QuillFeature/UI/` para garantizar cobertura de VoiceOver, Dynamic Type y acciones alternativas. Produce cambios listos para commit con build verificado.

## Contrato (reglas estrictas)

1. **NUNCA hardcodear strings** en `.accessibilityLabel` / `.accessibilityHint`. Siempre por una propiedad `text<Algo>` que llame a `Language.getLanguageString(key:comment:)`.
2. **Reusar keys existentes** antes de crear nuevas. Grep del `.xcstrings` por contenido equivalente.
3. **Convención de keys nuevas:** `WORD_<UPPER>` para una palabra, `PHRASE_<UPPER_SNAKE>` para dos o más.
4. **4 idiomas obligatorios** en cada key nueva: `en`, `es`, `ht`, `pt`, en estado `translated`.
5. **Toda acción que solo exista como swipe va también en `.accessibilityActions`.** Un `swipeActions` es invisible para VoiceOver y para Switch Control: si `ViewNoteRow` no duplicara fijar y eliminar ahí, un usuario de VoiceOver no podría borrar una nota.
6. **Dynamic Type:** prohibido `.font(.system(size:))` con tamaño fijo. Usar `.body`, `.headline`, `.caption`. Si el layout se rompe a tamaños grandes, consultar `@Environment(\.dynamicTypeSize)` y cambiar la disposición — nunca capar el tamaño.
7. **Imágenes decorativas:** `.accessibilityHidden(true)`. Si el icono repite algo que ya dice la label del contenedor, es decorativo.
8. **Filas compuestas:** `.accessibilityElement(children: .ignore)` más una label compuesta, para que VoiceOver lea la fila como una sola frase en vez de cuatro swipes.

## Flujo de ejecución

### Paso 1 — Inventario

Listar en la vista: elementos interactivos sin label, imágenes sin `accessibilityHidden`, strings hardcodeadas, tamaños de fuente fijos y acciones que solo existan como gesto.

### Paso 2 — Corregir

Aplicar el contrato. Las keys nuevas van al catálogo en los 4 idiomas antes de usarse.

### Paso 3 — Verificar

```sh
make lint && make build
```

Y revisar el `#Preview` de la vista a `.dynamicTypeSize(.accessibility3)` — si no existe ese preview, agregarlo: es la forma más rápida de ver el layout roto sin arrancar el simulador.

### Paso 4 — Reporte

Qué se agregó, qué keys se reusaron y qué keys nuevas se crearon.
