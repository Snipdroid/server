import Fluent
import Vapor

struct IconPackVersionController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let designer = routes.grouped("icon-pack-version")

        designer.grouped(Designer.authenticator(), DesignerAuthenticator()).post("create", use: create)
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
}
