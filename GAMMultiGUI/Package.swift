// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "GAMMultiGUI",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "GAMMultiGUI", targets: ["GAMMultiGUI"]),
        .executable(name: "GAMMultiGUIApp", targets: ["GAMMultiGUIApp"]),
        .library(name: "GAMMultiCore", targets: ["GAMMultiCore"]) 
    ],
    targets: [
        .executableTarget(
            name: "GAMMultiGUI",
            dependencies: ["GAMMultiCore"]
        ),
        .executableTarget(
            name: "GAMMultiGUIApp",
            dependencies: ["GAMMultiCore"],
            path: "Sources/GAMMultiGUIApp"
        ),
        .target(
            name: "GAMMultiCore",
            path: "Sources/GAMMultiCore"
        )
    ]
)
