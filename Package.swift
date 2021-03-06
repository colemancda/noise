// swift-tools-version:4.0

import PackageDescription

let package = Package(
    name: "Noise",
    products: [
        .library(name: "Noise", targets: ["Noise"])
    ],
    dependencies: [
        .package(url: "https://github.com/kelvin13/maxpng", from: "2.0.0")
    ],
    targets: [
        .target(
            name: "Noise",
            path: "sources/noise"),
        .testTarget(
            name: "Tests",
            dependencies: ["Noise", "MaxPNG"],
            path: "tests/noise"),
    ]
)
