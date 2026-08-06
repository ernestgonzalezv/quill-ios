import SwiftUI
import CoreSpotlight
import QuillFeature

@main
struct QuillApp: App {
    // The graph is built once, for the process lifetime. `@State` rather than a
    // global so it is torn down with the scene in previews and tests.
    @State private var dependencies = AppDependencies.live()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            NoteListView(
                factory: dependencies.featureFactory,
                router: dependencies.router
            )
            .overlay(alignment: .top) { storeFailureBanner }
            // Spotlight hands back the note's id; the router turns that into a
            // push without the app layer touching the navigation stack.
            .onContinueUserActivity(CSSearchableItemActionType) { activity in
                guard
                    let raw = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String,
                    let id = UUID(uuidString: raw)
                else { return }
                dependencies.router.requestOpen(noteID: id)
            }
            .task {
                // Long-lived: keeps the Spotlight index in step with the store for
                // as long as the scene exists.
                await dependencies.spotlightIndexer.run()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            // Foregrounding is the highest-value sync trigger: it is when the local
            // copy is most likely to be stale and when the user is about to look.
            guard phase == .active else { return }
            Task { await dependencies.syncCoordinator.syncInBackground() }
        }
    }

    @ViewBuilder
    private var storeFailureBanner: some View {
        if let message = dependencies.storeFailureMessage {
            Text(message)
                .font(.footnote.weight(.medium))
                .padding()
                .frame(maxWidth: .infinity)
                .background(.yellow.opacity(0.9), in: .rect(cornerRadius: 12))
                .padding()
        }
    }
}
