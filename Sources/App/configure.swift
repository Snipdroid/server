import Fluent
import FluentPostgresDriver
import JWT
import Leaf
import LeafKit
import NIOSSL
import QueuesRedisDriver
import SotoS3
import Vapor

// configures your application
public func configure(_ app: Application) async throws {
    // uncomment to serve files from /Public folder
    // app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

    // Configure OIDC authentication (uses auto-discovery)
    guard let oidcIssuer = Environment.get("OIDC_ISSUER") else {
        fatalError("OIDC_ISSUER environment variable is required")
    }
    guard let oidcAudience = Environment.get("OIDC_AUDIENCE") else {
        fatalError("OIDC_AUDIENCE environment variable is required")
    }
    try await app.configureOIDC(issuer: oidcIssuer, audience: oidcAudience)

    // try app.queues.use(.redis(url: Environment.get("REDIS_URL") ?? "redis://localhost:6379"))
    // app.queues.add(DailySummaryJob())
    // app.queues.schedule(DailySummaryJob()).daily()
    // try app.queues.startInProcessJobs(on: .default)

    if let awsPrivateEndpoint = Environment.get("AWS_PRIVATE_ENDPOINT") {
        app.aws.client = AWSClient(
            httpClient: app.http.client.shared
        )
        app.aws.s3 = S3(client: app.aws.client, endpoint: awsPrivateEndpoint)
    }

    app.aws.s3PublicEndpoint = Environment.get("AWS_PUBLIC_ENDPOINT")

    guard let jwtSecret = Environment.get("JWT_SECRET") else {
        fatalError("JWT_SECRET environment variable is required")
    }
    await app.jwt.keys.add(hmac: HMACKey(from: jwtSecret), digestAlgorithm: .sha256)

    app.databases.use(
        DatabaseConfigurationFactory.postgres(
            configuration: .init(
                hostname: Environment.get("DATABASE_HOST") ?? "localhost",
                port: Environment.get("DATABASE_PORT").flatMap(Int.init(_:))
                    ?? SQLPostgresConfiguration.ianaPortNumber,
                username: Environment.get("DATABASE_USERNAME") ?? "vapor_username",
                password: Environment.get("DATABASE_PASSWORD") ?? "vapor_password",
                database: Environment.get("DATABASE_NAME") ?? "vapor_database",
                tls: .prefer(try .init(configuration: .clientDefault)))
        ), as: .psql)

    app.views.use(.leaf)
    app.leaf.sources = LeafSources.singleSource(DynamicLeafSource.global)

    try await migrations(app)
    // register routes
    try routes(app)
}

public func migrations(_ app: Application) async throws {
    app.migrations.add(CreateExtension())
    app.migrations.add(CreateDesigner())
    app.migrations.add(CreateAppInfo())
    app.migrations.add(CreateAppLocalizedName())
    app.migrations.add(CreateIconPack())
    app.migrations.add(CreateIconPackVersion())
    app.migrations.add(CreateRequestRecord())
    app.migrations.add(CreateTrigger())
    app.migrations.add(CreateDailySummary())
    app.migrations.add(CreateIconPackApp())
    app.migrations.add(CreateTag())
    app.migrations.add(CreateAppInfoTag())
    app.migrations.add(AddPerformanceIndexes())
    app.migrations.add(CreateIconPackCollaborator())
}
