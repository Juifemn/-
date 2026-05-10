// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "PointerPilot",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "PointerPilot",
            targets: ["PointerPilot"]
        )
    ],
    targets: [
        .executableTarget(
            name: "PointerPilot",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("Carbon"),
                .linkedFramework("IOKit"),
                .linkedFramework("QuartzCore")
            ]
        )
    ]
)
