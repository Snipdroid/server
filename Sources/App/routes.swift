import Fluent
import Vapor

func routes(_ app: Application) throws {
    app.get { req in
        return "Yes! It works!"
    }

    // try app.register(collection: TodoController())
}
