// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "KeyPathRecording",
    products: [
        .library(
            name: "KeyPathRecording",
            targets: ["KeyPathRecording"]),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "KeyPathRecording",
            dependencies: [
                
            ]),
        .testTarget(
            name: "KeyPathRecordingTests",
            dependencies: ["KeyPathRecording"]),
    ]
)
