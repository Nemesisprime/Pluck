// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Pluck",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "Pluck",
            targets: ["Pluck"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/Nemesisprime/NiftyTemplate.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/lake-of-fire/swift-readability.git",
            revision: "d4f0824f5f4496791d01a83493ffccf3dd89c4cf"
        ),
        .package(
            url: "https://github.com/scinfu/SwiftSoup.git",
            from: "2.7.0"
        ),
    ],
    targets: [
        .target(
            name: "Pluck",
            dependencies: [
                .product(name: "NiftyTemplate", package: "NiftyTemplate"),
                .product(name: "SwiftReadability", package: "swift-readability"),
                "SwiftSoup",
            ],
            resources: [
                .process("Resources/Templates"),
            ]
        ),
        .testTarget(
            name: "PluckTests",
            dependencies: ["Pluck"],
            resources: [
                .copy("Resources/Fixtures"),
            ]
        ),
    ]
)
