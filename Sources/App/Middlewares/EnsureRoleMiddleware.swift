import Vapor

struct EnsureRoleMiddleware: AsyncMiddleware {
    init(_ roles: DesignerRole...) {
        self.roles = roles
    }

    private let roles: [DesignerRole]

    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        guard let designer = request.auth.get(Designer.self),
            roles.contains(designer.role)
        else {
            throw Abort(.unauthorized)
        }
        return try await next.respond(to: request)
    }
}
