import Fluent
import Vapor

struct AppInfoController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let appInfos = routes.grouped("api", "appinfo")

        appInfos.get(use: search)
        appInfos.post(use: add)
        appInfos.delete(use: delete)
        appInfos.patch(use: patch)

        let web = routes.grouped("web")
        web.get(use: index)
    }

    func index(req: Request) async throws -> View {
        var buildQuery: QueryBuilder<AppInfo>

        if let searchText: String = req.query["q"] {
            buildQuery = normalSearch(searchText, for: req)
        } else if let regexPattern: String = req.query["regex"] {
            buildQuery = regexSearch(regexPattern, for: req)
        } else {
            buildQuery = AppInfo.query(on: req.db)
                .with(\.$tags)
                .with(\.$requests)
        }

        let apps = try await buildQuery.sort(\.$count, .descending).paginate(for: req).items

        struct RenderContext: Content {
            let apps: [AppInfo]
            let searchText: String
        }

        return try await req.view.render(
            "index", 
            RenderContext(
                apps: apps, 
                searchText: req.query["q"] ?? "Search..."
            )
        )
    }
    
    /*
     GET /api/appInfo
     Params:
        - q
        - regex
     */
    func search(req: Request) async throws -> Page<AppInfo> {

        var buildQuery: QueryBuilder<AppInfo>

        if let searchText: String = req.query["q"] {
            buildQuery = normalSearch(searchText, for: req)
        } else if let regexPattern: String = req.query["regex"] {
            buildQuery = regexSearch(regexPattern, for: req)
        } else {
            buildQuery = AppInfo.query(on: req.db)
                .with(\.$tags)
                .with(\.$requests)
        }

        return try await buildQuery
            .sort(\.$createdAt, .descending) // Newest first
            .sort(\.$count, .descending) // Frequency first
            .paginate(for: req)
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
            oldAppInfo.count += 1
            try await oldAppInfo.update(on: req.db)
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

    private func normalSearch(_ searchText: String, for req: Request) -> QueryBuilder<AppInfo> {
        let searchTextArray = searchText.split(separator: " ")
        return AppInfo.query(on: req.db)
            .group(.or) { group in
                searchTextArray.forEach { keyword in
                    group.filter(\.$appName, .custom("ILIKE"), "%\(keyword)%")
                    group.filter(\.$packageName ~~ String(keyword))
                    group.filter(\.$activityName ~~ String(keyword))
                }
            }
            .sort(.sql(raw: "similarity(app_name, '\(searchText)') DESC"))
            .with(\.$tags)
            .with(\.$requests)
    }

    private func regexSearch(_ pattern: String, for req: Request) -> QueryBuilder<AppInfo> {
        return AppInfo.query(on: req.db)
            .group(.or) { or in
                or.filter(\.$appName, .custom("~"), pattern)
                or.filter(\.$packageName, .custom("~"), pattern)
                or.filter(\.$activityName, .custom("~"), pattern)
            }
            .with(\.$tags)
            .with(\.$requests)
    }
}
