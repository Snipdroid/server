import Fluent
import Vapor

func routes(_ app: Application) throws {
//    app.get { req async throws -> Response in
//        req.redirect(to: "/index.html")
//    }

    try app.register(collection: AppInfoController())
    try app.register(collection: IconController())
    try app.register(collection: IconPackController())
    try app.register(collection: TagController())
    try app.register(collection: UserAccountController())
}
