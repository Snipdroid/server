import Fluent
import Vapor

func routes(_ app: Application) throws {
//    app.get { req async throws -> String in
//        return "Yes! It's up and running!"
//    }

    try app.register(collection: AppInfoController())
    try app.register(collection: IconController())
    try app.register(collection: IconPackController())
    try app.register(collection: TagController())
    try app.register(collection: UserAccountController())
}
