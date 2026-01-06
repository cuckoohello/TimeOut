// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TimeOut",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "TimeOut", targets: ["TimeOut"])
    ],
    targets: [
        .executableTarget(
            name: "TimeOut",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
