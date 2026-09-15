// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "HSRDamageMeterProtocol",
  platforms: [.macOS(.v14)],
  products: [
    .library(name: "HSRProtocol", targets: ["HSRProtocol"]),
    .executable(name: "fixture-roundtrip", targets: ["FixtureRoundtrip"]),
    .executable(name: "HSRDamageMeter", targets: ["NativeApp"]),
  ],
  targets: [
    .target(name: "HSRProtocol", path: "Networking"),
    .target(name: "VeritasNetworking", path: "VeritasNetworking"),
    .target(
      name: "LiveDomain", dependencies: ["VeritasNetworking"], path: "LiveDomain",
      resources: [.process("Resources")]),
    .executableTarget(
      name: "NativeApp", dependencies: ["LiveDomain", "VeritasNetworking"], path: "NativeApp"),
    .testTarget(
      name: "NativeUITests", dependencies: ["NativeApp", "LiveDomain"], path: "NativeUITests"),
    .testTarget(
      name: "LiveTests", dependencies: ["LiveDomain", "VeritasNetworking"], path: "LiveTests"),
    .executableTarget(
      name: "FixtureRoundtrip", dependencies: ["HSRProtocol"], path: "Tools/FixtureRoundtrip"),
    .testTarget(name: "HSRProtocolTests", dependencies: ["HSRProtocol"], path: "Tests"),
  ]
)
