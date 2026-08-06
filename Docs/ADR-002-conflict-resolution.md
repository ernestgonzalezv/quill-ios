# ADR-002 — Last-write-wins with tombstones for conflict resolution

**Status:** Accepted · **Date:** 2026-08-06

## Context

The app is offline-first: the local store is the source of truth and every write
succeeds without a network. Two devices can therefore edit the same note while
both are offline, and something has to decide what happens when they reconnect.

Deletes need the same treatment. If a delete is a plain row removal, the next pull
sees a note the device does not have, treats it as new, and the note comes back.
This is the single most common offline-sync bug.

## Options considered

**1. Server always wins.**
Trivial. Silently discards local edits, including ones made minutes ago while the
server's copy is a week old. Unacceptable for a notes app — losing typing is the
one failure users do not forgive.

**2. Last-write-wins on `updatedAt`.**
Chosen. Converges, is cheap, and is a pure function of two values, so every case
is a one-line test. Loses one side of a genuinely concurrent edit.

**3. Field-level merge.**
Merge `title` and `body` independently. Slightly better in practice, but two
devices editing the *same* field still lose one, and it adds per-field timestamps
to the wire format for a partial improvement.

**4. CRDT (per-character or RGA).**
Preserves both sides of a concurrent edit — the correct answer for collaborative
editing. Costs a much larger payload (per-character metadata), a real merge
implementation, and a migration path for existing notes. Overkill for a
single-user notes app where concurrent edits to one note are rare.

## Decision

**Last-write-wins on `updatedAt`, with deletes winning ties.** Implemented as
`NoteMerger` — a pure function with no I/O, no clock and no store.

Deletes are **soft**: a note with a non-nil `deletedAt` is a tombstone that stays
in the store and syncs like any other change. Its content is cleared on deletion,
so deleted text cannot leak through a stale cache or the Spotlight index.

Tie-breaking, in order:

1. Later `updatedAt` wins.
2. Equal timestamps, one side deleted → **the tombstone wins**. A delete is not
   recoverable by the user; a lost edit is retypable.
3. Equal timestamps, both live, different content → **remote wins**. Arbitrary but
   *deterministic*: every device replaying the pair reaches the same answer.
   Preferring local would let two devices each keep their own version and never
   converge.

Supporting requirements:

- Every mutation goes through a method that stamps `updatedAt`
  (`Note.edited(with:at:)` and friends), so a timestamp cannot silently drift.
- All timestamps come from an injected `DateProvider`, which is what makes the
  rules testable without sleeping.
- Wire format sends **fractional seconds**. Whole-second precision makes
  near-simultaneous edits tie constantly and fall through to rule 3.
- Tombstones are purged only after a successful sync, and only past a lifetime
  (30 days) that must exceed the longest plausible offline stretch for another
  device.

## Consequences

**Good**

- Converges, provably, and the proof is a unit test rather than an argument.
- `NoteMerger` is the first and only place to look when a sync bug appears.
- Deletes propagate correctly instead of resurrecting.

**Bad, and accepted**

- **A concurrent edit loses one side wholesale.** Two devices editing the same
  note while both offline: the later timestamp overwrites the other body
  completely. This is a real data-loss window, documented rather than hidden.
- Correctness depends on device clocks being roughly right. A device with a badly
  wrong clock can win or lose conflicts it should not. The sync *cursor* is immune
  — it tracks server time — but the merge rule is not.
- Tombstones make the store grow until purged, and a device offline longer than
  the tombstone lifetime can resurrect a deleted note.

## Revisit if

Notes become collaborative or shared between users. At that point concurrent edits
stop being rare and a CRDT becomes the right cost.
