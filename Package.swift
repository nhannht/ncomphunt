// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CompHuntKit",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "CompHuntKit", targets: ["CompHuntKit"])
    ],
    dependencies: [
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.7.0"),
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.1.0"),
    ],
    targets: [
        .target(
            name: "CompHuntKit",
            dependencies: ["SwiftSoup", "Yams"]
        ),
        .testTarget(
            name: "CompHuntKitTests",
            dependencies: ["CompHuntKit"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
