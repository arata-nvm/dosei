// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "DoseiCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "DoseiCore", targets: ["DoseiCore"]),
    ],
    targets: [
        .target(name: "DoseiCore"),
        .testTarget(name: "DoseiCoreTests", dependencies: ["DoseiCore"]),
    ]
)
