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

        api.on(.GET, "search", "regex") { req async throws -> Page<AppInfo> in

            guard let pattern: String = req.query["q"] else {
                throw Abort(.badRequest)
            }

            guard let page = try? req.query.decode(PageRequest.self) else {
                req.logger.error("Failed to decode page metadata")
                throw Abort(.badRequest)
            }

            app.logger.info("Regex search app \(pattern)") 
            
            var filterResult = [AppInfo]()
            for appInfo in try await AppInfo.query(on: req.db).all() {
                if try appInfo.regexSearch(\.appName, with: pattern) ||
                appInfo.regexSearch(\.packageName, with: pattern) ||
                appInfo.regexSearch(\.activityName, with: pattern) {
                    filterResult.append(appInfo)
                }
            }

            return filterResult.paginate(for: page)
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

            let idList: [UUID] = try {
                if let idList = try? req.content.decode([UUID].self) {
                    return idList
                } else if let id: UUID = req.query["id"] {
                    return [id]
                } else {
                    throw Abort(.badRequest)
                }
            }()
            

            let filterResult = try await AppInfo.query(on: req.db)
                .filter(\.$id ~~ idList)
                .all()
                
            let count = filterResult.count
            try await filterResult.delete(on: req.db)
            
            return RequestResult(code: 200, isSuccess: true, message: "Deleted \(count) rows.")
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

        api.on(.PATCH, "update") { req async throws -> RequestResult in
            guard let patcher = try? req.content.decode(AppInfo.self) else {
                throw Abort(.badRequest)
            }

            guard let id = patcher.id else {
                return .init(code: 400, isSuccess: false, message: "Patch needs and id.")
            }

            guard let appInfoToPatch = try await AppInfo.query(on: req.db).filter(\.$id == id).first() else {
                return .init(code: 400, isSuccess: false, message: "App info with requested ID not found.")
            }
            appInfoToPatch.appName = patcher.appName

            return .init(code: 200, isSuccess: true, message: "Update succeeded.")
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
