// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "VelloKit",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "VelloCore", targets: ["VelloCore"]),
        .library(name: "VelloCapture", targets: ["VelloCapture"]),
        .library(name: "VelloExport", targets: ["VelloExport"]),
        .library(name: "VelloUI", targets: ["VelloUI"])
    ],
    targets: [
        .target(name: "VelloCore"),
        .target(name: "VelloCapture", dependencies: ["VelloCore"]),
        .target(name: "VelloExport", dependencies: ["VelloCore"]),
        .target(name: "VelloUI", dependencies: ["VelloCore", "VelloCapture", "VelloExport"]),
        .testTarget(name: "VelloCoreTests", dependencies: ["VelloCore"]),
        .testTarget(name: "VelloCaptureTests", dependencies: ["VelloCapture"]),
        .testTarget(name: "VelloExportTests", dependencies: ["VelloExport"]),
        .testTarget(name: "VelloUITests", dependencies: ["VelloUI"])
    ]
)
