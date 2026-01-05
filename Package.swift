// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GeoLogger",
    platforms: [.iOS(.v14)],
    products: [
        .library(
            name: "GeoLogger",
            targets: ["GeoLogger"]
        )
    ],
    targets: [
        .target(
            name: "GeoLogger",
            dependencies: []
        ),
        .testTarget(
            name: "GeoLoggerTests",
            dependencies: ["GeoLogger"]
        )
    ]
)
