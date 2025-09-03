import Fluent
import Vapor
import VaporToOpenAPI

struct IconPackVersionController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let designer = routes.grouped("icon-pack-version")

        designer
            .grouped(Designer.authenticator(), DesignerAuthenticator())
            .post("create", use: create)
            .openAPI(
                summary: "Create icon pack version",
                description: "Create a new icon pack version",
                body: .type(IconPackVersion.Create.self),
                response: .type(IconPackVersion.DTO.self)
            )
        designer
            .grouped(Designer.authenticator(), DesignerAuthenticator())
            .get(":iconPackVersionId", "requests", use: requests)
            .openAPI(
                summary: "Get requests",
                description: "Get requests for an icon pack version",
                response: .type(Page<RequestRecord>.self)
            )
    }

    @Sendable
    func create(req: Request) async throws -> IconPackVersion.DTO {
        let designer = try req.auth.require(Designer.self)

        guard let designerId = try? designer.requireID() else {
            throw InternalError.failedToAcquireID(Designer.self)
        }

        let create = try req.content.decode(IconPackVersion.Create.self)

        // 1. Ensure the app version does not already exist
        guard try await IconPackVersion.query(on: req.db)
            .filter(\.$designer.$id == designerId)
            .filter(\.$versionString == create.versionString)
            .first() == nil else {
                throw InternalError.violationOfUniqueConstraint(IconPackVersion.self)
            }

        // 2. Create the app version
        let newIconPackVersion = IconPackVersion(designerId: designerId, versionString: create.versionString)
        try await newIconPackVersion.save(on: req.db)

        // 3. Retrieve the app version and generate a token
        guard let iconPackVersion = try await IconPackVersion
            .query(on: req.db)
            .filter(\.$designer.$id == designerId)
            .filter(\.$versionString == create.versionString)
            .first() else {
            throw InternalError.failedToAcquireEntity(IconPackVersion.self)
        }

        guard let iconPackVersionID = try? iconPackVersion.requireID() else {
            throw InternalError.failedToAcquireID(IconPackVersion.self)
        }
        
        let payload = IconPackVersion.Token(expiration: .init(value: create.expireAt), id: iconPackVersionID)
        return try await iconPackVersion.toDTO(token: req.jwt.sign(payload))
    }


    // GET /icon-pack-version/:iconPackVersionId/requests
    @Sendable
    func requests(req: Request) async throws -> Page<RequestRecord> {
        let designer = try req.auth.require(Designer.self)
        let designerId = try designer.requireID()
        
        let iconPackVersionId = try req.parameters.require("iconPackVersionId", as: UUID.self)

        guard let iconPackVersion = try await IconPackVersion.query(on: req.db)
            .filter(\.$id == iconPackVersionId)
            .first() else {
            throw Abort(.notFound)
        }

        guard iconPackVersion.$designer.id == designerId else {
            throw Abort(.forbidden)
        }

        return try await RequestRecord.query(on: req.db)
            .filter(\.$iconPackVersion.$id, .equal, iconPackVersionId)
            .with(\.$appInfo)
            .paginate(for: req)
    }

}
