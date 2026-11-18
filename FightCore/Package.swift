// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FightCore",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(name: "FightCore", targets: ["FightCore"]),
        .library(name: "AppLogic", targets: ["AppLogic"]),
        .executable(name: "FightSim", targets: ["FightSim"]),
    ],
    targets: [
        .target(
            name: "FightCore",
            path: "Sources/FightCore",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "AppLogic",
            dependencies: ["FightCore"],
            path: "Sources/AppLogic"
        ),
        .executableTarget(
            name: "FightSim",
            dependencies: ["FightCore"],
            path: "Sources/FightSim"
        ),
        .testTarget(
            name: "FightCoreTests",
            dependencies: ["FightCore"],
            path: "Tests/FightCoreTests",
            resources: [
                .copy("Resources"),
            ]
        ),
        .testTarget(
            name: "AppLogicTests",
            dependencies: ["AppLogic", "FightCore"],
            path: "Tests/AppLogicTests",
            exclude: ["InputMap/T-ADAPT-SCRIPT.sh"]
        ),
        .testTarget(
            name: "ContentTests",
            dependencies: ["FightCore"],
            path: "Tests/ContentTests"
        ),
        .testTarget(
            name: "IntegrationTests",
            dependencies: ["FightCore"],
            path: "Tests/IntegrationTests"
        ),
    ]
)