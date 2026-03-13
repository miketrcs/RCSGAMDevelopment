// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "GAMMultiGUI",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "GAMMultiGUI", targets: ["GAMMultiGUI"])
    ],
    targets: [
        .executableTarget(
            name: "GAMMultiGUI",
            path: "Sources"
        )
    ]
)
