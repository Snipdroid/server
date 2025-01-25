import Fluent
import Vapor

struct AppVersionController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let designer = routes.grouped("app-version")

        designer.grouped(Designer.authenticator(), DesignerAuthenticator()).post("create", use: create)
    }

    @Sendable
    func create(req: Request) async throws -> AppVersion.DTO {
        let designer = try req.auth.require(Designer.self)

        guard let designerId = try? designer.requireID() else {
            throw InternalError.failedToAcquireID(Designer.self)
        }

        let create = try req.content.decode(AppVersion.Create.self)

        let newAppVersion = AppVersion(designerId: designerId, versionString: create.versionString)
        try await newAppVersion.save(on: req.db)

        guard let appVersion = try await AppVersion
            .query(on: req.db)
            .filter(\.$designer.$id == designerId)
            .filter(\.$versionString == create.versionString)
            .first() else {
            throw InternalError.failedToAcquireEntity(AppVersion.self)
        }

        guard let appVersionId = try? appVersion.requireID() else {
            throw InternalError.failedToAcquireID(AppVersion.self)
        }
        
        let payload = AppVersion.Token(expiration: .init(value: create.expireAt), id: appVersionId)
        return try await appVersion.toDTO(token: req.jwt.sign(payload))
    }
}
