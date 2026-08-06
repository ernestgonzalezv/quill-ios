// swift-tools-version: 6.0
import PackageDescription

/// Strict settings applied to every target: Swift 6 language mode (full data-race
/// checking) plus upcoming features we want to adopt ahead of Swift 7.
let strict: [SwiftSetting] = [
    .swiftLanguageMode(.v6),
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("InternalImportsByDefault"),
]

let package = Package(
    name: "QuillCore",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "QuillDomain", targets: ["QuillDomain"]),
    ],
    targets: [
        // Pure Swift. No Foundation-adjacent frameworks, no I/O, no UI.
        .target(name: "QuillDomain", swiftSettings: strict),

        // SwiftUI + view models. Depends on the domain only — never on QuillData.
        .target(
            name: "QuillFeature",
            dependencies: ["QuillDomain"],
            resources: [.process("Resources")],
            swiftSettings: strict
        ),
    ]
)
