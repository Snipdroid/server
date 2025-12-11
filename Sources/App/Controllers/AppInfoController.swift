import Fluent
import PostgresKit
import Vapor
import VaporToOpenAPI

struct AppInfoController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let appInfo = routes.grouped("app-info")

        appInfo
            .get("search", use: search)
            .openAPI(
                summary: "Search for apps",
                description:
                    "Search for apps using a simple query or advanced filters. The `query` parameter searches across name, package name, and main activity. Advanced filters (byName, byPackageName, byMainActivity) can be combined with query using AND logic. Use `sortBy` to control result ordering.",
                query: .type(AppInfoQueryRequest.self),
                response: .type(Page<AppInfoDTO>.self)
            )

        appInfo.grouped(IconPackVersionAuthenticator())
            .post("create", use: create)
            .openAPI(
                summary: "Create or update app information",
                description: """
                    Creates or updates app information.
                    If an app with the same package name and main activity already exists, it will be updated. Otherwise, a new app will be created.
                    Localized names are also created or updated.
                    A request record is created for each app to associate it with the authenticated icon pack.
                    """,
                body: .type(Set<AppInfoCreateSingleRequest>.self),
                response: .type([AppInfoDTO].self)
            )
    }

    @Sendable
    func search(req: Request) async throws -> Page<AppInfoDTO> {
        let query = try req.query.decode(AppInfoQueryRequest.self)
        let sortBy = query.sortBy ?? .count

        var queryBuilder: QueryBuilder<AppInfo> = AppInfo.query(on: req.db)
            .with(\.$localizedNames)

        // Track search term for relevance sorting
        var searchTerm: String? = nil

        // Step 1: Handle unified `query` parameter (searches all fields)
        if let simpleQuery = query.query, !simpleQuery.isEmpty {
            searchTerm = simpleQuery

            // Search across localized names
            let nameMatchIds = try await AppLocalizedName.query(on: req.db)
                .filter(\.$name, .custom("ILIKE"), "%\(simpleQuery)%")
                .all()
                .map(\.$appInfo.id)

            // Search across package names
            let packageMatchIds = try await AppInfo.query(on: req.db)
                .filter(\.$packageName, .custom("ILIKE"), "%\(simpleQuery)%")
                .all()
                .compactMap(\.id)

            // Search across main activities
            let activityMatchIds = try await AppInfo.query(on: req.db)
                .filter(\.$mainActivity, .custom("ILIKE"), "%\(simpleQuery)%")
                .all()
                .compactMap(\.id)

            // Union all matching IDs (OR logic across fields)
            let allMatchingIds = Set(nameMatchIds + packageMatchIds + activityMatchIds)

            if allMatchingIds.isEmpty {
                // No matches found, return empty page
                return Page(items: [], metadata: .init(page: 1, per: 20, total: 0))
            }

            queryBuilder = queryBuilder.filter(\.$id ~~ Array(allMatchingIds))
        }

        // Step 2: Apply advanced filters (AND logic on top of query results)
        if let byName = query.byName, !byName.isEmpty {
            searchTerm = searchTerm ?? byName

            let appInfoIds = try await AppLocalizedName.query(on: req.db)
                .filter(\.$name, .custom("ILIKE"), "%\(byName)%")
                .sort(
                    .sql(
                        embed:
                            "similarity(\(idents: ["app_localized_names", "name"], joinedBy: "."), \(bind: byName)) DESC"
                    )
                )
                .all()
                .uniqued(on: \.$appInfo.id)
                .map(\.$appInfo.id)

            queryBuilder = queryBuilder.filter(\.$id ~~ appInfoIds)
        }

        if let byPackageName = query.byPackageName, !byPackageName.isEmpty {
            searchTerm = searchTerm ?? byPackageName
            queryBuilder = queryBuilder.filter(
                \.$packageName, .custom("ILIKE"), "%\(byPackageName)%")
        }

        if let byMainActivity = query.byMainActivity, !byMainActivity.isEmpty {
            searchTerm = searchTerm ?? byMainActivity
            queryBuilder = queryBuilder.filter(
                \.$mainActivity, .custom("ILIKE"), "%\(byMainActivity)%")
        }

        // Step 3: Apply sorting
        switch sortBy {
        case .relevance:
            if let term = searchTerm {
                // Sort by similarity to search term, then by count
                queryBuilder =
                    queryBuilder
                    .sort(
                        .sql(
                            embed:
                                "GREATEST(similarity(package_name, \(bind: term)), similarity(main_activity, \(bind: term))) DESC"
                        )
                    )
                    .sort(\.$count, .descending)
            } else {
                // No search term, fall back to count
                queryBuilder = queryBuilder.sort(\.$count, .descending)
            }
        case .count:
            queryBuilder = queryBuilder.sort(\.$count, .descending)
        }

        let page = try await queryBuilder.paginate(for: req)
        return page.map { $0.toDTO() }
    }

    @Sendable
    func create(req: Request) async throws -> [AppInfo] {
        let iconPackVersionId = try? req.auth.require(IconPackVersion.self).requireID()
        let creates = try req.content.decode(Set<AppInfoCreateSingleRequest>.self)

        // 1. Batch query existing AppInfo
        let existingAppInfos = try await AppInfo.query(on: req.db)
            .group(.or) { or in
                creates.forEach { create in
                    or.group(.and) { and in
                        and.filter(\.$packageName == create.packageName)
                        and.filter(\.$mainActivity == create.mainActivity)
                    }
                }
            }
            .with(\.$localizedNames)
            .all()

        // 2. Create a quick lookup table for existing AppInfo by packageName and mainActivity
        struct AppInfoKey: Hashable {
            let packageName: String
            let mainActivity: String
        }
        let existingMap: [AppInfoKey: AppInfo] = existingAppInfos.reduce(into: [:]) {
            result, appInfo in
            result[
                AppInfoKey(packageName: appInfo.packageName, mainActivity: appInfo.mainActivity)] =
                appInfo
        }

        // 3. Create new AppInfos for non-existing entries
        let newAppInfos = creates.compactMap { create -> AppInfo? in
            let key = AppInfoKey(packageName: create.packageName, mainActivity: create.mainActivity)
            if existingMap[key] == nil {
                return AppInfo(create: create)
            }
            return nil
        }

        // 4. Batch save new AppInfos
        try await newAppInfos.create(on: req.db)

        // 5. Build complete lookup map for all AppInfos (existing + new)
        let allAppInfosMap = (existingAppInfos + newAppInfos).reduce(into: existingMap) { result, appInfo in
            result[AppInfoKey(packageName: appInfo.packageName, mainActivity: appInfo.mainActivity)] = appInfo
        }

        // 6. Batch query existing localized names
        let appInfoIds = allAppInfosMap.values.compactMap { try? $0.requireID() }
        let existingLocalizedNamesMap = try await AppLocalizedName.query(on: req.db)
            .filter(\.$appInfo.$id ~~ appInfoIds)
            .all()
            .reduce(into: [UUID: [String: AppLocalizedName]]()) { result, name in
                result[name.$appInfo.id, default: [:]][name.languageCode] = name
            }

        // 7. Prepare new localized names and updates by looking up AppInfo by key
        let (newLocalizedNames, localizedNamesToUpdate) = creates.reduce(into: ([AppLocalizedName](), [AppLocalizedName]())) { result, create in
            let key = AppInfoKey(packageName: create.packageName, mainActivity: create.mainActivity)
            guard let appInfo = allAppInfosMap[key], let appInfoId = try? appInfo.requireID() else { return }

            if let existingName = existingLocalizedNamesMap[appInfoId]?[create.languageCode] {
                existingName.name = create.localizedName
                result.1.append(existingName)
            } else {
                result.0.append(AppLocalizedName(
                    appInfoId: appInfoId,
                    languageCode: create.languageCode,
                    name: create.localizedName,
                    isPrimary: false
                ))
            }
        }

        // 8. Batch create new localized names
        try await newLocalizedNames.create(on: req.db)

        // 9. Update existing localized names
        for name in localizedNamesToUpdate {
            try await name.update(on: req.db)
        }

        // 10. Batch create request records
        let requestRecords = creates.compactMap { create -> RequestRecord? in
            let key = AppInfoKey(packageName: create.packageName, mainActivity: create.mainActivity)
            guard let appInfoId = try? allAppInfosMap[key]?.requireID() else { return nil }
            return RequestRecord(appInfoId: appInfoId, iconPackVersionId: iconPackVersionId)
        }
        try await requestRecords.create(on: req.db)

        return Array(allAppInfosMap.values)
    }

    @Sendable
    func createSingle(req: Request) async throws -> AppInfoDTO {
        let iconPackVersionId = try? req.auth.require(IconPackVersion.self).requireID()
        guard let create = try req.content.decode([AppInfoCreateSingleRequest].self).first else {
            throw InternalError.decodingError([AppInfoCreateSingleRequest].self)
        }

        // 1. Find or create an app info
        let appInfo = try await {
            if let existingAppInfo = try await AppInfo.query(on: req.db)
                .filter(\.$packageName == create.packageName)
                .filter(\.$mainActivity == create.mainActivity)
                .with(\.$localizedNames)
                .first()
            {
                return existingAppInfo
            } else {
                let newAppInfo = AppInfo(create: create)
                try await newAppInfo.save(on: req.db)
                return newAppInfo
            }
        }()

        guard let appInfoId = try? appInfo.requireID() else {
            throw InternalError.failedToAcquireID(AppInfo.self)
        }

        // 2. Update or create a new localized name
        if let existingLocalizedName =
            try await AppLocalizedName
            .query(on: req.db)
            .filter(\.$appInfo.$id == appInfoId)
            .filter(\.$languageCode == create.languageCode)
            .first()
        {
            existingLocalizedName.name = create.localizedName
            try await existingLocalizedName.update(on: req.db)
        } else {
            let newLocalizedName = AppLocalizedName(
                appInfoId: appInfoId,
                languageCode: create.languageCode,
                name: create.localizedName,
                isPrimary: false
            )
            try await newLocalizedName.save(on: req.db)
        }

        // 3. Record the request
        let newRequestRecord = RequestRecord(
            appInfoId: appInfoId, iconPackVersionId: iconPackVersionId)
        try await newRequestRecord.save(on: req.db)

        return appInfo.toDTO()
    }
}
