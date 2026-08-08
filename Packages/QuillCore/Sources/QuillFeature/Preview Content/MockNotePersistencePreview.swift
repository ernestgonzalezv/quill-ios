//
//  MockNotePersistencePreview.swift
//  Quill
//
//  Created by Ernesto on 8/8/26.
//

#if DEBUG
internal import QuillDomain
import Foundation

/// Store en memoria para los Previews.
///
/// Es la prueba de que los puertos sirven para algo: `QuillFeature` no puede
/// importar `QuillData`, así que no tiene forma de tocar SwiftData ni
/// `URLSession` — y aun así puede montar una pantalla completa, con su view
/// model real y sus casos de uso reales, solo implementando el protocolo que
/// declara el dominio.
actor MockNotePersistencePreview: ProtoNoteRepository, ProtoNoteRepositoryObserving {
    private var notes: [UUID: Note]
    private let broadcaster = PreviewChangeBroadcaster()

    init(notes: [Note] = Note.previewSamples) {
        self.notes = Dictionary(uniqueKeysWithValues: notes.map { ($0.id, $0) })
    }

    nonisolated var changes: AsyncStream<Void> { broadcaster.stream() }

    func all(includingDeleted: Bool) async throws -> [Note] {
        let values = Array(notes.values)
        return includingDeleted ? values : values.filter { !$0.isDeleted }
    }

    func note(id: UUID) async throws -> Note? {
        notes[id]
    }

    func upsert(_ incoming: [Note]) async throws {
        for note in incoming {
            notes[note.id] = note
        }
        broadcaster.send()
    }

    func purgeTombstones(deletedBefore date: Date) async throws {
        notes = notes.filter { _, note in
            guard let deletedAt = note.deletedAt else { return true }
            return deletedAt >= date
        }
    }
}

/// Reparte el aviso de "algo cambió" a quien esté escuchando.
///
/// Versión mínima de lo que hace `InteractorChangeBroadcaster` en `QuillData`,
/// reimplementada aquí porque este módulo no puede importar aquel.
private final class PreviewChangeBroadcaster: @unchecked Sendable {
    private let lock = NSLock()
    private var continuations: [UUID: AsyncStream<Void>.Continuation] = [:]

    func stream() -> AsyncStream<Void> {
        AsyncStream { continuation in
            let id = UUID()
            lock.withLock { continuations[id] = continuation }
            continuation.onTermination = { [weak self] _ in
                self?.lock.withLock { _ = self?.continuations.removeValue(forKey: id) }
            }
        }
    }

    func send() {
        let current = lock.withLock { Array(continuations.values) }
        for continuation in current {
            continuation.yield()
        }
    }
}
#endif
