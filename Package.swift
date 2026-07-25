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
            path: "Sources/RotaWidgetExtension"
        )
    ]
)
