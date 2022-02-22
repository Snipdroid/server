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

        api.on(.POST, "new") { req async throws -> AppInfo in
            let newAppInfo = try { () -> AppInfo in
                let appInfo = try req.content.decode(AppInfo.self)
                appInfo.count = 1
                return appInfo
            }()
            
            let withSignature = newAppInfo.signature != "" && newAppInfo.signature != "app-tracker"

            try await AppInfo.query(on: req.db)
                .filter(\.$packageName == newAppInfo.packageName)
                .filter(\.$activityName == newAppInfo.activityName)
                .filter(\.$appName == "")
                .all()
                .asyncMap {
                    $0.appName = newAppInfo.appName
                    try await $0.save(on: req.db)
                }
                .end()

            if withSignature {
                if let old = try await AppInfo.query(on: req.db)
                    .filter(\.$packageName == newAppInfo.packageName)
                    .filter(\.$activityName == newAppInfo.activityName)
                    .filter(\.$signature == newAppInfo.signature)
                    .first() {
                        old.count! += 1
                        try await old.update(on: req.db)
                    } else {
                        try await newAppInfo.create(on: req.db)
                    }
            }

            if try await AppInfo.query(on: req.db)
                .filter(\.$packageName == newAppInfo.packageName)
                .filter(\.$activityName == newAppInfo.activityName)
                .filter(\.$signature == "")
                .first() == nil {
                    try await newAppInfo.eraseSignature().create(on: req.db)
                }

            return newAppInfo
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
