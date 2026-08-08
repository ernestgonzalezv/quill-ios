//
//  LogicNoteMerger.swift
//  Quill
//
//  Created by Ernesto on 8/6/26.
//

import Foundation

/// Conflict resolution for offline-first sync.
///
/// The strategy is **last-write-wins on `updatedAt`, with deletes winning ties**.
/// It is a pure function of its inputs — no I/O, no clock, no store — which is
/// why it can be exhaustively unit-tested, and why it is the first thing to read
/// when a sync bug shows up.
///
/// LWW is chosen knowingly. It is the cheapest strategy that converges, and for
/// single-user notes the losing side of a conflict is almost always a stale
/// device. It *can* lose a concurrent edit: two devices editing the same note
/// while both offline means the later timestamp overwrites the earlier body
/// wholesale. A CRDT (per-character or per-field) would preserve both, at the
/// cost of a much larger payload and a real merge implementation. See
/// `Docs/ADR-002-conflict-resolution.md`.
public struct LogicNoteMerger: Sendable {
    public init() {}

    /// Which side of a conflict survives.
    public enum Resolution: Hashable, Sendable {
        case local
        case remote
        /// Identical timestamps *and* identical content — nothing to do.
        case unchanged
    }

    /// Decides a single pair. Split out from ``merge(local:remote:)`` so the rule
    /// can be tested in isolation from the set arithmetic around it.
    public func resolve(local: Note, remote: Note) -> Resolution {
        if local == remote { return .unchanged }

        if local.updatedAt > remote.updatedAt { return .local }
        if remote.updatedAt > local.updatedAt { return .remote }

        // Same timestamp, different content. A delete is not recoverable by the
        // user, whereas a lost edit is retypable — so the tombstone wins.
        if local.isDeleted != remote.isDeleted {
            return local.isDeleted ? .local : .remote
        }

        // Fully concurrent and both live: prefer remote so every device that
        // replays this pair reaches the same answer. Preferring local would let
        // two devices each keep their own version and never converge.
        return .remote
    }

    /// Reconciles a full local snapshot against a remote change set.
    ///
    /// `local` must include tombstones, otherwise a locally-deleted note looks
    /// absent, the remote copy is treated as new, and the delete resurrects.
    public func merge(local: [Note], remote: [Note]) -> MergeResult {
        let localByID = Dictionary(local.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let remoteByID = Dictionary(remote.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        var toStoreLocally: [Note] = []
        var toPushRemotely: [Note] = []

        for note in remote {
            guard let mine = localByID[note.id] else {
                // Unknown here: accept it, including tombstones — that is how a
                // delete made on another device propagates.
                toStoreLocally.append(note)
                continue
            }
            switch resolve(local: mine, remote: note) {
            case .remote: toStoreLocally.append(note)
            case .local: toPushRemotely.append(mine)
            case .unchanged: break
            }
        }

        // Local notes the server has never seen.
        for note in local where remoteByID[note.id] == nil {
            toPushRemotely.append(note)
        }

        return MergeResult(
            toStoreLocally: toStoreLocally.sorted(by: idOrder),
            toPushRemotely: toPushRemotely.sorted(by: idOrder)
        )
    }

    /// Stable ordering so results are comparable in tests and diffs.
    private func idOrder(_ lhs: Note, _ rhs: Note) -> Bool {
        lhs.id.uuidString < rhs.id.uuidString
    }
}

public struct MergeResult: Hashable, Sendable {
    /// Remote wins — write these into the local store.
    public var toStoreLocally: [Note]
    /// Local wins, or the server has never seen them — upload these.
    public var toPushRemotely: [Note]

    public init(toStoreLocally: [Note] = [], toPushRemotely: [Note] = []) {
        self.toStoreLocally = toStoreLocally
        self.toPushRemotely = toPushRemotely
    }

    public var isEmpty: Bool { toStoreLocally.isEmpty && toPushRemotely.isEmpty }
}
