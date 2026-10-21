// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Rota",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .target(
            name: "RotaKit",
            path: "Sources/RotaKit"
        ),
        .executableTarget(
            name: "Rota",
            dependencies: ["RotaKit"],
            path: "Sources/Rota"
        ),
        .executableTarget(
            name: "RotaWidgetExtension",
            dependencies: ["RotaKit"],
            path: "Sources/RotaWidgetExtension",
            linkerSettings: [
                // Le app extension devono avere NSExtensionMain come entry point
                // (Xcode lo passa automaticamente; con SwiftPM va dichiarato qui).
                .unsafeFlags(["-Xlinker", "-e", "-Xlinker", "_NSExtensionMain"])
            ]
        )
    ]
)
