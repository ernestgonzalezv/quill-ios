---
name: localizable-sweep
description: 'Barrido total de Localizable.xcstrings del proyecto Quill. Detecta entradas incompletas (estado "new", idiomas faltantes, vacías) y completa traducciones en los 4 idiomas soportados (en/es/ht/pt). Reusa traducciones existentes semánticamente equivalentes. Reporta cobertura antes/después. Usar cuando el desarrollador pida "completar traducciones", "sweep de localización", "/localizable-sweep", o cuando una pantalla muestre keys sin traducir.'
---

# Localizable Sweep

## Cuándo usar este skill

Aplicar a `Packages/QuillCore/Sources/QuillFeature/Resources/Localizable.xcstrings` para garantizar cobertura completa en 4 idiomas. El skill termina cuando el archivo alcance el 100% en estado `translated`.

## Contrato (reglas estrictas)

1. **4 idiomas obligatorios:** `en`, `es`, `ht` (Haitian Creole), `pt` (Brazilian Portuguese). Si un idioma falta, agregarlo.
2. **Estado correcto:** keys completas → `translated`. Nunca dejar `new` si hay valor.
3. **Reusar traducciones existentes** antes de inventar. Buscar en el mismo archivo otras entradas con valor `en` igual o semánticamente equivalente.
4. **Convención de keys:**
   - Una palabra → `WORD_<UPPER>` (ej. `WORD_DELETE`)
   - Dos o más → `PHRASE_<UPPER_SNAKE>` (ej. `PHRASE_SEARCH_NOTES`)
5. **`shouldTranslate: false`** → respetar. Símbolos y formatos (`%lld`, `--:--`) no se traducen.
6. **Comentarios:** el `comment` que se pasa en `Language.getLanguageString(key:comment:)` es el contexto del traductor. Si una key no tiene `comment` en el catálogo, agregarlo tomándolo del call site.
7. **Plurales en el catálogo, no en Swift.** Si una key necesita singular/plural, va como `variations.plural` con `one`/`other` por idioma. `count == 1 ? "nota" : "notas"` es incorrecto en la mayoría de los idiomas.
8. **Sweep total por defecto.** No solo las keys que el usuario mencionó.
9. **Reporte de cobertura obligatorio** antes y después.

## Flujo de ejecución

### Paso 1 — Inventario inicial

Leer el catálogo y calcular por idioma: keys totales, keys `translated`, keys `new` o ausentes, y el porcentaje.

```
Cobertura inicial:
- en: X/N (Y%)
- es: X/N (Y%)
- ht: X/N (Y%)
- pt: X/N (Y%)
```

### Paso 2 — Detectar keys huérfanas en ambos sentidos

- **En el catálogo pero sin usar:** grep de cada key en `Packages/` y `App/`. Una key sin call site es candidata a borrarse — pregunta antes.
- **Usadas pero sin entrada:** grep de `getLanguageString(key: "` en el código y contrastar contra el catálogo. Una key sin entrada se renderiza como su propio nombre en producción. Estas se agregan siempre.

### Paso 3 — Completar

Para cada entrada incompleta, escribir los 4 idiomas con estado `translated`, reusando traducciones equivalentes ya presentes.

### Paso 4 — Verificar

```sh
make test && make lint && make build
```

El build tiene que seguir verde: una key mal formada en el `.xcstrings` rompe la compilación del recurso.

### Paso 5 — Reporte final

Cobertura después, número de keys agregadas, número de traducciones completadas y las keys huérfanas encontradas.
