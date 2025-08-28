// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "AppTracker",
    platforms: [
       .macOS(.v13)
    ],
    dependencies: [
        // 💧 A server-side Swift web framework.
        .package(url: "https://github.com/vapor/vapor.git", from: "4.110.1"),
        // 🗄 An ORM for SQL and NoSQL databases.
        .package(url: "https://github.com/vapor/fluent.git", from: "4.9.0"),
        // 🐘 Fluent driver for Postgres.
        .package(url: "https://github.com/vapor/fluent-postgres-driver.git", from: "2.8.0"),
        // 🔵 Non-blocking, event-driven networking for Swift. Used for custom executors
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.65.0"),
        // 🍬 JSON Web Token signing and verification (JWT)
        .package(url: "https://github.com/vapor/jwt.git", from: "5.0.0"),
        // 🚦 A queueing backend for Queues that uses Redis.
        .package(url: "https://github.com/vapor/queues-redis-driver.git", from: "1.0.0"),
        // 📄 OpenAPI doc generator
        .package(url: "https://github.com/dankinsoid/VaporToOpenAPI", from: "4.0.0"),
        // 🚀 AWS SDK for Swift
        .package(url: "https://github.com/soto-project/soto.git", from: "7.0.0"),
        // 🚀 S3 file transfer for Soto
        // .package(url: "https://github.com/soto-project/soto-s3-file-transfer.git", from: "2.0.0")
    ],
    targets: [
        .executableTarget(
            name: "App",
            dependencies: [
                .product(name: "Fluent", package: "fluent"),
                .product(name: "FluentPostgresDriver", package: "fluent-postgres-driver"),
                .product(name: "Vapor", package: "vapor"),
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
                .product(name: "JWT", package: "jwt"),
                .product(name: "QueuesRedisDriver", package: "queues-redis-driver"),
                .product(name: "SotoS3", package: "soto"),
                .product(name: "VaporToOpenAPI", package: "VaporToOpenAPI"),
            ],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "AppTests",
            dependencies: [
                .target(name: "App"),
                .product(name: "VaporTesting", package: "vapor"),
            ],
            swiftSettings: swiftSettings
        )
    ],
    swiftLanguageModes: [.v5]
)

var swiftSettings: [SwiftSetting] { [
    .enableUpcomingFeature("DisableOutwardActorInference"),
    .enableExperimentalFeature("StrictConcurrency"),
] }
