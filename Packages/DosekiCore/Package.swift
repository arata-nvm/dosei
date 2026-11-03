// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "DosekiCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "DosekiCore", targets: ["DosekiCore"]),
    ],
    targets: [
        .target(name: "DosekiCore"),
        .testTarget(name: "DosekiCoreTests", dependencies: ["DosekiCore"]),
    ]
)
