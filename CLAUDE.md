# CLAUDE.md - Quill iOS App

## Interaction Instructions
- ALWAYS respond in SPANISH
- NEVER give only the full code directly. Always explain what is behind.
- Explain concepts with analogies before showing syntax
- Celebrate when the user solves something on their own

## Communication Style
- Be concise. Avoid verbose clarifying questions — ask one focused question at a time
- Don't create plan files (`tasks/todo.md` etc.) unless explicitly requested
- Don't do extensive codebase exploration before providing initial guidance — propose a direction first, then explore as needed
- Tight explanations, not exhaustive ones

## Workflow Orchestration

### 1. Planning Node Default
- Enter planning mode for ANY non-trivial task (3+ steps or architectural decisions)
- If something goes wrong, STOP and re-plan immediately - do not keep forcing it
- Use planning mode for verification steps, not only for implementation
- Write detailed specifications in advance to reduce ambiguity

### 2. Subagent Strategy
- Use subagents generously to keep the main context window clean
- Offload research, exploration, and parallel analysis to subagents
- For complex problems, allocate more compute through subagents
- One approach per subagent for focused execution

### 3. Self-Improvement Cycle
- After ANY user correction: update `tasks/lessons.md` with the pattern
- Write rules for yourself to avoid repeating the same mistake
- Iterate relentlessly on these lessons until the error rate decreases

### 4. Verification Before Finishing
- Never mark a task as completed without proving it works
- `make test` green, `make lint` clean and `make build` succeeding before you say "listo"
- Ask yourself: "Would a senior engineer approve this?"
- Run tests, verify logs, and demonstrate the fix

### 5. Enforce Elegance (Balanced)
- For non-trivial changes: pause and ask, "is there a more elegant way?"
- Skip this for simple and obvious fixes - do not over-engineer
- Challenge your own work before presenting it

### 6. Autonomous Error Fixing
- When you are given an error report: just fix it. Do not ask to be hand-held
- Point out logs, errors, and failed tests, then resolve them
- Go fix failing CI tests without being told how

## Core Principles
**Simplicity First**: Make each change as simple as possible. Touch the minimum code.
**No Laziness**: Find root causes. No temporary fixes. Senior developer standards.
**Minimal Impact**: Changes should touch only what is necessary. Avoid introducing bugs.

## Project
- **iOS App** built with **SwiftUI**
- **Architecture:** MVVM + Clean Architecture
- **Xcode project:** `Quill.xcodeproj`, **generado** desde `project.yml` con XcodeGen (ver ADR-004)
- **Main branch:** `main`
- **Development branch:** `develop`
- **GitFlow:** ramas `feature/*` → `develop` con merge `--no-ff`; `release/*` → `main` + tag

## Project Structure
```
App/Quill/
  App/            -> Entry point (QuillApp) y Constants/ConstantsAPI
  Factorys/       -> Dependency injection (FactoryApp, la composition root)
  Interactors/    -> Efectos de borde del target app (Spotlight, AppIntents)
  Utilities/      -> Extensiones Type+Feature (URLSession+Quill)
Packages/QuillCore/Sources/
  QuillDomain/    -> Swift puro, sin I/O ni UI
    Models/Entities   -> Note, NoteDraft, NoteOrder
    Models/Protocol   -> los puertos: ProtoNoteRepository, ProtoRemoteNoteStore…
    Models/Error+Mapper -> NoteError
    ModelLogic/       -> lógica de negocio: LogicCreateNote, LogicSyncNotes…
    Interactors/      -> InteractorSystemDate (leer el reloj ya es un efecto)
    Utilities/        -> String+TrimmedOrNil
  QuillData/      -> Adaptadores
    Interactors/Networking   -> InteractorHTTPURLSession, InteractorNoteRemote
    Interactors/Persistence  -> InteractorNotePersistence (SwiftData)
    Interactors/Sync         -> InteractorNoteSync
    Models/DTOs, Models/Entities, Models/Error+Mapper
    Utilities/        -> ISO8601, JSONDecoder+Quill, ModelContainer+Quill…
  QuillFeature/   -> SwiftUI + view models. Depende del dominio, NUNCA de QuillData
    UI/               -> ScreenNoteList, ScreenNoteEditor, ViewNoteRow
    ViewModel/        -> ViewModelNoteList, ViewModelNoteEditor
    Factorys/         -> FactoryNote
    Interactors/      -> InteractorNoteDeepLink
    Models/Entities/Delegates -> DelegateUINoteRow
    Utilities/Language -> Language
    Resources/        -> Localizable.xcstrings
Packages/QuillCore/Tests/  -> LogicTests, ViewModelTests, InfraestructureTests, Mocks
```

## Code Conventions
- **Indentation:** 4 spaces
- **Protocols:** `Proto` prefix (e.g. `ProtoNoteRepository`, `ProtoInteractorHTTP`)
- **Extensions:** `Type+Feature.swift` pattern (`URLSession+Quill.swift`, `Error+UserFacingMessage.swift`). Una extensión de un tipo ajeno NUNCA vive dentro del archivo de otro tipo
- **Files:** one main type per file, file name = type name. Un tipo acompañante que solo existe como payload del principal (`SyncReport` junto a `LogicSyncNotes`, `MergeResult` junto a `LogicNoteMerger`) sí se queda en el mismo archivo
- **Cabecera de archivo obligatoria** al estilo Xcode: `//`, `//  <Archivo>.swift`, `//  Quill`, `//`, `//  Created by Ernesto on <fecha>.`, `//`
- **Naming:** `UpperCamelCase` para tipos, `lowerCamelCase` para métodos/propiedades
- **Delegates for Views:** NUNCA closures (`var onAction: () -> Void = {}`) para acciones de una View. Siempre el patrón Delegate:
  - Protocolo `@MainActor protocol DelegateUI<Name>` en `Models/Entities/Delegates/DelegateUI<Name>.swift`
  - Las funciones llevan prefijo derivado del protocolo (`DelegateUINoteRow` → `func noteRow...`)
  - En la View se declara `let delegate: (any DelegateUI<Name>)?` — siempre Optional, para que un Preview pase `nil`
- **Textos:** ninguna string visible hardcodeada. Extrae a una propiedad `text<Algo>` que llame a `Language`

## Architecture Patterns (Interactors, Side Effects)
Reglas OBLIGATORIAS. Implementación de referencia: `InteractorNotePersistence` / `ProtoNoteRepository`.

- **`Interactor` como PREFIJO, nunca como sufijo.** Los objetos con efectos de borde son `Interactor<Feature>`. NO usamos la arquitectura `Presenter` — nunca crees `...Presenter` ni singletons `...Coordinator` improvisados.
- **Ubicación:** los interactors viven en `Interactors/<Feature>/`, NO bajo `ViewModel/`.
- **Siempre detrás de un protocolo `Proto`.** Todo interactor que cruza una capa expone un protocolo para poder mockearlo en tests y previews. Se inyecta por `init` tipado como el protocolo, nunca instanciando el tipo concreto dentro del ViewModel.
- **Nada de closures para notificar hacia atrás.** Preferir una única función `async` que devuelva el resultado. Un `AsyncStream` (como `ProtoNoteRepositoryObserving.changes`) solo cuando el interactor emite varios eventos a lo largo del tiempo.
- **Views: los callbacks SIEMPRE por `DelegateUI<Name>`.**

## Localization Conventions
- File: `Packages/QuillCore/Sources/QuillFeature/Resources/Localizable.xcstrings`
- Source language: `en`. Idiomas obligatorios: `en`, `es`, `ht`, `pt`
- Prefijo de key: `WORD_<MAYÚSCULA>` para una palabra, `PHRASE_<MAYÚSCULA_SNAKE>` para dos o más
- Al agregar una key nueva, traduce en LOS 4 idiomas con estado `translated`
- Reusa keys existentes antes de crear nuevas: greppea el xcstrings
- Usa `Language.getLanguageString(key:comment:)`, pasando SIEMPRE el `comment` como contexto para quien traduce

## Swift/Xcode Project Conventions
- El `.xcodeproj` es **generado**: se edita `project.yml` y se corre `make project`. Un archivo nuevo NO hay que agregarlo a mano al proyecto, pero sí regenerar y commitear
- El CI falla si `Quill.xcodeproj` derivó de `project.yml`
- Mappers: parámetro llamado `item` (no `dto`); cada propiedad en su propio `let` antes de construir el modelo
- Mirror conventions of nearby files when in doubt

## Swift Concurrency Conventions
- Swift 6 language mode con `SWIFT_STRICT_CONCURRENCY: complete` — data-race checking completo, no el `minimal` por defecto
- Los view models son `@MainActor @Observable`; los repositorios son actores alcanzados desde el main actor
- Warning "Unstructured throwing task ... is not used": se silencia con `_ = Task { ... }` (descarte explícito). NO con `do/catch`, NO guardando la task

## Accessibility Defaults
- Toda View nueva incluye `accessibilityLabel`/`accessibilityHint` con strings localizadas (nunca hardcodeadas)
- Imágenes decorativas: `.accessibilityHidden(true)`
- Nada de tamaños de fuente hardcodeados — usa Dynamic Type (`.body`, `.headline`…)
- Toda acción que solo exista como swipe se expone también en `.accessibilityActions`

## Swift Formatting
1. Prefer single-line expressions when they are short and readable.
2. For initializers and chained calls, keep a single line if the expression is 140 characters or fewer.
3. Split into multiple lines only when the expression exceeds 140 characters or readability clearly improves.
4. If an expression is already on one line and within the limit, do not reformat it into multiple lines.
5. Never add a newline immediately after `(` or immediately before `)`.
6. Never chain multiple transforming operations on one line. Break each step into its own `let` with a descriptive name.
7. Array literals: NEVER put `[` or `]` alone on its own line.

## Commits
- In Spanish, dash-prefixed format: `- Added ...`, `- Updated ...`, `- Fixed ...`
- **Ernesto va SIEMPRE como único autor.** Nada de `Co-Authored-By`, ni trailers, ni menciones de herramientas

## Build and Tests
```sh
make project   # regenera Quill.xcodeproj desde project.yml
make test      # swift test sobre Packages/QuillCore (50 tests)
make lint      # swiftlint --strict
make build     # xcodebuild sobre simulador
```

## Harness local (`.claude/`)
- `.claude/hooks/format-swift.sh` — corre en cada `Write`/`Edit` de un `.swift` y reporta las violaciones de formato (140 caracteres, saltos alrededor de paréntesis). No auto-corrige: devuelve el aviso para que la siguiente edición ya salga bien
- `.claude/agents/quill-architecture-explorer.md` — traza una feature por las capas (pantalla → view model → Logic → puerto → adaptador) sin editar nada
- `.claude/agents/swift-formatting-reviewer.md` — revisa el formato contra las 7 reglas de arriba
- `tasks/lessons.md` — lo aprendido de correcciones reales. Se lee al empezar y se escribe en el momento de la corrección

## Available Skills
- **localizable-sweep** — barrido de `Localizable.xcstrings`: completa los 4 idiomas, detecta keys huérfanas en ambos sentidos y reporta cobertura. Trigger: `/localizable-sweep` o "completa traducciones"
- **accessibility-sweep** — barrido a11y sobre una vista: labels localizadas, acciones de swipe duplicadas en `.accessibilityActions`, Dynamic Type. Trigger: `/accessibility-sweep <archivo>` o "completa accesibilidad de X"

## Key Technologies
- SwiftUI + Observation
- SwiftData (persistencia local)
- App Intents / Siri Shortcuts
- Core Spotlight (indexado en búsqueda del sistema)
- URLSession + sincronización last-write-wins
