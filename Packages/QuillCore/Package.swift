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
        .library(name: "QuillData", targets: ["QuillData"]),
        .library(name: "QuillFeature", targets: ["QuillFeature"]),
    ],
    targets: [
        // Pure Swift. No Foundation-adjacent frameworks, no I/O, no UI.
        .target(name: "QuillDomain", swiftSettings: strict),

        // Adapters: SwiftData persistence, URLSession networking, sync engine.
        .target(name: "QuillData", dependencies: ["QuillDomain"], swiftSettings: strict),

        // SwiftUI + view models. Depends on the domain only — never on QuillData.
        .target(
            name: "QuillFeature",
            dependencies: ["QuillDomain"],
            resources: [.process("Resources")],
            swiftSettings: strict
        ),

        .testTarget(name: "QuillDomainTests", dependencies: ["QuillDomain"], swiftSettings: strict),
        .testTarget(name: "QuillDataTests", dependencies: ["QuillData"], swiftSettings: strict),
        .testTarget(name: "QuillFeatureTests", dependencies: ["QuillFeature"], swiftSettings: strict),
    ]
)
