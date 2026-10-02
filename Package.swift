// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SanctuaryCore",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(name: "SanctuaryCore", targets: ["SanctuaryCore"]),
        .library(name: "SanctuaryUI", targets: ["SanctuaryUI"]),
    ],
    targets: [
        .target(
            name: "SanctuaryCore",
            resources: [
                // Drop audio files (m4a/wav/mp3) into Sources/SanctuaryCore/Media/
                // and reference them by fileName in AudioTrack seed data.
                .process("Media")
            ]
        ),
        .target(
            name: "SanctuaryUI",
            dependencies: ["SanctuaryCore"]
        ),
        .testTarget(
            name: "SanctuaryCoreTests",
            dependencies: ["SanctuaryCore"]
        ),
    ]
)
