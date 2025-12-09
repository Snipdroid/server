import Fluent
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
}
