import Fluent
import Vapor

func routes(_ app: Application) throws {
    app.get { req in
        return "Yes! It's up and running!"
    }

    app.group("api") { api in
        api.on(.GET, "search") { req async throws -> Page<AppInfo> in
            guard let searchText: String = req.query["q"] else {
                throw Abort(.badRequest)
            }
            let searchTextMatrix = searchText.split(separator: " ").map { $0.split(separator: "+") }
            app.logger.info("Search app '\(searchTextMatrix)'")

            return try await AppInfo.query(on: req.db)
                .filter(\.$signature == "")
                .group(.or) { group in
                    for col in searchTextMatrix {
                        group.group(.and) { subgroup in
                            for word in col {
                                subgroup.group(.or) { subsubgroup in
                                    subsubgroup
                                        .filter(\.$appName ~~ String(word))
                                        .filter(\.$packageName ~~ String(word))
                                        .filter(\.$activityName ~~ String(word))
                                }
                            }
                        }
                    }
                }
                .paginate(for: req)
        }

        api.on(.GET, "search", "regex") { req -> EventLoopFuture<Page<AppInfo>> in

            guard let pattern: String = req.query["q"], let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
                throw Abort(.badRequest)
            }

            guard let page = try? req.query.decode(PageRequest.self) else {
                req.logger.error("Failed to decode page metadata")
                throw Abort(.badRequest)
            }

            app.logger.info("Regex search app \(pattern)")

            return AppInfo.query(on: req.db)
                .all()
                .mapEachCompact { appInfo -> AppInfo? in
                    let doMatch = [appInfo.appName, appInfo.activityName, appInfo.packageName] // Fields to match
                        .map { field -> Bool in
                            let stringRange = NSRange(location: 0, length: field.utf16.count)
                            return regex.firstMatch(in: field, range: stringRange) != nil // check if current field matches
                        }
                        .contains(true) // check if any field matches
                    if doMatch { return appInfo } else { return nil} // if any does, return appInfo
                }
                .map { appInfoList -> Page<AppInfo> in
                    return appInfoList.paginate(for: page)
                }
        }

        api.on(.POST, "new") { req -> EventLoopFuture<AppInfo> in
            let newAppInfo = try req.content.decode(AppInfo.self)
            newAppInfo.id = UUID()
            newAppInfo.signature = newAppInfo.signature == "app-tracker" ? "" : newAppInfo.signature

            let sameAppInfo = AppInfo.query(on: req.db)
                .filter(\.$packageName == newAppInfo.packageName)
                .filter(\.$activityName == newAppInfo.activityName)

            // Update name
            let _ = sameAppInfo.all()
                .mapEach { oldAppInfo -> EventLoopFuture<AppInfo> in
                    if oldAppInfo.appName == "" {
                        oldAppInfo.appName = newAppInfo.appName
                    } 
                    return oldAppInfo.update(on: req.db).map { oldAppInfo }
                }
            

            // look up existance -(T)> add in
            //                   -(F)> do nothing
            //                            ->    has signature  -(F)>    return
            //                                                 -(T)>    look up existance -(T)> count ++
            //                                                                            -(F)> add in

            // Erase signature and copy
            let signatureErased = sameAppInfo
                .filter(\.$signature == "")
                .first()
                .flatMap { oldAppInfo -> EventLoopFuture<AppInfo> in
                    if let oldAppInfo = oldAppInfo {
                        // if exists, no nothing
                        // since the count does not matter
                        return oldAppInfo.update(on: req.db).map { oldAppInfo }
                    } else {
                        let signatureErasedAppInfo = newAppInfo
                        signatureErasedAppInfo.signature = "" // Erase signature
                        return signatureErasedAppInfo.create(on: req.db).map { signatureErasedAppInfo }
                    }
                }

            if newAppInfo.signature == "" {
                return sameAppInfo
                .filter(\.$signature == newAppInfo.signature)
                .first()
                .flatMap { oldAppInfo -> EventLoopFuture<AppInfo> in
                    if let oldAppInfo = oldAppInfo {
                        // if exists, update count
                        oldAppInfo.count! += 1
                        return oldAppInfo.update(on: req.db).map { oldAppInfo }
                    } else {
                        // not exist
                        newAppInfo.count = 1
                        return newAppInfo
                            .create(on: req.db)
                            .map { newAppInfo }
                    }
                }
            } else {
                return signatureErased
            }
        }

        api.on(.DELETE, "remove") { req async throws -> RequestResult in
            guard let id: UUID = req.query["id"] else {
                throw Abort(.badRequest)
            }

            try await AppInfo.query(on: req.db)
                .filter(\.$id == id)
                .delete()
            
            return RequestResult(code: 200, isSuccess: true, message: "Deleted row of ID \(id)")
        }

        api.on(.DELETE, "remove", ":signature") { req async throws -> RequestResult in
            guard let signature: String = req.parameters.get("signature") else {
                throw Abort(.badRequest)
            }

            let filterResult =  AppInfo.query(on: req.db).filter(\.$signature == signature)
            let count = try await filterResult.count()
            try await filterResult.delete()

            return .init(code: 200, isSuccess: true, message: "Deleted all \(count) of signature \(signature)")
        }

        api.on(.GET, "getExample") { req -> AppInfo in
            return AppInfo.getExample()
        }

        api.on(.GET, "getAll") { req async throws -> Page<AppInfo> in
            return try await AppInfo.query(on: req.db).paginate(for: req)
        }

        api.on(.GET, "getAll", ":signature") { req async throws -> Page<AppInfo> in
            guard let signature = req.parameters.get("signature") else { 
                throw Abort(.badRequest)
            }

            return try await AppInfo.query(on: req.db)
                                .filter(\.$signature == signature)
                                .sort(\.$count, .descending)
                                .paginate(for: req)
        }
    }
}
