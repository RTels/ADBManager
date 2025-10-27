// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "XPCLibrary",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "XPCLibrary",
            targets: ["XPCLibrary"]
        ),
    ],
    targets: [
        .target(
            name: "XPCLibrary",
            resources: [
                .copy("Resources/adb")  
            ]
        ),
    ]
)
