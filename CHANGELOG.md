# Changelog

All notable changes are documented here. This project follows
[Semantic Versioning](https://semver.org) and
[Keep a Changelog](https://keepachangelog.com).

## [Unreleased]

### Changed

- **Convenciones alineadas con Cococel.iOS.** Los tipos pasan a llevar prefijo por
  responsabilidad — `Proto` para protocolos, `Interactor` para efectos de borde,
  `Logic` para lógica de negocio, `Screen`/`View`/`ViewModel` para UI y `Factory`
  para inyección de dependencias — y las carpetas al vocabulario
  `Models/`, `ModelLogic/`, `Interactors/`, `UI/`, `ViewModel/`, `Factorys/`,
  `Utilities/`. Los nombres de 1.0.0 (`NoteListViewModel`, `SwiftDataNoteRepository`,
  `SyncCoordinator`…) ya no existen.
- **Localización a cuatro idiomas** (en, es, ht, pt) con keys `WORD_`/`PHRASE_` y
  un único punto de acceso, `Language.getLanguageString(key:comment:)`.
- **Acciones de fila por delegate.** `ViewNoteRow` expone fijar y eliminar a
  través de `DelegateUINoteRow` en vez de que la pantalla cablee closures.

### Added

- Workflows `ios-ci.yml` y `pr-main-ci.yml`, con filtrado de cambios de solo
  documentación y verificación de que la configuración Release apunta a producción.

## [1.0.0] — 2026-08-06

First release.

### Added

- **Notes**: create, edit, pin, soft-delete and search, with autosave that
  flushes on both navigation and scene backgrounding.
- **Offline-first storage** on SwiftData, reached only through a repository port.
  The local store is the source of truth; every read and write works with no
  network.
- **Sync engine** with last-write-wins conflict resolution and tombstoned deletes,
  so a delete propagates between devices instead of the note reappearing on the
  next pull. Conflict resolution is a pure function (`NoteMerger`) and the sync
  cursor tracks server time, never device time.
- **Retrying HTTP client** with exponential backoff and full jitter, composed as a
  decorator so retry can be added or omitted per call site.
- **Siri, Shortcuts and Action button** support via `CreateNoteIntent`, which
  writes through the same use case as the UI without launching the app.
- **Spotlight indexing** with deep links back into the editor. Deleted notes are
  removed from the index so tombstoned text is not searchable.
- **Accessibility**: composed VoiceOver labels per row, swipe actions mirrored as
  accessibility actions, and Dynamic Type through to accessibility sizes.
- **Localisation** in English and Spanish via a String Catalog, with correct
  pluralisation and compile-checked keys.
- **50 tests** across the domain, adapters and view models, running without a
  simulator. Time, randomness and sleeping are injected, so none of them sleep.
- **CI** running the test suite, an app build that fails on project-file drift, and
  SwiftLint in strict mode.
- **Documentation**: architecture notes and four ADRs recording what each decision
  costs, not only what was chosen.

### Fixed

Three bugs the test suite surfaced while it was being written:

- `UpdateNote` compared notes *after* stamping `updatedAt`, so its no-op guard
  never fired. Opening and closing the editor without typing would bump the
  timestamp and win a sync conflict against a real edit made on another device.
- `purgeTombstones` used a force-unwrapped optional inside a `#Predicate`, which
  SwiftData rejects at runtime rather than compile time — a crash on the first
  tombstone purge in production.
- Documented that the wire format truncates timestamps to milliseconds, which is
  why two edits inside the same millisecond fall through to the merger's
  tie-break rule rather than being ordered.

### Known limitations

- Last-write-wins loses one side of a genuinely concurrent edit. See
  [ADR-002](Docs/ADR-002-conflict-resolution.md).
- No widget, rich text, attachments, or background refresh yet.
- `QUILL_API_BASE_URL` points at a placeholder host, so sync fails out of the box
  while local storage keeps working — the intended degradation path.

[1.0.0]: https://github.com/ernestgonzalezv/quill-ios/releases/tag/v1.0.0
