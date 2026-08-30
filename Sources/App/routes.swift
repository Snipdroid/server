import Fluent
import Vapor
import VaporToOpenAPI

func routes(_ app: Application) throws {
    app.get("swagger") { req in
        req.application.routes.openAPI(
            info: InfoObject(
                title: "AppTracker", version: "3.0.0"
            )
        )
    }.excludeFromOpenAPI()

    try app.register(collection: DesignerController())
    try app.register(collection: AppInfoController())
    try app.register(collection: IconPackController())
    try app.register(collection: IconPackVersionController())
    try app.register(collection: AppIconController())
    try app.register(collection: RequestRecordController())
    try app.register(collection: MustacheController())
    try app.register(collection: TagController())
    try app.register(collection: IconPackAppController())
    try app.register(collection: IconPackCollaboratorController())
}
