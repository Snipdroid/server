import Fluent
import SQLKit
import SQLKitExtras
import Vapor
import VaporToOpenAPI

struct IconPackController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let iconPacks =
            routes
            .grouped("icon-pack")
            .grouped(OIDCAuthenticator())

        iconPacks
            .post("create", use: createIconPack)
            .openAPI(
                summary: "Create icon pack",
                description: "Create a new icon pack",
                body: .type(IconPack.Create.self),
                response: .type(IconPackDTO.self)
            )

        iconPacks
            .get(use: listIconPacks)
            .openAPI(
                summary: "List icon packs",
                description: "List all icon packs for the authenticated designer",
                response: .type([IconPackDTO].self)
            )

        iconPacks
            .get(":iconPackId", use: getIconPack)
            .openAPI(
                summary: "Get icon pack",
                description:
                    """
                    Get a specific icon pack by ID,
                    does not include its icon pack verisons,
                    use `/icon-pack/:iconPackId/versions` instead
                    """,
                response: .type(IconPackDTO.self)
            )

        iconPacks
            .put(":iconPackId", use: updateIconPack)
            .openAPI(
                summary: "Update icon pack",
                description: "Update an icon pack's name",
                body: .type(IconPack.Update.self),
                response: .type(IconPackDTO.self)
            )

        iconPacks
            .delete(":iconPackId", use: deleteIconPack)
            .openAPI(
                summary: "Delete icon pack",
                description: "Delete an icon pack and all its versions",
                response: .type(HTTPStatus.self)
            )

        iconPacks
            .post(":iconPackId", use: markAsAdapted)
            .openAPI(
                summary: "Mark app as adapted",
                description: "Mark an app as adapted, or remove the adapted mark",
                body: .type(IconPackMarkAppAsAdaptedRequest.self),
                response: .type([IconPackAppDTO].self)
            )

        iconPacks
            .get(":iconPackId", "requests", use: requestsOfIconPack)
            .openAPI(
                summary: "Get requests of icon pack",
                description:
                    "List all apps with request counts for a specific icon pack, sorted by request count descending",
                query: .all(of: .type(PageRequest.self), ["includingAdapted": .boolean]),
                response: .type(Page<AppInfoWithRequestCount>.self)
            )

        routes.get("icon-pack", ":iconPackId", "adapted-apps", use: getAdaptedApps)
            .openAPI(
                summary: "Get adapted apps",
                description: "Get the list of apps that have been adapted",
                query: .type(PageRequest.self),
                response: .type(Page<AppInfoDTO>.self)
            )
    }

    @Sendable
    func createIconPack(req: Request) async throws -> IconPackDTO {
        let designer = try req.auth.require(Designer.self)
        let designerId = try designer.requireID()

        let create = try req.content.decode(IconPack.Create.self)

        // Ensure the icon pack name doesn't already exist for this designer
        guard
            try await IconPack.query(on: req.db)
                .filter(\.$designer.$id == designerId)
                .filter(\.$name == create.name)
                .first() == nil
        else {
            throw InternalError.violationOfUniqueConstraint(IconPack.self)
        }

        let iconPack = IconPack(designerId: designerId, name: create.name)
        try await iconPack.save(on: req.db)

        return iconPack.toDTO()
    }

    @Sendable
    func listIconPacks(req: Request) async throws -> [IconPackDTO] {
        let designer = try req.auth.require(Designer.self)
        let designerId = try designer.requireID()

        let iconPacks = try await IconPack.query(on: req.db)
            .filter(\.$designer.$id == designerId)
            .all()

        return iconPacks.map { $0.toDTO() }
    }

    @Sendable
    func getIconPack(req: Request) async throws -> IconPackDTO {
        let iconPack = try await requireAuthorizedIconPack(req: req, on: req.db)
        return iconPack.toDTO()
    }

    @Sendable
    func updateIconPack(req: Request) async throws -> IconPackDTO {
        let update = try req.content.decode(IconPack.Update.self)
        let iconPack = try await requireAuthorizedIconPack(req: req, on: req.db)

        let designerId = iconPack.$designer.id
        let iconPackId = try iconPack.requireID()

        // Check if new name conflicts with existing icon pack (excluding current one)
        guard
            try await IconPack.query(on: req.db)
                .filter(\.$designer.$id == designerId)
                .filter(\.$name == update.name)
                .filter(\.$id != iconPackId)
                .first() == nil
        else {
            throw InternalError.violationOfUniqueConstraint(IconPack.self)
        }

        iconPack.name = update.name
        try await iconPack.save(on: req.db)

        return iconPack.toDTO()
    }

    @Sendable
    func deleteIconPack(req: Request) async throws -> HTTPStatus {
        let iconPack = try await requireAuthorizedIconPack(req: req, on: req.db)
        try await iconPack.delete(on: req.db)
        return .noContent
    }

    @Sendable
    func markAsAdapted(req: Request) async throws -> [IconPackAppDTO] {
        let markRequest = try req.content.decode(IconPackMarkAppAsAdaptedRequest.self)

        return try await req.db.transaction { db in
            let iconPack = try await requireAuthorizedIconPack(req: req, on: db)
            let iconPackId = try iconPack.requireID()

            // Get the app
            let appInfoList = try await AppInfo.query(on: db)
                .filter(\.$id ~~ markRequest.appInfoIDs)
                .all()

            if markRequest.adapted {
                try await iconPack.$adaptedApps.attach(appInfoList, on: db)
            } else {
                try await iconPack.$adaptedApps.detach(appInfoList, on: db)
            }

            return try await IconPackApp.query(on: db)
                .filter(\.$iconPack.$id == iconPackId)
                .filter(\.$appInfo.$id ~~ markRequest.appInfoIDs)
                .all()
                .map { $0.toDTO() }
        }
    }

    @Sendable
    func requestsOfIconPack(req: Request) async throws -> Page<AppInfoWithRequestCount> {
        let paginationParameters = try req.query.decode(PageRequest.self)
        let includingAdapted = try req.query.get(Bool.self, at: "includingAdapted")

        // Verify ownership
        _ = try await requireAuthorizedIconPack(req: req, on: req.db)
        let iconPackId = try req.parameters.require("iconPackId", as: UUID.self)

        guard let db = req.db as? any SQLDatabase else {
            throw Abort(.internalServerError, reason: "Database does not support SQL")
        }

        // Step 1: Get total count of distinct AppInfos for pagination metadata
        //
        // SELECT COUNT(app_infos.id) AS 'count'
        // FROM request_records
        // JOIN app_infos ON request_records.app_info_id = app_infos.id
        // JOIN icon_pack_versions ON request_records.icon_pack_version_id = icon_pack_versions.id
        // LEFT JOIN icon_pack_apps ON (app_infos.id = icon_pack_apps.app_info_id AND icon_pack_apps.icon_pack_id = ?)
        // WHERE icon_pack_versions.icon_pack_id = ?
        // AND icon_pack_apps.id IS null; -- Not adapted
        var countQuery =
            db
            .select()
            .column(
                SQLFunction("COUNT", args: SQLDistinct(AppInfo.sqlColumn(for: \.$id))),
                as: "count"
            )
            .from(RequestRecord.schema)
            .join(
                AppInfo.schema,
                on: RequestRecord.sqlColumn(for: \.$appInfo.$id),
                .equal,
                AppInfo.sqlColumn(for: \.$id)
            )
            .join(
                IconPackVersion.schema,
                on: RequestRecord.sqlColumn(for: \.$iconPackVersion.$id),
                .equal,
                IconPackVersion.sqlColumn(for: \.$id)
            )
            .join(
                IconPackApp.schema,
                method: .left,
                on: SQLBinaryExpression(
                    left: SQLBinaryExpression(
                        left: AppInfo.sqlColumn(for: \.$id),
                        op: SQLBinaryOperator.equal,
                        right: IconPackApp.sqlColumn(for: \.$appInfo.$id)
                    ),
                    op: SQLBinaryOperator.and,
                    right: SQLBinaryExpression(
                        left: IconPackApp.sqlColumn(for: \.$iconPack.$id),
                        op: SQLBinaryOperator.equal,
                        right: SQLBind(iconPackId)
                    )
                )
            )
            .where(
                IconPackVersion.sqlColumn(for: \.$iconPack.$id), .equal,
                SQLBind(iconPackId)
            )

        if !includingAdapted {
            countQuery = countQuery.where(
                IconPackApp.sqlColumn(for: \.$id), .is, SQLLiteral.null)
        }

        let totalCountRows = try await countQuery.all()

        let total = (try? totalCountRows.first?.decode(column: "count", as: Int.self)) ?? 0
        let per = paginationParameters.per
        let page = paginationParameters.page
        let offset = (page - 1) * per

        // Step 2: Get paginated AppInfo IDs with counts
        var dataQuery =
            db
            .select()
            .column(AppInfo.sqlColumn(for: \.$id), as: "appInfoId")
            .column(
                SQLFunction("COUNT", args: RequestRecord.sqlColumn(for: \.$id)),
                as: "count"
            )
            .column(IconPackApp.sqlColumn(for: \.$id), as: "iconPackAppId")
            .from(RequestRecord.schema)
            .join(
                AppInfo.schema,
                on: RequestRecord.sqlColumn(for: \.$appInfo.$id),
                .equal,
                AppInfo.sqlColumn(for: \.$id)
            )
            .join(
                IconPackVersion.schema,
                on: RequestRecord.sqlColumn(for: \.$iconPackVersion.$id),
                .equal,
                IconPackVersion.sqlColumn(for: \.$id)
            )
            .join(
                IconPackApp.schema,
                method: .left,
                on: SQLBinaryExpression(
                    left: SQLBinaryExpression(
                        left: AppInfo.sqlColumn(for: \.$id),
                        op: SQLBinaryOperator.equal,
                        right: IconPackApp.sqlColumn(for: \.$appInfo.$id)
                    ),
                    op: SQLBinaryOperator.and,
                    right: SQLBinaryExpression(
                        left: IconPackApp.sqlColumn(for: \.$iconPack.$id),
                        op: SQLBinaryOperator.equal,
                        right: SQLBind(iconPackId)
                    )
                )
            )
            .where(
                IconPackVersion.sqlColumn(for: \.$iconPack.$id), .equal,
                SQLBind(iconPackId)
            )

        if !includingAdapted {
            dataQuery = dataQuery.where(
                IconPackApp.sqlColumn(for: \.$id), .is, SQLLiteral.null)
        }

        let queryResults =
            try await dataQuery
            .groupBy(AppInfo.sqlColumn(for: \.$id))
            .groupBy(IconPackApp.sqlColumn(for: \.$id))
            .orderBy(
                SQLOrderBy(
                    expression: SQLFunction(
                        "COUNT", args: RequestRecord.sqlColumn(for: \.$id)),
                    direction: SQLDirection.descending
                )
            )
            .limit(per)
            .offset(offset)
            .all()

        // Extract AppInfo IDs and count mappings
        var appInfoIds: [UUID] = []
        var countMap: [UUID: Int] = [:]
        var iconPackAppIdMap: [UUID: UUID] = [:]

        for row in queryResults {
            if let id = try? row.decode(column: "appInfoId", as: UUID.self),
                let count = try? row.decode(column: "count", as: Int.self)
            {
                appInfoIds.append(id)
                countMap[id] = count
                if let iconPackAppId = try? row.decode(column: "iconPackAppId", as: UUID.self) {
                    iconPackAppIdMap[id] = iconPackAppId
                }
            }
        }

        // Step 3: Fetch AppInfo objects using Fluent
        let appInfos = try await AppInfo.query(on: req.db)
            .filter(\.$id ~~ appInfoIds)
            .all()

        // Step 4: Fetch IconPackApp objects for adapted apps
        let iconPackAppIds = Array(iconPackAppIdMap.values)
        let iconPackApps = try await IconPackApp.query(on: req.db)
            .filter(\.$id ~~ iconPackAppIds)
            .all()
        let iconPackAppMap: [UUID: IconPackApp] = Dictionary(
            uniqueKeysWithValues: iconPackApps.compactMap { iconPackApp in
                guard let id = iconPackApp.id else { return nil }
                return (id, iconPackApp)
            }
        )

        // Maintain the order from the SQL query
        let orderedResults = appInfoIds.compactMap { id -> AppInfoWithRequestCount? in
            guard let appInfo = appInfos.first(where: { $0.id == id }),
                let count = countMap[id]
            else { return nil }

            let iconPackApp = iconPackAppIdMap[id].flatMap { iconPackAppMap[$0] }
            return AppInfoWithRequestCount(
                appInfo: appInfo.toDTO(),
                iconPackApp: iconPackApp?.toDTO(),
                count: count
            )
        }

        // Create and return the page
        return Page(
            items: orderedResults,
            metadata: PageMetadata(
                page: page,
                per: per,
                total: total
            )
        )
    }

    @Sendable
    func getAdaptedApps(req: Request) async throws -> Page<AppInfoDTO> {
        let iconPackId = try req.parameters.require("iconPackId", as: UUID.self)

        guard
            let iconPack =
                try await IconPack
                .query(on: req.db)
                .filter(\.$id == iconPackId)
                .first()
        else {
            throw Abort(.notFound, reason: "Icon pack not found")
        }

        return try await iconPack.$adaptedApps.query(on: req.db)
            .paginate(for: req).map {
                $0.toDTO()
            }
    }

    // MARK: - Private Helpers

    @Sendable
    private func requireAuthorizedIconPack(req: Request, on db: Database) async throws -> IconPack {
        let designer = try req.auth.require(Designer.self)
        let designerId = try designer.requireID()
        let iconPackId = try req.parameters.require("iconPackId", as: UUID.self)

        guard
            let iconPack = try await IconPack.query(on: db)
                .join(Designer.self, on: \IconPack.$designer.$id == \Designer.$id)
                .filter(\IconPack.$id == iconPackId)
                .filter(Designer.self, \.$id == designerId)
                .first()
        else {
            throw Abort(.notFound)
        }

        return iconPack
    }
}
