import Fluent
import Vapor

struct DesignerController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let designer = routes.grouped("designer")

        designer.post("register", use: register)
        designer.grouped(Designer.authenticator(), DesignerAuthenticator()).get("login", use: login)
    }

    @Sendable
    func register(req: Request) async throws -> Designer.DTO {
        try Designer.Register.validate(content: req)
        let register = try req.content.decode(Designer.Register.self)

        let newDesigner = try Designer(register: register)
        try await newDesigner.save(on: req.db)

        guard let designer = try await Designer
            .query(on: req.db)
            .filter(\.$email == register.email)
            .first() else {
            throw InternalError.failedToAcquireEntity(Designer.self)
        }

        guard let designerId = try? designer.requireID() else {
            throw InternalError.failedToAcquireID(Designer.self)
        }

        let expireAt = Date().addingTimeInterval(60 * 60 * 48)
        let payload = Designer.Token(expiration: .init(value: expireAt), id: designerId)
        return try await designer.toDTO(token: req.jwt.sign(payload))
    }

    @Sendable
    func login(req: Request) async throws -> Designer.DTO {
        let designer = try req.auth.require(Designer.self)
        guard let designerId = try? designer.requireID() else {
            throw InternalError.failedToAcquireID(Designer.self)
        }

        let expireAt = Date().addingTimeInterval(60 * 60 * 48)
        let payload = Designer.Token(expiration: .init(value: expireAt), id: designerId)
        return try await designer.toDTO(token: req.jwt.sign(payload))
    }
}
