// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "MiddleFlow",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "MiddleFlow", targets: ["MiddleFlow"])
    ],
    targets: [
        .executableTarget(
            name: "MiddleFlow",
            path: "Sources/MiddleFlow",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("Carbon"),
                .linkedFramework("CoreAudio"),
                .linkedFramework("ServiceManagement")
            ]
        ),
        .testTarget(
            name: "MiddleFlowTests",
            dependencies: ["MiddleFlow"],
            path: "Tests/MiddleFlowTests"
        )
    ]
)
