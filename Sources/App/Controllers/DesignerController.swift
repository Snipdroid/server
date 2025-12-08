import Fluent
import Vapor
import VaporToOpenAPI

struct DesignerController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let designer = routes.grouped("designer")

        designer
            .grouped(OIDCAuthenticator())
            .get("me", use: me)
            .openAPI(
                summary: "Get Current Designer",
                description: "Get the currently authenticated designer's profile",
                response: .type(Designer.DTO.self)
            )
    }

    @Sendable
    func me(req: Request) async throws -> Designer.DTO {
        let designer = try req.auth.require(Designer.self)
        return designer.toDTO()
    }
}
