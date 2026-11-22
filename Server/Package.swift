// swift-tools-version: 6.0
import PackageDescription

let package = Package(name: "RealPacmanServer", platforms: [.macOS(.v14)], products: [
    .executable(name: "RealPacmanServer", targets: ["Run"])
], dependencies: [
    .package(url: "https://github.com/vapor/vapor.git", from: "4.115.0"),
    .package(url: "https://github.com/vapor/fluent.git", from: "4.12.0"),
    .package(url: "https://github.com/vapor/fluent-postgres-driver.git", from: "2.10.0"),
    .package(url: "https://github.com/vapor/fluent-sqlite-driver.git", from: "4.8.0")
], targets: [
    .target(name: "App", dependencies: [
        .product(name: "Vapor", package: "vapor"),
        .product(name: "Fluent", package: "fluent"),
        .product(name: "FluentPostgresDriver", package: "fluent-postgres-driver")
    ], resources: [.copy("Resources/verney-draft.json")]),
    .executableTarget(name: "Run", dependencies: ["App"]),
    .executableTarget(name: "IntegrationServer", dependencies: ["App",
        .product(name: "FluentSQLiteDriver", package: "fluent-sqlite-driver")], path: "Tests/IntegrationServer"),
    .testTarget(name: "AppTests", dependencies: ["App",
        .product(name: "VaporTesting", package: "vapor"),
        .product(name: "FluentSQLiteDriver", package: "fluent-sqlite-driver")])
])
