// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FreeRadio",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "FreeRadio", targets: ["FreeRadio"])
    ],
    targets: [
        .executableTarget(
            name: "FreeRadio",
            path: "Sources/FreeRadio"
        )
    ]
)
