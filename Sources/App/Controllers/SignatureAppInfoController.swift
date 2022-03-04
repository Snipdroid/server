import Fluent
import Vapor

struct SignatureAppInfoController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let appInfos = routes.grouped("api", ":signature", "appInfo")

        appInfos.get(use: search)
        appInfos.delete(use: delete)
    }

    func delete(req: Request) async throws -> RequestResult {
        guard let signature: String = req.parameters.get("signature") else {
            throw Abort(.badRequest)
        }

        let filterResult =  AppInfo.query(on: req.db).filter(\.$signature == signature)
        let count = try await filterResult.count()
        try await filterResult.delete()

        return .init(code: 200, isSuccess: true, message: "Deleted all \(count) of signature \(signature)")
    }

    func search(req: Request) async throws -> Page<AppInfo> {
        guard let signature = req.parameters.get("signature") else { 
            throw Abort(.badRequest)
        }

        if let searchText: String = req.query["q"] {
            return try await normalSearch(searchText, in: signature, for: req)
        } else if let regexPattern: String = req.query["regex"] {
            return try await regexSearch(regexPattern, in: signature, for: req)
        } else {
            return try await AppInfo.query(on: req.db).filter(\.$signature == signature).paginate(for: req)
        }
    }

    private func normalSearch(_ searchText: String, in signature: String, for req: Request) async throws -> Page<AppInfo> {
        let searchTextMatrix = searchText.split(separator: "|").map { $0.split(separator: " ") }
        req.logger.info("Search app '\(searchTextMatrix)'")
        return try await AppInfo.query(on: req.db)
            .filter(\.$signature == signature)
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

    private func regexSearch(_ pattern: String, in signature: String, for req: Request) async throws -> Page<AppInfo> {
        guard let page = try? req.query.decode(PageRequest.self) else {
            req.logger.error("Failed to decode page metadata")
            throw Abort(.badRequest)
        }

        req.logger.info("Regex search app \(pattern)") 
        
        var filterResult = [AppInfo]()
        for appInfo in try await AppInfo.query(on: req.db).filter(\.$signature == signature).all() {
            if try appInfo.regexSearch(\.appName, with: pattern) ||
            appInfo.regexSearch(\.packageName, with: pattern) ||
            appInfo.regexSearch(\.activityName, with: pattern) {
                filterResult.append(appInfo)
            }
        }

        return filterResult.paginate(for: page)
    }
}