import Fluent
import Vapor
import VaporToOpenAPI

struct IconPackVersionController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let versions =
            routes
            .grouped("icon-pack")
            .grouped(OIDCAuthenticator())

        versions
            .post(":iconPackId", "version", "create", use: create)
            .openAPI(
                summary: "Create icon pack version",
                description: "Create a new icon pack version",
                body: .type(IconPackVersion.Create.self),
                response: .type(IconPackVersionDTO.self)
            )

        versions
            .get(":iconPackId", "versions", use: listVersions)
            .openAPI(
                summary: "List icon pack versions",
                description: """
                    List all versions for an icon pack,
                    sorted by creation date in descending order
                    """,
                query: .type(PageRequest.self),
                response: .type(Page<IconPackVersionDTO>.self)
            )

        versions
            .get(":iconPackId", "version", ":versionId", "requests", use: requests)
            .openAPI(
                summary: "Get requests",
                description: "Get requests for an icon pack version",
                query: .type(PageRequest.self),
                response: .type(Page<RequestRecordDTO>.self)
            )

        versions
            .post(":iconPackId", "version", ":versionId", "token", use: createToken)
            .openAPI(
                summary: "Create access token",
                description: "Generate an access token for an icon pack version",
                body: .type(IconPackVersion.TokenRequest.self),
                response: .type(IconPackVersion.TokenResponse.self)
            )

        versions
            .delete(":iconPackId", "version", ":versionId", use: deleteVersion)
            .openAPI(
                summary: "Delete icon pack version",
                description: "Delete an icon pack version, returns the deleted version",
                response: .type(IconPackVersionDTO.self)
            )
    }

    @Sendable
    func create(req: Request) async throws -> IconPackVersionDTO {
        let designer = try req.auth.require(Designer.self)
        let designerId = try designer.requireID()

        let iconPackId = try req.parameters.require("iconPackId", as: UUID.self)

        // Verify the icon pack exists and belongs to the designer
        guard
            let iconPack = try await IconPack.query(on: req.db)
                .filter(\.$id == iconPackId)
                .first()
        else {
            throw Abort(.notFound)
        }

        guard iconPack.$designer.id == designerId else {
            throw Abort(.forbidden)
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

        // Verify the icon pack exists and belongs to the designer
        guard
            let iconPack = try await IconPack.query(on: req.db)
                .filter(\.$id == iconPackId)
                .first()
        else {
            throw Abort(.notFound)
        }

        guard iconPack.$designer.id == designerId else {
            throw Abort(.forbidden)
        }

        let versions = try await IconPackVersion.query(on: req.db)
            .filter(\.$iconPack.$id == iconPackId)
            .paginate(for: req)

        return versions.map { $0.toDTO() }
    }

    @Sendable
    func requests(req: Request) async throws -> Page<RequestRecordDTO> {
        let designer = try req.auth.require(Designer.self)
        let designerId = try designer.requireID()

        let iconPackId = try req.parameters.require("iconPackId", as: UUID.self)
        let versionId = try req.parameters.require("versionId", as: UUID.self)

        // Verify the icon pack exists and belongs to the designer
        guard
            let iconPack = try await IconPack.query(on: req.db)
                .filter(\.$id == iconPackId)
                .first()
        else {
            throw Abort(.notFound)
        }

        guard iconPack.$designer.id == designerId else {
            throw Abort(.forbidden)
        }

        // Verify the version exists and belongs to this icon pack
        guard
            let version = try await IconPackVersion.query(on: req.db)
                .filter(\.$id == versionId)
                .first()
        else {
            throw Abort(.notFound)
        }

        guard version.$iconPack.id == iconPackId else {
            throw Abort(.forbidden)
        }

        return try await RequestRecord.query(on: req.db)
            .filter(\.$iconPackVersion.$id, .equal, versionId)
            .with(\.$appInfo)
            .paginate(for: req)
            .map { $0.toDTO() }
    }

    @Sendable
    func createToken(req: Request) async throws -> IconPackVersion.TokenResponse {
        let designer = try req.auth.require(Designer.self)
        let designerId = try designer.requireID()

        let iconPackId = try req.parameters.require("iconPackId", as: UUID.self)
        let versionId = try req.parameters.require("versionId", as: UUID.self)

        // Verify the icon pack exists and belongs to the designer
        guard
            let iconPack = try await IconPack.query(on: req.db)
                .filter(\.$id == iconPackId)
                .first()
        else {
            throw Abort(.notFound)
        }

        guard iconPack.$designer.id == designerId else {
            throw Abort(.forbidden)
        }

        // Verify the version exists and belongs to this icon pack
        guard
            let version = try await IconPackVersion.query(on: req.db)
                .filter(\.$id == versionId)
                .first()
        else {
            throw Abort(.notFound)
        }

        guard version.$iconPack.id == iconPackId else {
            throw Abort(.forbidden)
        }

        let tokenRequest = try req.content.decode(IconPackVersion.TokenRequest.self)
        let payload = IconPackVersion.Token(
            expiration: .init(value: tokenRequest.expireAt),
            id: versionId
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

        // Verify the icon pack exists and belongs to the designer
        guard
            let iconPack = try await IconPack.query(on: req.db)
                .filter(\.$id == iconPackId)
                .first()
        else {
            throw Abort(.notFound)
        }

        guard iconPack.$designer.id == designerId else {
            throw Abort(.forbidden)
        }

        // Verify the version exists and belongs to this icon pack
        guard
            let version = try await IconPackVersion.query(on: req.db)
                .filter(\.$id == versionId)
                .first()
        else {
            throw Abort(.notFound)
        }

        guard version.$iconPack.id == iconPackId else {
            throw Abort(.forbidden)
        }

        try await version.delete(on: req.db)

        return version.toDTO()
    }
}
