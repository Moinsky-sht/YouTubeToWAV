// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "YouTubeToWAV",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "YouTubeToWAV",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
