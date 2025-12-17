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
                query: .all(of: .type(AppInfoQueryRequest.self), .type(PageRequest.self)),
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

        appInfo.grouped(OIDCAuthenticator(), EnsureCuratorMiddleware())
            .post(":appInfoID", "tag", use: tagAppInfo)
            .openAPI(
                summary: "Tag an app",
                description: "Add or remove a tag to an app.",
                body: .type(AppInfoTagRequest.self),
                response: .type(AppInfoDTO.self)
            )

        appInfo.get(":appInfoID", "tags", use: getAppInfoTags)
            .openAPI(
                summary: "Get tags for an app",
                description: "Get tags for an app.",
                response: .type([TagDTO].self)
            )
    }

    @Sendable
    func search(req: Request) async throws -> Page<AppInfoDTO> {
        let query = try req.query.decode(AppInfoQueryRequest.self)
        let sortBy: SortOption =
            switch (query.query, query.sortBy) {
            case (.none, _):
                .count
            case (.some(let query), .none):
                query.isEmpty ? .count : .relevance
            case (.some, .some(let sortBy)):
                sortBy
            }

        // Branch on sortBy: relevance uses SQLKit, count uses existing Fluent
        switch sortBy {
        case .relevance:
            return try await searchWithRelevance(req: req, query: query)
        case .count:
            return try await searchWithCount(req: req, query: query)
        }
    }

    @Sendable
    private func searchWithCount(
        req: Request,
        query: AppInfoQueryRequest
    ) async throws -> Page<AppInfoDTO> {
        // Keep existing Fluent implementation for count-based sorting
        var queryBuilder: QueryBuilder<AppInfo> = AppInfo.query(on: req.db)
            .with(\.$localizedNames)

        // Step 1: Handle unified `query` parameter (searches all fields)
        if let simpleQuery = query.query, !simpleQuery.isEmpty {
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
            let appInfoIds = try await AppLocalizedName.query(on: req.db)
                .filter(\.$name, .custom("ILIKE"), "%\(byName)%")
                .all()
                .uniqued(on: \.$appInfo.id)
                .map(\.$appInfo.id)

            queryBuilder = queryBuilder.filter(\.$id ~~ appInfoIds)
        }

        if let byPackageName = query.byPackageName, !byPackageName.isEmpty {
            queryBuilder = queryBuilder.filter(
                \.$packageName, .custom("ILIKE"), "%\(byPackageName)%")
        }

        if let byMainActivity = query.byMainActivity, !byMainActivity.isEmpty {
            queryBuilder = queryBuilder.filter(
                \.$mainActivity, .custom("ILIKE"), "%\(byMainActivity)%")
        }

        // Sort by count
        queryBuilder = queryBuilder.sort(\.$count, .descending)

        let page = try await queryBuilder.paginate(for: req)
        return page.map { $0.toDTO() }
    }

    @Sendable
    private func searchWithRelevance(
        req: Request,
        query: AppInfoQueryRequest
    ) async throws -> Page<AppInfoDTO> {
        // SQLKit-based relevance search
        guard let db = req.db as? any SQLDatabase else {
            throw Abort(.internalServerError, reason: "Database does not support SQL")
        }

        // Extract and process search terms
        var searchTerms: [String] = []
        var fullSearchQuery: String = ""

        if let simpleQuery = query.query, !simpleQuery.isEmpty {
            fullSearchQuery = simpleQuery
            searchTerms =
                simpleQuery
                .split(separator: " ")
                .map(String.init)
                .filter { !$0.isEmpty }
        }

        // Early return if no search terms
        guard !searchTerms.isEmpty else {
            return Page(items: [], metadata: PageMetadata(page: 1, per: 20, total: 0))
        }

        // Helper function to build WHERE clause with OR logic across search terms
        func addSearchTermConditions(
            _ dataQuery: SQLSelectBuilder,
            terms: [String]
        ) -> SQLSelectBuilder {

            let columns: [SQLColumn] = [
                AppInfo.sqlColumn(for: \.$defaultName),
                AppInfo.sqlColumn(for: \.$packageName),
                AppInfo.sqlColumn(for: \.$mainActivity),
                AppLocalizedName.sqlColumn(for: \.$name),
            ]

            let conditions: [SQLExpression] =
                terms
                .map { "%\($0)%" }
                .flatMap { pattern in
                    columns.map {
                        SQLBinaryExpression(
                            left: $0,
                            op: SQLRaw("ILIKE"),
                            right: SQLBind(pattern)
                        )
                    }
                }

            guard let first = conditions.first else { return dataQuery }

            let combined = conditions.dropFirst().reduce(first) { acc, next in
                SQLBinaryExpression(left: acc, op: SQLBinaryOperator.or, right: next)
            }

            return dataQuery.where(combined)
        }

        // Build relevance scoring expression
        func buildRelevanceExpression(
            for column: SQLColumn
        ) -> SQLFunction {
            SQLFunction(
                "COALESCE",
                args: [
                    SQLFunction(
                        "similarity",
                        args: [
                            column,
                            SQLBind(fullSearchQuery),
                        ]),
                    SQLLiteral.numeric("0"),
                ]
            )
        }

        let relevanceScore = SQLFunction(
            "MAX",
            args: [
                SQLFunction(
                    "GREATEST",
                    args: [
                        AppInfo.sqlColumn(for: \.$defaultName),
                        AppInfo.sqlColumn(for: \.$packageName),
                        AppInfo.sqlColumn(for: \.$mainActivity),
                        AppLocalizedName.sqlColumn(for: \.$name),
                    ].map(buildRelevanceExpression))
            ]
        )

        // Pagination
        let paginationRequest = try req.query.decode(PageRequest.self)
        let page = paginationRequest.page
        let per = paginationRequest.per
        let offset = (page - 1) * per

        // Build single query with window function
        var dataQuery =
            db
            .select()
            .column(AppInfo.sqlColumn(for: \.$id), as: "app_info_id")
            .column(
                SQLRaw("COUNT(*) OVER()"),  // Window function for total count
                as: "total_count"
            )
            .from(AppInfo.schema)
            .join(
                AppLocalizedName.self,
                method: .left,
                on: AppLocalizedName.sqlColumn(for: \.$appInfo.$id),
                .equal,
                AppInfo.sqlColumn(for: \.$id)
            )

        // Add advanced filters FIRST (performance optimization)
        if let byName = query.byName, !byName.isEmpty {
            dataQuery = dataQuery.where(
                SQLBinaryExpression(
                    left: AppLocalizedName.sqlColumn(for: \.$name),
                    op: SQLRaw("ILIKE"),
                    right: SQLBind("%\(byName)%")
                )
            )
        }

        if let byPackageName = query.byPackageName, !byPackageName.isEmpty {
            dataQuery = dataQuery.where(
                SQLBinaryExpression(
                    left: AppInfo.sqlColumn(for: \.$packageName),
                    op: SQLRaw("ILIKE"),
                    right: SQLBind("%\(byPackageName)%")
                )
            )
        }

        if let byMainActivity = query.byMainActivity, !byMainActivity.isEmpty {
            dataQuery = dataQuery.where(
                SQLBinaryExpression(
                    left: AppInfo.sqlColumn(for: \.$mainActivity),
                    op: SQLRaw("ILIKE"),
                    right: SQLBind("%\(byMainActivity)%")
                )
            )
        }

        // Add search term conditions
        dataQuery = addSearchTermConditions(dataQuery, terms: searchTerms)

        let queryResults =
            try await dataQuery
            .groupBy(AppInfo.sqlColumn(for: \.$id))
            .orderBy(SQLOrderBy(expression: relevanceScore, direction: SQLDirection.descending))
            .orderBy(
                SQLOrderBy(
                    expression: AppInfo.sqlColumn(for: \.$count), direction: SQLDirection.descending
                )
            )
            .limit(per)
            .offset(offset)
            .all()

        // Extract ordered IDs and total count
        var total = 0
        let appInfoIds: [UUID] = queryResults.compactMap { row in
            // Extract total from first row (all rows have same value due to window function)
            if total == 0, let rowTotal = try? row.decode(column: "total_count", as: Int.self) {
                total = rowTotal
            }
            return try? row.decode(column: "app_info_id", as: UUID.self)
        }

        // Early return if no results
        guard !appInfoIds.isEmpty else {
            return Page(items: [], metadata: PageMetadata(page: page, per: per, total: 0))
        }

        // Query full AppInfo entities with relations
        let appInfos = try await AppInfo.query(on: req.db)
            .filter(\.$id ~~ appInfoIds)
            .with(\.$localizedNames)
            .all()

        // Create lookup map
        let appInfoMap: [UUID: AppInfo] = Dictionary(
            uniqueKeysWithValues: appInfos.compactMap { appInfo in
                guard let id = appInfo.id else { return nil }
                return (id, appInfo)
            }
        )

        // Maintain SQL result order
        let orderedAppInfos = appInfoIds.compactMap { appInfoMap[$0] }

        // Convert to DTOs
        let dtos = orderedAppInfos.map { $0.toDTO() }

        // Return paginated response
        return Page(
            items: dtos,
            metadata: PageMetadata(page: page, per: per, total: total)
        )
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
        let allAppInfosMap = (existingAppInfos + newAppInfos).reduce(into: existingMap) {
            result, appInfo in
            result[
                AppInfoKey(packageName: appInfo.packageName, mainActivity: appInfo.mainActivity)] =
                appInfo
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
        let (newLocalizedNames, localizedNamesToUpdate) = creates.reduce(
            into: ([AppLocalizedName](), [AppLocalizedName]())
        ) { result, create in
            let key = AppInfoKey(packageName: create.packageName, mainActivity: create.mainActivity)
            guard let appInfo = allAppInfosMap[key], let appInfoId = try? appInfo.requireID() else {
                return
            }

            if let existingName = existingLocalizedNamesMap[appInfoId]?[create.languageCode] {
                existingName.name = create.localizedName
                result.1.append(existingName)
            } else {
                result.0.append(
                    AppLocalizedName(
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
            return RequestRecord(
                appInfoId: appInfoId, iconPackVersionId: iconPackVersionId,
                isSystemApp: create.systemApp)
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

    @Sendable
    func tagAppInfo(req: Request) async throws -> AppInfoDTO {
        let designer = try req.auth.require(Designer.self)
        let designerID = try designer.requireID()
        let taggingRequest = try req.content.decode(AppInfoTagRequest.self)

        guard let appInfoId = req.parameters.get("appInfoID", as: UUID.self) else {
            throw Abort(.badRequest)
        }

        return try await req.db.transaction { transactionalDatabase in
            guard
                let appInfo = try await AppInfo.query(on: transactionalDatabase)
                    .filter(\.$id == appInfoId)
                    .first()
            else {
                throw Abort(.notFound, reason: "App not found")
            }

            guard
                let tag =
                    try await Tag
                    .query(on: transactionalDatabase)
                    .filter(\.$id == taggingRequest.tagID)
                    .first()
            else {
                throw Abort(.notFound, reason: "Tag not found")
            }

            if taggingRequest.remove {
                try await appInfo.$tags.detach(tag, on: transactionalDatabase)
            } else {
                try await appInfo.$tags.attach(tag, method: .ifNotExists, on: transactionalDatabase)
                {
                    $0.$createdBy.id = designerID
                }
            }

            return appInfo.toDTO()
        }
    }

    @Sendable
    func getAppInfoTags(req: Request) async throws -> [TagDTO] {
        guard let appInfoId = req.parameters.get("appInfoID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid app info ID")
        }

        guard
            let appInfo = try await AppInfo.query(on: req.db)
                .filter(\.$id == appInfoId)
                .with(\.$tags)
                .first()
        else {
            throw Abort(.notFound, reason: "App not found")
        }

        return appInfo.tags.map { $0.toDTO() }
    }
}
