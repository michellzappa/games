// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GameShell",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "GameShell", targets: ["GameShell"])
    ],
    targets: [
        .target(name: "GameShell")
    ]
)
