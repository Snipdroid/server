import Fluent
import FluentSQL
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

    func delete(req: Request) async throws -> RequestResult {
        
        guard let idList = try? req.content.decode([UUID].self) else {
            throw Abort(.decodingError([UUID].self))
        }
        
        let filterResult = try await AppInfo.query(on: req.db)
            .filter(\.$id ~~ idList)
            .all()
            
        let count = filterResult.count
        try await filterResult.delete(on: req.db)
        
        return RequestResult(code: 200, isSuccess: true, message: "Deleted \(count) rows.")
    }

    func add(req: Request) async throws -> AppInfo {

        let newAppInfoDTO = try req.content.decode(AppInfoDTO.self)
        let newAppInfo = AppInfo(newAppInfoDTO)

        let oldAppInfo = try await AppInfo.query(on: req.db)
            .filter(\.$packageName == newAppInfo.packageName)
            .filter(\.$activityName == newAppInfo.activityName)
            .first()

        if let oldAppInfo = oldAppInfo {
            // If already exists, update app names if needed.
            if oldAppInfo.appName != newAppInfo.appName {
                oldAppInfo.appName = newAppInfo.appName
                try await oldAppInfo.save(on: req.db)
            }
        } else {
            // If not exists, create one
            try await newAppInfo.save(on: req.db)
        }
        
        // Requested from icon pack
        if let iconPackName = newAppInfoDTO.iconPack,
           let iconPack = try await IconPack.query(on: req.db).filter(\.$name, .equal, iconPackName).first()
        {
            let appInfoId = oldAppInfo?.id ?? newAppInfo.id!
            if let oldIconRequest = try await IconRequest.query(on: req.db)
                .filter(\.$fromIconPack.$id, .equal, iconPack.id!)
                .filter(\.$appInfo.$id, .equal, appInfoId).first() {
                // Have requested
                oldIconRequest.count += 1;
                try await oldIconRequest.update(on: req.db)
            } else {
                let newIconRequest = IconRequest(from: iconPack.id!, for: appInfoId)
                try await newIconRequest.save(on: req.db)
                // Haven't requested
            }
        }
        
        return oldAppInfo ?? newAppInfo
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
