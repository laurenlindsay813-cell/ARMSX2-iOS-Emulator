// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ARMSX2iOS",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "ARMSX2iOS",
            targets: ["ARMSX2iOS"]
        )
    ],
    targets: [
        .target(
            name: "ARMSX2iOS",
            path: "Sources/ARMSX2iOS"
        )
    ]
)
