import Fluent
import Vapor

func routes(_ app: Application) throws {
    try app.register(collection: DesignerController())
    try app.register(collection: AppInfoController())
    try app.register(collection: AppVersionController())
}
