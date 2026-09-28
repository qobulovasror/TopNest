// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TopNest",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "TopNest", targets: ["TopNest"]),
        // /usr/bin/perl ichiga yuklanadigan MediaRemote yordamchisi (ilovaga bog'lanmaydi).
        .library(name: "TopNestMediaBridge", type: .dynamic, targets: ["TopNestMediaBridge"])
    ],
    targets: [
        .executableTarget(name: "TopNest"),
        .target(
            name: "TopNestMediaBridge",
            linkerSettings: [.linkedFramework("AppKit"), .linkedFramework("Foundation")]
        )
    ],
    swiftLanguageModes: [.v5]
)
