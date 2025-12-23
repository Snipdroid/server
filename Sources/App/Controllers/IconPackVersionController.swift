import Fluent
import Vapor
import VaporToOpenAPI

struct IconPackVersionController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let iconPack =
            routes
            .grouped("icon-pack", ":iconPackId")
            .grouped(OIDCAuthenticator())

        let version =
            routes
            .grouped("icon-pack", ":iconPackId", "version", ":versionId")
            .grouped(OIDCAuthenticator())

        iconPack
            .post("version", "create", use: createVersion)
            .openAPI(
                summary: "Create icon pack version",
                description: "Create a new icon pack version",
                body: .type(IconPackVersion.Create.self),
                response: .type(IconPackVersionDTO.self)
            )

        iconPack
            .get("versions", use: listVersions)
            .openAPI(
                summary: "List icon pack versions",
                description: """
                    List all versions for an icon pack,
                    sorted by creation date in descending order
                    """,
                query: .type(PageRequest.self),
                response: .type(Page<IconPackVersionDTO>.self)
            )

        version
            .get("requests", use: requestsOfVersion)
            .openAPI(
                summary: "Get requests of version",
                description: "Get requests for an icon pack version",
                query: .all(of: .type(PageRequest.self), ["includingAdapted": .boolean]),
                response: .type(Page<IconPackVersionRequestRecordResponse>.self)
            )

        version
            .post("token", use: createToken)
            .openAPI(
                summary: "Create access token",
                description: "Generate an access token for an icon pack version",
                body: .type(IconPackVersion.TokenRequest.self),
                response: .type(IconPackVersion.TokenResponse.self)
            )

        version
            .delete(use: deleteVersion)
            .openAPI(
                summary: "Delete icon pack version",
                description: "Delete an icon pack version, returns the deleted version",
                response: .type(IconPackVersionDTO.self)
            )
    }

    @Sendable
    func createVersion(req: Request) async throws -> IconPackVersionDTO {
        let designer = try req.auth.require(Designer.self)
        let designerId = try designer.requireID()

        let iconPackId = try req.parameters.require("iconPackId", as: UUID.self)

        // Verify the icon pack exists and belongs to the designer
        guard
            try await IconPack.query(on: req.db)
                .join(Designer.self, on: \IconPack.$designer.$id == \Designer.$id)
                .filter(\IconPack.$id == iconPackId)
                .filter(Designer.self, \.$id == designerId)
                .first() != nil
        else {
            throw Abort(.notFound)
        }

        let create = try req.content.decode(IconPackVersion.Create.self)

        // Ensure the version does not already exist for this icon pack
        guard
            try await IconPackVersion.query(on: req.db)
                .filter(\.$iconPack.$id == iconPackId)
                .filter(\.$versionString == create.versionString)
                .first() == nil
        else {
            throw InternalError.violationOfUniqueConstraint(IconPackVersion.self)
        }

        // Create the version
        let newVersion = IconPackVersion(
            iconPackId: iconPackId, versionString: create.versionString)
        try await newVersion.save(on: req.db)

        return newVersion.toDTO()
    }

    @Sendable
    func listVersions(req: Request) async throws -> Page<IconPackVersionDTO> {
        let designer = try req.auth.require(Designer.self)
        let designerId = try designer.requireID()

        let iconPackId = try req.parameters.require("iconPackId", as: UUID.self)

        // Verify ownership and fetch versions in a single query
        let versions = try await IconPackVersion.query(on: req.db)
            .join(IconPack.self, on: \IconPackVersion.$iconPack.$id == \IconPack.$id)
            .join(IconPackCollaborators.self, on: \IconPack.$id == \IconPackCollaborators.$iconPack.$id, method: .left)
            .join(Designer.self, on: \IconPackCollaborators.$collaborator.$id == \Designer.$id, method: .left)
            .filter(\IconPackVersion.$iconPack.$id == iconPackId)
            .group(
                .or,
                { group in
                    group
                        .filter(IconPack.self, \.$designer.$id == designerId)
                        .filter(Designer.self, \.$id == designerId)
                }
            )
            .paginate(for: req)

        return versions.map { $0.toDTO() }
    }

    @Sendable
    func requestsOfVersion(req: Request) async throws -> Page<IconPackVersionRequestRecordResponse>
    {
        let designer = try req.auth.require(Designer.self)
        let designerId = try designer.requireID()

        let iconPackId = try req.parameters.require("iconPackId", as: UUID.self)
        let versionId = try req.parameters.require("versionId", as: UUID.self)
        let includingAdapted = try req.query.get(Bool.self, at: "includingAdapted")

        guard
            let version = try await IconPackVersion.query(on: req.db)
                .join(IconPack.self, on: \IconPackVersion.$iconPack.$id == \IconPack.$id)
                .join(Designer.self, on: \IconPack.$designer.$id == \Designer.$id)
                .filter(\IconPackVersion.$id == versionId)
                .filter(IconPack.self, \.$id == iconPackId)
                .filter(Designer.self, \.$id == designerId)
                .first()
        else {
            throw Abort(.notFound)
        }

        var query = version.$requestRecords.query(on: req.db)
            .with(\.$appInfo)
            .join(
                IconPackApp.self,
                on: \RequestRecord.$appInfo.$id == \IconPackApp.$appInfo.$id
                    && \IconPackApp.$iconPack.$id == iconPackId, method: .left
            )

        if !includingAdapted {
            query = query.filter(IconPackApp.self, \.$id == .null)
        }

        return
            try await query
            .paginate(for: req)
            .map { requestRecord in
                let iconPackApp = try? requestRecord.joined(IconPackApp.self)
                return IconPackVersionRequestRecordResponse(
                    requestRecord: requestRecord.toDTO(), iconPackApp: iconPackApp?.toDTO()
                )
            }
    }

    @Sendable
    func createToken(req: Request) async throws -> IconPackVersion.TokenResponse {
        let designer = try req.auth.require(Designer.self)
        let designerId = try designer.requireID()

        let iconPackId = try req.parameters.require("iconPackId", as: UUID.self)
        let versionId = try req.parameters.require("versionId", as: UUID.self)

        guard
            let version = try await IconPackVersion.query(on: req.db)
                .join(IconPack.self, on: \IconPackVersion.$iconPack.$id == \IconPack.$id)
                .join(Designer.self, on: \IconPack.$designer.$id == \Designer.$id)
                .filter(\IconPackVersion.$id == versionId)
                .filter(IconPack.self, \.$id == iconPackId)
                .filter(Designer.self, \.$id == designerId)
                .first()
        else {
            throw Abort(.notFound)
        }

        let tokenRequest = try req.content.decode(IconPackVersion.TokenRequest.self)
        let payload = try IconPackVersion.Token(
            expiration: .init(value: tokenRequest.expireAt),
            id: version.requireID()
        )
        let token = try await req.jwt.sign(payload)

        return .init(token: token)
    }

    @Sendable
    func deleteVersion(req: Request) async throws -> IconPackVersionDTO {
        let designer = try req.auth.require(Designer.self)
        let designerId = try designer.requireID()

        let iconPackId = try req.parameters.require("iconPackId", as: UUID.self)
        let versionId = try req.parameters.require("versionId", as: UUID.self)

        guard
            let version = try await IconPackVersion.query(on: req.db)
                .join(IconPack.self, on: \IconPackVersion.$iconPack.$id == \IconPack.$id)
                .join(Designer.self, on: \IconPack.$designer.$id == \Designer.$id)
                .filter(\IconPackVersion.$id == versionId)
                .filter(IconPack.self, \.$id == iconPackId)
                .filter(Designer.self, \.$id == designerId)
                .first()
        else {
            throw Abort(.notFound)
        }

        try await version.delete(on: req.db)

        return version.toDTO()
    }
}
