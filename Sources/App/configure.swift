import NIOSSL
import Fluent
import FluentPostgresDriver
import JWT
import Vapor

// configures your application
public func configure(_ app: Application) async throws {
    // uncomment to serve files from /Public folder
    // app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

    await app.jwt.keys.add(hmac: HMACKey(from: Environment.get("JWT_SECRET") ?? "jwt"), digestAlgorithm: .sha256)

    app.databases.use(DatabaseConfigurationFactory.postgres(configuration: .init(
        hostname: Environment.get("DATABASE_HOST") ?? "localhost",
        port: Environment.get("DATABASE_PORT").flatMap(Int.init(_:)) ?? SQLPostgresConfiguration.ianaPortNumber,
        username: Environment.get("DATABASE_USERNAME") ?? "vapor_username",
        password: Environment.get("DATABASE_PASSWORD") ?? "vapor_password",
        database: Environment.get("DATABASE_NAME") ?? "vapor_database",
        tls: .prefer(try .init(configuration: .clientDefault)))
    ), as: .psql)

    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .millisecondsSince1970
    ContentConfiguration.global.use(encoder: encoder, for: .json)

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .millisecondsSince1970
    ContentConfiguration.global.use(decoder: decoder, for: .json)

    try await migrations(app)
    // register routes
    try routes(app)
}

public func migrations(_ app: Application) async throws {
    app.migrations.add(CreateExtension())
    app.migrations.add(CreateDesigner())
    app.migrations.add(CreateAppInfo())
    app.migrations.add(CreateAppLocalizedName())
    app.migrations.add(CreateAppVersion())
    app.migrations.add(CreateRequestRecord())
    app.migrations.add(CreateTrigger())
}
