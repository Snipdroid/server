import Fluent
import SQLKit
import Vapor
import VaporToOpenAPI

struct UserinfoResponse: Content {
    let sub: String
    let email: String?
    let name: String?
    let preferredUsername: String?

    enum CodingKeys: String, CodingKey {
        case sub
        case email
        case name
        case preferredUsername = "preferred_username"
    }
}

struct DesignerController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let designer = routes.grouped("designer")

        let protected = designer.grouped(OIDCAuthenticator())

        protected
            .get("me", use: me)
            .openAPI(
                summary: "Get Current Designer",
                description: "Get the currently authenticated designer's profile",
                response: .type(DesignerDTO.self)
            )

        protected
            .post("me", "sync", use: sync)
            .openAPI(
                summary: "Sync Designer Profile",
                description: "Fetch and update profile data from OIDC provider's userinfo endpoint",
                response: .type(DesignerDTO.self)
            )

        protected
            .get("requests", use: listRequest)
            .openAPI(
                summary: "Get App Request Statistics",
                description:
                    "List all apps with request counts for the currently authenticated designer's icon packs, sorted by request count descending",
                query: .type(PageRequest.self),
                response: .type(Page<AppInfoWithRequestCount>.self)
            )
    }

    @Sendable
    func me(req: Request) async throws -> DesignerDTO {
        let designer = try req.auth.require(Designer.self)
        return designer.toDTO()
    }

    @Sendable
    func sync(req: Request) async throws -> DesignerDTO {
        let designer = try req.auth.require(Designer.self)
        let oidcConfig = req.application.oidc

        // Get the bearer token from the request
        guard let token = req.headers.bearerAuthorization?.token else {
            throw Abort(.unauthorized, reason: "Missing bearer token")
        }

        // Call the userinfo endpoint
        let response = try await req.client.get(URI(string: oidcConfig.userinfoURL)) { req in
            req.headers.bearerAuthorization = .init(token: token)
        }

        guard response.status == .ok else {
            throw Abort(
                .badGateway,
                reason: "Failed to fetch userinfo from OIDC provider: \(response.status)")
        }

        let userinfo = try response.content.decode(UserinfoResponse.self)

        // Verify the subject matches
        guard userinfo.sub == designer.oidcSubject else {
            throw Abort(.forbidden, reason: "Token subject mismatch")
        }

        // Update designer profile
        designer.email = userinfo.email
        designer.name = userinfo.name ?? userinfo.preferredUsername
        try await designer.save(on: req.db)

        return designer.toDTO()
    }

    @Sendable
    func listRequest(req: Request) async throws -> Page<AppInfoWithRequestCount> {
        #warning("This route needs a test")
        let designer = try req.auth.require(Designer.self)
        let designerID = try designer.requireID()
        let paginationParameters = try req.query.decode(PageRequest.self)

        guard let db = req.db as? any SQLDatabase else {
            throw Abort(.internalServerError, reason: "Database does not support SQL")
        }

        // Step 1: Get total count of distinct AppInfos for pagination metadata
        let totalCountRows =
            try await db
            .select()
            .column(
                SQLFunction("COUNT", args: SQLDistinct(SQLColumn("id", table: AppInfo.schema))),
                as: "count"
            )
            .from(RequestRecord.schema)
            .join(
                AppInfo.schema,
                on: SQLColumn("app_info_id", table: RequestRecord.schema),
                .equal,
                SQLColumn("id", table: AppInfo.schema)
            )
            .join(
                IconPackVersion.schema,
                on: SQLColumn("icon_pack_version_id", table: RequestRecord.schema),
                .equal,
                SQLColumn("id", table: IconPackVersion.schema)
            )
            .join(
                IconPack.schema,
                on: SQLColumn("icon_pack_id", table: IconPackVersion.schema),
                .equal,
                SQLColumn("id", table: IconPack.schema)
            )
            .where(SQLColumn("designer_id", table: IconPack.schema), .equal, SQLBind(designerID))
            .all()

        let total = (try? totalCountRows.first?.decode(column: "count", as: Int.self)) ?? 0
        let per = paginationParameters.per
        let page = paginationParameters.page
        let offset = (page - 1) * per

        // Step 2: Get paginated AppInfo IDs with counts
        let queryResults =
            try await db
            .select()
            .column(SQLColumn("id", table: AppInfo.schema), as: "appInfoId")
            .column(
                SQLFunction("COUNT", args: SQLColumn("id", table: RequestRecord.schema)),
                as: "count"
            )
            .from(RequestRecord.schema)
            .join(
                AppInfo.schema,
                on: SQLColumn("app_info_id", table: RequestRecord.schema),
                .equal,
                SQLColumn("id", table: AppInfo.schema)
            )
            .join(
                IconPackVersion.schema,
                on: SQLColumn("icon_pack_version_id", table: RequestRecord.schema),
                .equal,
                SQLColumn("id", table: IconPackVersion.schema)
            )
            .join(
                IconPack.schema,
                on: SQLColumn("icon_pack_id", table: IconPackVersion.schema),
                .equal,
                SQLColumn("id", table: IconPack.schema)
            )
            .where(SQLColumn("designer_id", table: IconPack.schema), .equal, SQLBind(designerID))
            .groupBy(SQLColumn("id", table: AppInfo.schema))
            .orderBy(
                SQLOrderBy(
                    expression: SQLFunction(
                        "COUNT", args: SQLColumn("id", table: RequestRecord.schema)),
                    direction: SQLDirection.descending
                )
            )
            .limit(per)
            .offset(offset)
            .all()

        // Extract AppInfo IDs and count mappings
        var appInfoIds: [UUID] = []
        var countMap: [UUID: Int] = [:]

        for row in queryResults {
            if let id = try? row.decode(column: "appInfoId", as: UUID.self),
                let count = try? row.decode(column: "count", as: Int.self)
            {
                appInfoIds.append(id)
                countMap[id] = count
            }
        }

        // Step 3: Fetch AppInfo objects using Fluent
        let appInfos = try await AppInfo.query(on: req.db)
            .filter(\.$id ~~ appInfoIds)
            .all()

        // Maintain the order from the SQL query
        let orderedResults = appInfoIds.compactMap { id -> AppInfoWithRequestCount? in
            guard let appInfo = appInfos.first(where: { $0.id == id }),
                let count = countMap[id]
            else { return nil }
            return AppInfoWithRequestCount(appInfo: appInfo.toDTO(), count: count)
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
}
