import Fluent
import FluentPostgresDriver
import Vapor

// configures your application
public func configure(_ app: Application) throws {
    // uncomment to serve files from /Public folder
    // app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))
    app.logger.logLevel = .info

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

    guard let postgresUrl = Environment.get("POSTGRES_URL") else {
        app.logger.error("Environment variable POSTGRES_URL not found in .env file.")
        exit(1)
    }
    try app.databases.use(.postgres(url: postgresUrl), as: .psql)
    app.migrations.add(CreateAppInfo())
    app.migrations.add(RemoveSignature())
    app.migrations.add(CreateIconPack())
    app.migrations.add(CreateIconRequest())
    app.migrations.add(CreateTag())
    app.migrations.add(CreateAppInfoTagPivot())

    if let httpProxyAddr = Environment.get("HTTP_PROXY_ADDR"),
       let httpProxyPort = Environment.get("HTTP_PROXY_PORT"),
       let httpProxyPortNumber = Int(httpProxyPort)
    {
        app.logger.info("Using http proxy http://\(httpProxyAddr):\(httpProxyPortNumber)")
        app.http.client.configuration.proxy = .server(host: httpProxyAddr, port: httpProxyPortNumber)
    }

    // register routes
    try routes(app)
}

private func configureHttp(_ app: Application) {
    app.http.server.configuration.port = 2080
}

private func configureMiddleware(_ app: Application) {
    let corsConfiguration = CORSMiddleware.Configuration(
        allowedOrigin: .all,
        allowedMethods: [.GET, .POST, .PUT, .OPTIONS, .DELETE, .PATCH],
        allowedHeaders: [.accept, .authorization, .contentType, .origin, .xRequestedWith, .userAgent, .accessControlAllowOrigin]
    )
    let cors = CORSMiddleware(configuration: corsConfiguration)
    app.middleware.use(cors, at: .beginning)
    app.middleware.use(CacheControlMiddleware())
    app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))
}
