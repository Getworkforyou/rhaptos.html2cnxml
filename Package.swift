// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "RhaptosHTML2CNXML",
    platforms: [
        .macOS(.v13),
        .linux
    ],
    products: [
        .library(
            name: "RhaptosHTML2CNXML",
            targets: ["RhaptosHTML2CNXML"]),
        .executable(
            name: "testbed",
            targets: ["TestbedHTML"])
    ],
    dependencies: [
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.6.0"),
        .package(url: "https://github.com/tid-kijyun/Kanna.git", from: "5.2.0")
    ],
    targets: [
        .target(
            name: "RhaptosHTML2CNXML",
            dependencies: [
                "SwiftSoup",
                "Kanna"
            ],
            linkerSettings: [
                .linkedLibrary("xml2"),
                .linkedLibrary("xslt")
            ]),
        .executableTarget(
            name: "TestbedHTML",
            dependencies: ["RhaptosHTML2CNXML"]),
        .testTarget(
            name: "RhaptosHTML2CNXMLTests",
            dependencies: ["RhaptosHTML2CNXML"])
    ]
)
