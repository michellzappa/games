// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GridKit",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "GridKit", targets: ["GridKit"])
    ],
    targets: [
        .target(name: "GridKit")
    ]
)
