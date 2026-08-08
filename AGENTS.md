# Repository Guidelines

## Interaction Instructions
- ALWAYS respond in SPANISH
- NEVER give only the full code directly. Always explain what is behind.
- Explain concepts with analogies before showing syntax
- Celebrate when the user solves something on their own

## Project Structure & Module Organization
- `App/Quill/` holds the app target, organized by layers: `App/` (entry point + `Constants/`), `Factorys/` (dependency injection) and `Interactors/` (Spotlight, App Intents).
- `Packages/QuillCore/` holds the three library modules: `QuillDomain` (pure Swift: `Models/Entities`, `Models/Protocol`, `ModelLogic/`), `QuillData` (adapters under `Interactors/Networking`, `Interactors/Persistence`, `Interactors/Sync`) and `QuillFeature` (`UI/`, `ViewModel/`, `Factorys/`, `Utilities/Language`).
- `Packages/QuillCore/Tests/` contains the suites split by area (`LogicTests/`, `ViewModelTests/`, `InfraestructureTests/`) plus the doubles under `Mocks/`.
- Localized strings live in `Packages/QuillCore/Sources/QuillFeature/Resources/Localizable.xcstrings`. Architecture notes and ADRs live in `Docs/`.

## Build, Test, and Development Commands
- Open `Quill.xcodeproj` in Xcode for day-to-day development. It is **generated** — edit `project.yml`, never the `.pbxproj`.
- Regenerate the project after adding files:
  ```sh
  make project
  ```
- Run the test suite (no simulator needed):
  ```sh
  swift test --package-path Packages/QuillCore
  ```
- Build the app on a simulator:
  ```sh
  xcodebuild build -project Quill.xcodeproj -scheme Quill -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
  ```

## Coding Style & Naming Conventions
- Swift files use 4-space indentation and open with the Xcode-style header (`//  <File>.swift`, `//  Quill`, `//  Created by Ernesto on <date>.`).
- File names match the primary type (`ViewModelNoteList.swift`, `InteractorNotePersistence.swift`) and keep one main type per file.
- Extensions use the `Type+Feature.swift` pattern.
- Types use `UpperCamelCase`; methods/properties use `lowerCamelCase`. Protocols always use a `Proto` prefix (for example `ProtoNoteRepository`).
- Preferred patterns: MVVM with `ViewModel/` + `UI/`, business logic in `ModelLogic/` (`Logic` prefix), side effects in `Interactors/` (`Interactor` prefix), dependency injection in `Factorys/`.
- View callbacks always travel through a `DelegateUI<Name>` protocol — never closures.
- SwiftLint is configured (`.swiftlint.yml`) and runs `--strict` in CI.

## Swift Formatting
1. Prefer single-line expressions when they are short and readable.
2. For initializers and chained calls, keep a single line if the expression is 140 characters or fewer.
3. Split into multiple lines only when the expression exceeds 140 characters or readability clearly improves.
4. If an expression is already on one line and within the limit, do not reformat it into multiple lines.
5. Never add a newline immediately after `(` or immediately before `)`.

## Testing Guidelines
- Tests use the Swift Testing framework (`@Test`, `#expect`) and live under `Packages/QuillCore/Tests/`.
- Group tests by area and name them after what they assert.
- Add or adjust doubles under `Tests/QuillDomainTests/Mocks/` when new data is needed.

## Commit & Pull Request Guidelines
- Commits use Spanish, dash-prefixed summaries (for example `- Added ...`, `- Updated ...`, `- Fixed ...`). Keep the same style and tense.
- GitFlow: work on `feature/*`, merge into `develop` with `--no-ff`. Releases go through `release/*` into `main` with a tag.
- PRs should include a concise description and screenshots for UI changes, and call out the exact test command used.

## Security & Configuration Tips
- The API host is a build setting (`QUILL_API_BASE_URL` per configuration), read at launch by `ConstantsAPI`. Never branch on `#if DEBUG` for it.
- A PR into `main` fails if the Release configuration still points at staging.
