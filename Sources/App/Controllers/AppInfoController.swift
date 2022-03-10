import Fluent
import Vapor

struct AppInfoController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let appInfos = routes.grouped("api", "appInfo")

        appInfos.get(use: search)
        appInfos.post(use: add)
        appInfos.delete(use: delete)
        appInfos.patch(use: patch)
    }

    func patch(req: Request) async throws -> RequestResult {
        guard let patches = try? req.content.decode([AppInfo].self) else {
            throw Abort(.badRequest)
        }

        var count = 0

        for patch in patches {
            guard let id = patch.id else { continue }
            guard patch.appName != "" else { continue }
            guard let appInfoToPatch = try await AppInfo.query(on: req.db).filter(\.$id == id).first() else { continue }

            appInfoToPatch.appName = patch.appName
            try await appInfoToPatch.update(on: req.db)
            count += 1;
        }

        return .init(code: 200, isSuccess: true, message: "Successfully updated \(count) apps' name.")
    }

    func delete(req: Request) async throws -> RequestResult {
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

    func add(req: Request) async throws -> AppInfo {
        let newAppInfo = try { () -> AppInfo in
            let appInfo = try req.content.decode(AppInfo.self)
            appInfo.count = 1
            appInfo.id = UUID()
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

    func search(req: Request) async throws -> Page<AppInfo> {

        if let searchText: String = req.query["q"] {
            return try await normalSearch(searchText, for: req)
        } else if let regexPattern: String = req.query["regex"] {
            return try await regexSearch(regexPattern, for: req)
        } else {
            return try await AppInfo.query(on: req.db).paginate(for: req)
        }
    }

    private func normalSearch(_ searchText: String, for req: Request) async throws -> Page<AppInfo> {
        let searchTextMatrix = searchText.split(separator: "|").map { $0.split(separator: " ") }
        req.logger.info("Search app '\(searchTextMatrix)'")
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
            .sort(\.$appName, .ascending)
            .paginate(for: req)
    }

    private func regexSearch(_ pattern: String, for req: Request) async throws -> Page<AppInfo> {
        guard let page = try? req.query.decode(PageRequest.self) else {
            req.logger.error("Failed to decode page metadata")
            throw Abort(.badRequest)
        }

        req.logger.info("Regex search app \(pattern)") 
        
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
}