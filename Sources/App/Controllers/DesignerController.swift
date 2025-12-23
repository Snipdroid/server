import Fluent
import SQLKit
import SQLKitExtras
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
            .get("statistics", use: getStatistics)
            .openAPI(
                summary: "Get Designer Statistics",
                description: "Get statistics for the currently authenticated designer",
                response: .type(DesignerStatisticsResponse.self)
            )

        protected
            .get("search", use: searchDesigner)
            .openAPI(
                summary: "Search Designers",
                description: "Search for designers by email",
                query: ["query": .string],
                response: .type(Page<DesignerDTO>.self)
            )

    }

    @Sendable
    func me(req: Request) async throws -> DesignerDTO {
        let designer = try req.auth.require(Designer.self)

        // Cache-revalidate: sync if data is older than 5 minutes
        let needsSync =
            designer.updatedAt.map {
                Date().timeIntervalSince($0) > 300
            } ?? true

        return if needsSync {
            try await syncWithOIDCProvider(req: req, designer: designer).toDTO()
        } else {
            designer.toDTO()
        }
    }

    @Sendable
    func sync(req: Request) async throws -> DesignerDTO {
        let designer = try req.auth.require(Designer.self)
        let updated = try await syncWithOIDCProvider(req: req, designer: designer)
        return updated.toDTO()
    }

    private func syncWithOIDCProvider(req: Request, designer: Designer) async throws -> Designer {
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

        return designer
    }

    @Sendable
    func getStatistics(req: Request) async throws -> DesignerStatisticsResponse {
        let designer = try req.auth.require(Designer.self)
        let designerID = try designer.requireID()

        return try await req.db.transaction { transactionalDatabase in
            guard let db = transactionalDatabase as? any SQLDatabase else {
                throw Abort(.internalServerError, reason: "Database does not support SQL")
            }

            let requestCount =
                try await db.select()
                .column(
                    SQLFunction("COUNT", args: RequestRecord.sqlColumn(for: \.$id)),
                    as: "count"
                )
                .from(RequestRecord.schema)
                .join(
                    IconPackVersion.schema,
                    on: RequestRecord.sqlColumn(for: \.$iconPackVersion.$id),
                    .equal,
                    IconPackVersion.sqlColumn(for: \.$id)
                )
                .join(
                    IconPack.schema,
                    on: IconPackVersion.sqlColumn(for: \.$iconPack.$id),
                    .equal,
                    IconPack.sqlColumn(for: \.$id)
                )
                .where(
                    IconPack.sqlColumn(for: \.$designer.$id), .equal, SQLBind(designerID)
                )
                .first(decodingColumn: "count", as: Int.self) ?? -1

            let distinctRequestCount =
                try await db.select()
                .column(
                    SQLFunction("COUNT", args: SQLLiteral.all),
                    as: "count"
                )
                .from(
                    SQLGroupExpression(
                        db.select()
                            .column(RequestRecord.sqlColumn(for: \.$appInfo.$id))
                            .column(IconPack.sqlColumn(for: \.$id))
                            .from(RequestRecord.schema)
                            .join(
                                IconPackVersion.schema,
                                on: RequestRecord.sqlColumn(for: \.$iconPackVersion.$id),
                                .equal,
                                IconPackVersion.sqlColumn(for: \.$id)
                            )
                            .join(
                                IconPack.schema,
                                on: IconPackVersion.sqlColumn(for: \.$iconPack.$id),
                                .equal,
                                IconPack.sqlColumn(for: \.$id)
                            )
                            .where(
                                IconPack.sqlColumn(for: \.$designer.$id), .equal,
                                SQLBind(designerID)
                            )
                            .groupBy(RequestRecord.sqlColumn(for: \.$appInfo.$id))
                            .groupBy(IconPack.sqlColumn(for: \.$id))
                            .query
                    )

                )
                .first(decodingColumn: "count", as: Int.self) ?? -1

            return DesignerStatisticsResponse(
                requestCount: requestCount, distinctRequestCount: distinctRequestCount)
        }
    }

    @Sendable
    func searchDesigner(req: Request) async throws -> Page<DesignerDTO> {
        let email = try req.query.get(String.self, at: "query")
        return try await Designer.query(on: req.db)
            .filter(\.$email ~~ email)
            .paginate(for: req)
            .map { $0.toDTO() }
    }
}
