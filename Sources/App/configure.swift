import Fluent
import FluentPostgresDriver
import Vapor

// configures your application
public func configure(_ app: Application) async throws {
    configureHttp(app)
    configureMiddleware(app)

    // S3
    if let bucket = Environment.get("S3_BUCKET"),
       let accessKeyId = Environment.get("S3_ACCESS_KEY_ID"),
       let secretAccessKey = Environment.get("S3_SECRET_ACCESS_KEY")
    {
        app.iconProvider = S3IconProvider(
            bucket: bucket,
            accessKeyId: accessKeyId,
            secretAccessKey: secretAccessKey,
            s3Region: .init(rawValue: Environment.get("S3_REGION")),
            s3Endpoint: Environment.get("S3_ENDPOINT")
        )
        app.lifecycle.use(S3LifecycleHandler())
        app.logger.info("Using S3 storage.")
    } else {
        app.logger.info("Using local storage. Please make sure ./data/icons directory exists.")
    }

    // PostgreSQL Database
    guard let postgresUrl = Environment.get("POSTGRES_URL") else {
        app.logger.error("Environment variable POSTGRES_URL not found in .env file.")
        exit(1)
    }
    try app.databases.use(.postgres(url: postgresUrl), as: .psql)
    try await migrate(app)

    // Optional HTTP Proxy
    if let httpProxyAddr = Environment.get("HTTP_PROXY_ADDR"),
       let httpProxyPort = Environment.get("HTTP_PROXY_PORT"),
       let httpProxyPortNumber = Int(httpProxyPort)
    {
        app.logger.info("Using http proxy http://\(httpProxyAddr):\(httpProxyPortNumber)")
        app.http.client.configuration.proxy = .server(host: httpProxyAddr, port: httpProxyPortNumber)
    }
    
    // Session Driver
    app.sessions.use(.fluent)

    // register routes
    try routes(app)
}

private func migrate(_ app: Application) async throws {
    app.migrations.add(CreateAppInfo())
    app.migrations.add(RemoveSignature())
    app.migrations.add(CreateIconPack())
    app.migrations.add(CreateIconRequest())
    app.migrations.add(CreateTag())
    app.migrations.add(CreateAppInfoTagPivot())
    app.migrations.add(CreateUserAccount())
    app.migrations.add(CreateUserToken())
    app.migrations.add(AddDesignerToIconPack())
    app.migrations.add(AddSuggestedName())
    app.migrations.add(SessionRecord.migration)
    app.migrations.add(AddCreateTimeToAppInfo())
    try await app.autoMigrate()
}

private func configureHttp(_ app: Application) {
    app.http.server.configuration.port = 2080
}

private func configureMiddleware(_ app: Application) {
//    let corsConfiguration = CORSMiddleware.Configuration(
//        allowedOrigin: .all,
//        allowedMethods: [.GET, .POST, .PUT, .OPTIONS, .DELETE, .PATCH],
//        allowedHeaders: [.accept, .authorization, .contentType, .origin, .xRequestedWith, .userAgent, .accessControlAllowOrigin]
//    )
//    let cors = CORSMiddleware(configuration: corsConfiguration)
//    app.middleware.use(cors, at: .beginning)
    app.middleware.use(AsyncCacheControlMiddleware())
    app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory, defaultFile: "index.html"))
    app.middleware.use(app.sessions.middleware)
}
