import Fluent
import Vapor

func routes(_ app: Application) throws {
    app.get { req in
        return "Yes! It's up and running!"
    }

    app.group("api") { api in
        api.on(.GET, "search") { req -> EventLoopFuture<Page<AppInfo>> in
            guard let searchText: String = req.query["q"] else {
                throw Abort(.notFound)
            }

            app.logger.info("Search app info '\(searchText)'")

            return AppInfo.query(on: req.db)
                .group(.or) { group in
                    group
                        .filter(\.$appName ~~ searchText)
                        .filter(\.$packageName ~~ searchText)
                        .filter(\.$activityName ~~ searchText)
                }
                .paginate(for: req)
        }

        api.on(.POST, "new") { req -> EventLoopFuture<AppInfo> in
            let newAppInfo = try req.content.decode(AppInfo.self)
            newAppInfo.id = UUID()
            return newAppInfo
                .create(on: req.db)
                .map { newAppInfo }
        }

        api.on(.DELETE, "remove") { req -> EventLoopFuture<String> in
            guard let id: UUID = req.query["id"] else {
                throw Abort(.notModified)
            }

            return AppInfo.query(on: req.db)
                .filter(\.$id == id)
                .delete()
                .map { id.uuidString }
        }

        api.on(.GET, "getExample") { req -> AppInfo in
            return AppInfo.getExample()
        }

        api.on(.GET, "getAll") { req -> EventLoopFuture<Page<AppInfo>> in 
            AppInfo.query(on: req.db)
                .paginate(for: req)
        }
    }
}
