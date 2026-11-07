// swift-tools-version: 5.9
import PackageDescription
let package = Package(
 name: "Veilopoly",
 platforms: [.iOS(.v16), .macOS(.v13)],
 products: [
  .library(name: "VeilopolyEngine", targets: ["VeilopolyEngine"]),
  .library(name: "VeilopolyAI", targets: ["VeilopolyAI"]),
  .library(name: "VeilopolyNet", targets: ["VeilopolyNet"]),
  .library(name: "VeilopolyPersistence", targets: ["VeilopolyPersistence"]),
  .library(name: "VeilopolyUI", targets: ["VeilopolyUI"])
 ],
 targets: [
  .target(name: "VeilopolyEngine"),
  .target(name: "VeilopolyAI", dependencies: ["VeilopolyEngine"]),
  .target(name: "VeilopolyNet", dependencies: ["VeilopolyEngine"]),
  .target(name: "VeilopolyPersistence", dependencies: ["VeilopolyEngine"]),
  .target(name: "VeilopolyUI", dependencies: ["VeilopolyEngine", "VeilopolyAI", "VeilopolyNet", "VeilopolyPersistence"], resources: [.process("Resources")]),
  .testTarget(name: "VeilopolyEngineTests", dependencies: ["VeilopolyEngine"]),
  .testTarget(name: "VeilopolyAITests", dependencies: ["VeilopolyAI", "VeilopolyEngine"]),
  .testTarget(name: "VeilopolyNetTests", dependencies: ["VeilopolyNet", "VeilopolyEngine"]),
  .testTarget(name: "VeilopolyPersistenceTests", dependencies: ["VeilopolyPersistence", "VeilopolyEngine"]),
  .testTarget(name: "VeilopolyUITests", dependencies: ["VeilopolyUI"])
 ]
)
