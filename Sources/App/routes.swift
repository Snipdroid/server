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

            return AppInfo.query(on: req.db)
                .filter(\.$packageName == newAppInfo.packageName)
                .filter(\.$activityName == newAppInfo.activityName)
                .filter(\.$signature == newAppInfo.signature)
                .first()
                .flatMap { oldAppInfo -> EventLoopFuture<AppInfo> in
                    if let oldAppInfo = oldAppInfo { // existed
                        // oldAppInfo.count = oldAppInfo.count != nil ? oldAppInfo.count! + 1 : 1
                        oldAppInfo.count! += 1
                        return oldAppInfo
                            .update(on: req.db)
                            .map { oldAppInfo }
                    } else { // not existed
                        newAppInfo.count = 1
                        return newAppInfo
                            .create(on: req.db)
                            .map { newAppInfo }
                    }
                }
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
                .unique()
                .paginate(for: req)
        }

        api.on(.GET, "getAll", ":signature") { req -> EventLoopFuture<Page<AppInfo>> in 

            guard let signature = req.parameters.get("signature") else { 
                // Never happens
                throw Abort(.badRequest)
            }

            return AppInfo.query(on: req.db)
                .filter(\.$signature == signature)
                .sort(\.$count)
                .paginate(for: req)
        }
    }
}
