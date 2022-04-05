import Fluent
import FluentSQLiteDriver
import Vapor

// configures your application
public func configure(_ app: Application) throws {
    // uncomment to serve files from /Public folder
    // app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))
    app.logger.logLevel = .info

    configureHttp(app)
    configureMiddleware(app)

    app.databases.use(.sqlite(.file("data/db.sqlite")), as: .sqlite)
    app.migrations.add(CreateAppInfo())

    // register routes
    try routes(app)
}

fileprivate func configureHttp(_ app: Application) {
    app.http.server.configuration.port = 2080
}

fileprivate func configureMiddleware(_ app: Application) {
    let corsConfiguration = CORSMiddleware.Configuration(
        allowedOrigin: .all,
        allowedMethods: [.GET, .POST, .PUT, .OPTIONS, .DELETE, .PATCH],
        allowedHeaders: [.accept, .authorization, .contentType, .origin, .xRequestedWith, .userAgent, .accessControlAllowOrigin]
    )
    let cors = CORSMiddleware(configuration: corsConfiguration)
    app.middleware.use(cors, at: .beginning)
}
