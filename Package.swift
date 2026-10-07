// swift-tools-version: 6.0
import PackageDescription

// GrowthCore is platform-independent (Foundation + Observation only) so its logic
// can be built and tested on any Swift toolchain, including Linux CI.
// DesignSystem and AppFeatures depend on SwiftUI and are only declared on Apple platforms.

var products: [Product] = [
    .library(name: "GrowthCore", targets: ["GrowthCore"])
]

var targets: [Target] = [
    .target(name: "GrowthCore"),
    .testTarget(name: "GrowthCoreTests", dependencies: ["GrowthCore"])
]

#if canImport(Darwin)
products += [
    .library(name: "DesignSystem", targets: ["DesignSystem"]),
    .library(name: "AppFeatures", targets: ["AppFeatures"])
]
targets += [
    // UI targets use Swift 5 language mode to avoid strict-concurrency friction with SwiftUI/UIKit APIs;
    // GrowthCore (all logic and state) is compiled in Swift 6 mode.
    .target(name: "DesignSystem", dependencies: ["GrowthCore"], swiftSettings: [.swiftLanguageMode(.v5)]),
    .target(name: "AppFeatures", dependencies: ["GrowthCore", "DesignSystem"], swiftSettings: [.swiftLanguageMode(.v5)])
]
#endif

let package = Package(
    name: "GrowthApp",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: products,
    targets: targets
)
