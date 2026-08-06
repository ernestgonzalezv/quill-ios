# ADR-004 — Generate the Xcode project from `project.yml`

**Status:** Accepted · **Date:** 2026-08-06

## Context

`project.pbxproj` is a generated, ID-keyed format. It conflicts on nearly every
concurrent branch that adds a file, the conflicts are resolved by guessing, and
the diff is unreviewable in a pull request. On a repo whose point is to
demonstrate a clean branching workflow, that is the wrong thing to hand-maintain.

## Options considered

**1. Commit and hand-edit `Quill.xcodeproj`.** The default. Zero setup for anyone
cloning. Merge conflicts on every parallel branch.

**2. XcodeGen.** Chosen. A ~70-line YAML manifest is the source of truth; the
project is regenerated on demand. Build settings become reviewable text.

**3. Tuist.** More capable — Swift-defined projects, caching, graph validation.
Heavier to set up and more to learn than this repo needs.

**4. No Xcode project; SPM only.** Cleanest, but a package cannot be a runnable
iOS app, and a notes app you cannot launch is not a portfolio piece.

## Decision

XcodeGen, with `project.yml` as the source of truth.

**The generated `Quill.xcodeproj` is also committed.** That is not the usual
XcodeGen advice, and it is a deliberate trade for this repo: a reviewer or
recruiter cloning it can double-click and run without first installing a tool via
Homebrew. The cost is that the generated file can drift from the manifest, which
CI guards against by regenerating and failing if the result differs.

## Consequences

**Good**

- Build settings live in reviewable YAML. `SWIFT_STRICT_CONCURRENCY: complete` is
  visible in a diff instead of buried in a build-settings pane.
- Adding files does not touch the project file, so feature branches stop
  conflicting over it.
- Per-configuration values (`QUILL_API_BASE_URL`) are explicit and diffable.
- The repo still opens with a double-click.

**Bad, and accepted**

- The committed `.xcodeproj` can drift from `project.yml`. Mitigated by a CI check
  that regenerates and diffs, but it is one more thing that can go red.
- Contributors editing settings through Xcode's UI will have their changes
  overwritten by the next `make project`. `project.yml` is the only place to edit.
- XcodeGen is a Homebrew dependency for anyone changing project structure.

## Revisit if

The project grows several targets and extensions with interdependencies, where
Tuist's graph validation and caching would start to pay for its extra weight.
