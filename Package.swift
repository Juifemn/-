// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "旋转跳跃我闭着眼",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "CursorScreenSwitcher",
            targets: ["CursorScreenSwitcher"]
        )
    ],
    targets: [
        .executableTarget(
            name: "CursorScreenSwitcher",
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
