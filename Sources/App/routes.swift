import Fluent
import Vapor

func routes(_ app: Application) throws {
    app.get { req async throws -> String in
        return "Yes! It's up and running!"
    }

    try app.register(collection: AppInfoController())
    try app.register(collection: SignatureAppInfoController())
    try app.register(collection: IconController())
}
