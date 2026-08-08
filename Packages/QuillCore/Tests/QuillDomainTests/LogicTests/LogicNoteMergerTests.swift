//
//  LogicNoteMergerTests.swift
//  Quill
//
//  Created by Ernesto on 8/6/26.
//

import Foundation
import Testing
@testable import QuillDomain

/// Conflict resolution is the highest-risk logic in the app and a pure function,
/// so it gets exhaustive case coverage rather than a happy-path test.
@Suite("LogicNoteMerger")
struct NoteMergerTests {
    private let merger = LogicNoteMerger()
    private let id = UUID()

    // MARK: - Pairwise resolution

    @Test("Later timestamp wins")
    func laterTimestampWins() {
        let local = Note.stub(id: id, title: "Local", updatedAt: 200)
        let remote = Note.stub(id: id, title: "Remote", updatedAt: 100)

        #expect(merger.resolve(local: local, remote: remote) == .local)
        #expect(merger.resolve(local: remote, remote: local) == .remote)
    }

    @Test("Identical notes need no work")
    func identicalNotesAreUnchanged() {
        let note = Note.stub(id: id)
        #expect(merger.resolve(local: note, remote: note) == .unchanged)
    }

    @Test("On a timestamp tie, the tombstone wins")
    func tombstoneWinsTies() {
        let live = Note.stub(id: id, title: "Live", updatedAt: 100)
        let deleted = Note.stub(id: id, title: "", body: "", updatedAt: 100, deletedAt: 100)

        // A delete is unrecoverable for the user; a lost edit is retypable.
        #expect(merger.resolve(local: deleted, remote: live) == .local)
        #expect(merger.resolve(local: live, remote: deleted) == .remote)
    }

    @Test("Fully concurrent live edits resolve to remote, deterministically")
    func concurrentLiveEditsPreferRemote() {
        let local = Note.stub(id: id, title: "Local", updatedAt: 100)
        let remote = Note.stub(id: id, title: "Remote", updatedAt: 100)

        // Arbitrary but stable: every device replaying this pair must agree, or the
        // two never converge.
        #expect(merger.resolve(local: local, remote: remote) == .remote)
    }

    // MARK: - Set reconciliation

    @Test("Notes the server has never seen are queued for push")
    func unknownLocalNotesArePushed() {
        let local = Note.stub(title: "Only local")
        let result = merger.merge(local: [local], remote: [])

        #expect(result.toPushRemotely == [local])
        #expect(result.toStoreLocally.isEmpty)
    }

    @Test("Notes unknown locally are stored")
    func unknownRemoteNotesAreStored() {
        let remote = Note.stub(title: "Only remote")
        let result = merger.merge(local: [], remote: [remote])

        #expect(result.toStoreLocally == [remote])
        #expect(result.toPushRemotely.isEmpty)
    }

    /// The single most common offline-sync bug: without tombstones in the local
    /// snapshot, a locally-deleted note looks absent, the remote copy is treated as
    /// new, and the delete resurrects.
    @Test("A local tombstone is pushed rather than overwritten by the live remote copy")
    func localDeleteDoesNotResurrect() {
        let tombstone = Note.stub(id: id, title: "", body: "", updatedAt: 200, deletedAt: 200)
        let liveRemote = Note.stub(id: id, title: "Still here", updatedAt: 100)

        let result = merger.merge(local: [tombstone], remote: [liveRemote])

        #expect(result.toPushRemotely == [tombstone])
        #expect(result.toStoreLocally.isEmpty)
    }

    @Test("A remote tombstone is accepted locally")
    func remoteDeletePropagates() {
        let live = Note.stub(id: id, title: "Local copy", updatedAt: 100)
        let tombstone = Note.stub(id: id, title: "", body: "", updatedAt: 200, deletedAt: 200)

        let result = merger.merge(local: [live], remote: [tombstone])

        #expect(result.toStoreLocally == [tombstone])
    }

    @Test("Unchanged notes produce no writes in either direction")
    func unchangedNotesAreNoOps() {
        let note = Note.stub(id: id)
        #expect(merger.merge(local: [note], remote: [note]).isEmpty)
    }

    /// Applying the merge and re-running it must produce nothing new, otherwise a
    /// retried or replayed round would never settle.
    @Test("Merging is idempotent")
    func mergeConverges() {
        let local = [Note.stub(id: id, title: "Local", updatedAt: 100), Note.stub(title: "New local")]
        let remote = [Note.stub(id: id, title: "Remote", updatedAt: 300)]

        let first = merger.merge(local: local, remote: remote)
        let settledLocal = local.map { note in first.toStoreLocally.first { $0.id == note.id } ?? note }

        #expect(merger.merge(local: settledLocal, remote: remote).toStoreLocally.isEmpty)
    }
}
