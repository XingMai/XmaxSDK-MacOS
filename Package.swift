// swift-tools-version: 6.2
//
//  Package.swift
//  XmaxSDK
//  Copyright (c) 2026 XMAX.AI PTE. LTD.
//

import PackageDescription

let package = Package(
    name: "XmaxSDK",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "XmaxSDK", targets: ["XmaxSDK"])
    ],
    dependencies: [
        .package(url: "https://github.com/AgoraIO/AgoraRtcEngine_macOS.git", exact: "4.6.2")
    ],
    targets: [
        .target(
            name: "XmaxSDK",
            dependencies: [
                .product(name: "RtcBasic", package: "AgoraRtcEngine_macOS"),
                "QCloudCore",
                "QCloudCOSXML"
            ],
            path: "Sources/XmaxSDK"
        ),
        .binaryTarget(name: "QCloudCore", path: "Vendor/QCloudCore.xcframework"),
        .binaryTarget(name: "QCloudCOSXML", path: "Vendor/QCloudCOSXML.xcframework"),
        .testTarget(
            name: "XmaxSDKTests",
            dependencies: ["XmaxSDK"],
            path: "Tests/XmaxSDKTests",
            // Command-line XCTest bundles load third-party dynamic frameworks from the build products directory.
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@loader_path/../../.."])
            ]
        )
    ]
)
