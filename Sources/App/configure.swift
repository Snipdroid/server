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

    guard let baseUrl = Environment.get("BASE_URL") else {
        app.logger.error("Environment variable BASE_URL not found in .env file.")
        exit(1)
    }
    app.baseUrl = baseUrl

    guard let postgresUrl = Environment.get("POSTGRES_URL") else {
        app.logger.error("Environment variable POSTGRES_URL not found in .env file.")
        exit(1)
    }
    try app.databases.use(.postgres(url: postgresUrl), as: .psql)
    app.migrations.add(CreateAppInfo())

    if let httpProxyAddr = Environment.get("HTTP_PROXY_ADDR"), 
        let httpProxyPort = Environment.get("HTTP_PROXY_PORT"),
        let httpProxyPortNumber = Int(httpProxyPort) {
            app.logger.info("Using http proxy http://\(httpProxyAddr):\(httpProxyPortNumber)")
            app.http.client.configuration.proxy = .server(host: httpProxyAddr, port: httpProxyPortNumber)
    }

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
