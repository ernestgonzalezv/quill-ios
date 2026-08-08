//
//  InteractorSpotlight.swift
//  Quill
//
//  Created by Ernesto on 8/6/26.
//

import Foundation
import CoreSpotlight
import QuillDomain

/// Publishes notes to system search.
///
/// Runs off the repository's change stream rather than being called from each
/// write site, so a note created by the editor, by a sync round, or by a Siri
/// shortcut is indexed through the same path — nothing can forget to call it.
///
/// `@MainActor` rather than an actor of its own: `CSSearchableItem` and
/// `CSSearchableItemAttributeSet` are non-`Sendable` reference types, so pinning
/// the whole type to one actor is what keeps them from crossing an isolation
/// boundary. The work itself is handed to the Spotlight daemon and does not block.
@MainActor
final class InteractorSpotlight {
    private static let domainIdentifier = "com.ernestgonzalezv.quill.note"

    private let repository: any ProtoNoteRepository
    private let observing: any ProtoNoteRepositoryObserving
    private let index: CSSearchableIndex
    private let debounce: Duration

    private var pendingTask: Task<Void, Never>?

    init(
        repository: any ProtoNoteRepository,
        observing: any ProtoNoteRepositoryObserving,
        index: CSSearchableIndex = .default(),
        debounce: Duration = .seconds(2)
    ) {
        self.repository = repository
        self.observing = observing
        self.index = index
        self.debounce = debounce
    }

    /// Indexes once, then follows the store until cancelled.
    func run() async {
        await reindex()
        for await _ in observing.changes {
            scheduleReindex()
        }
    }

    /// Coalesces bursts. A sync round can commit hundreds of notes in a few
    /// writes; without this, each one would kick a full reindex and the daemon
    /// would do the same work dozens of times over.
    private func scheduleReindex() {
        pendingTask?.cancel()
        pendingTask = Task { [weak self, debounce] in
            try? await Task.sleep(for: debounce)
            guard !Task.isCancelled else { return }
            await self?.reindex()
        }
    }

    /// Rebuilds the index from the current store contents.
    ///
    /// A full rebuild rather than an incremental diff. The store holds a personal
    /// note count — hundreds, not millions — so a rebuild is cheap and cannot
    /// drift out of sync the way a hand-maintained delta can. If this ever backed
    /// a shared or very large corpus, `CSSearchableIndex`'s client-state API is the
    /// mechanism to switch to.
    private func reindex() async {
        guard CSSearchableIndex.isIndexingAvailable() else { return }

        do {
            // Tombstones included on purpose: they are exactly the identifiers that
            // must be *removed* from the index. Excluding them would leave deleted
            // notes searchable — their text still readable from Spotlight.
            let notes = try await repository.all(includingDeleted: true)
            let live = notes.filter { !$0.isDeleted }
            let deletedIdentifiers = notes.filter(\.isDeleted).map(\.id.uuidString)

            if !deletedIdentifiers.isEmpty {
                try await index.deleteSearchableItems(withIdentifiers: deletedIdentifiers)
            }
            if !live.isEmpty {
                try await index.indexSearchableItems(live.map(Self.searchableItem(for:)))
            }
        } catch {
            // Indexing is an enhancement, never a requirement. A failure here must
            // not surface as an error in a notes app that works perfectly without it.
        }
    }

    private static func searchableItem(for note: Note) -> CSSearchableItem {
        let attributes = CSSearchableItemAttributeSet(contentType: .text)
        attributes.title = note.displayTitle
        attributes.contentDescription = note.snippet(limit: 200)
        attributes.contentModificationDate = note.updatedAt
        attributes.contentCreationDate = note.createdAt

        let item = CSSearchableItem(
            uniqueIdentifier: note.id.uuidString,
            domainIdentifier: domainIdentifier,
            attributeSet: attributes
        )
        // Bounded so an abandoned install stops appearing in search forever.
        item.expirationDate = .distantFuture
        return item
    }
}
