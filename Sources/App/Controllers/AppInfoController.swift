import Fluent
import FluentSQL
import Vapor

struct AppInfoController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let appInfos = routes.grouped("api", "appinfo")

        appInfos.get(use: search)
        appInfos.post(use: add)
        appInfos.delete(use: delete)
        appInfos.patch(use: patch)
    }
    
    /*
     GET /api/appInfo
     Params:
        - q
        - regex
     */
    func search(req: Request) async throws -> Page<AppInfo> {

        var searchResult: Page<AppInfo>

        if let searchText: String = req.query["q"] {
            searchResult = try await normalSearch(searchText, for: req)
            req.logger.info("QUERY \(searchText) returns \(searchResult.metadata.total) results.")
        } else if let regexPattern: String = req.query["regex"] {
            searchResult = try await regexSearch(regexPattern, for: req)
            req.logger.info("REGEX \(regexPattern) returns \(searchResult.metadata.total) results.")
        } else {
            searchResult = try await AppInfo.query(on: req.db).with(\.$tags).paginate(for: req)
            req.logger.info("ALL QUERY returns \(searchResult.metadata.total) results.")
        }

        return searchResult
    }

    func add(req: Request) async throws -> AppInfo {

        let create = try req.content.decode(AppInfo.Create.self)
        let newAppInfo = AppInfo(create)

        let oldAppInfo = try await AppInfo.query(on: req.db)
            .filter(\.$packageName == newAppInfo.packageName)
            .filter(\.$activityName == newAppInfo.activityName)
            .with(\.$tags)
            .first()

        if let oldAppInfo = oldAppInfo {
            // If already exists, use the old one.
            return oldAppInfo
        } else {
            // If not exists, create and use the new one.
            try await newAppInfo.save(on: req.db)
            return newAppInfo
        }
    }
    
    func delete(req: Request) async throws -> RequestResult {
        
        guard let idList = try? req.content.decode([UUID].self) else {
            throw Abort(.decodingError([UUID].self))
        }
        
        let filterResult = try await AppInfo.query(on: req.db)
            .filter(\.$id ~~ idList)
            .all()
            
        let count = filterResult.count
        // Delete all requests related to these apps
        let deletedRequestCount = try await filterResult
            .compactMap { appInfo in appInfo.id }
            .asyncMap { uuid in
                try await IconRequest.query(on: req.db).filter(\.$appInfo.$id, .equal, uuid).all()
            }
            .flatMap { $0 }
            .asyncMap { iconRequest in
                try await iconRequest.delete(on: req.db)
            }
            .map { _ in 1 } // mapping deletions to 1 so that it's easier to accumulate
            .reduce(0, +)
        
        try await filterResult.delete(on: req.db)
        
        return RequestResult(
            code: 200,
            isSuccess: true,
            message: "Deleted \(count) app(s), \(deletedRequestCount) request(s)."
        )
    }
    
    func patch(req: Request) async throws -> RequestResult {
        guard let patches = try? req.content.decode([AppInfo].self) else {
            throw Abort(.decodingError([AppInfo].self))
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

    private func normalSearch(_ searchText: String, for req: Request) async throws -> Page<AppInfo> {
        let searchTextMatrix = searchText.split(separator: "|").map { $0.split(separator: " ") }
        return try await AppInfo.query(on: req.db)
            .group(.or) { group in
                for col in searchTextMatrix {
                    group.group(.and) { subgroup in
                        for word in col {
                            subgroup.group(.or) { subsubgroup in
                                subsubgroup
                                    .filter(\.$appName, .custom("ILIKE"), "%\(word)%")
                                    .filter(\.$packageName ~~ String(word))
                                    .filter(\.$activityName ~~ String(word))
                            }
                        }
                    }
                }
            }
            .sort(.sql(raw: "similarity(app_name, '\(searchText)') DESC"))
            .with(\.$tags)
            .paginate(for: req)
    }

    private func regexSearch(_ pattern: String, for req: Request) async throws -> Page<AppInfo> {
        return try await AppInfo.query(on: req.db)
            .group(.or) { or in
                or.filter(\.$appName, .custom("~"), pattern)
                or.filter(\.$packageName, .custom("~"), pattern)
                or.filter(\.$activityName, .custom("~"), pattern)
            }
            .with(\.$tags)
            .paginate(for: req)
    }
}
