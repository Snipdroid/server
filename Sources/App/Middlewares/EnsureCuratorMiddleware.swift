import Vapor

struct EnsureCuratorMiddleware: AsyncMiddleware {
    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        guard let designer = request.auth.get(Designer.self),
            [.admin, .curator].contains(designer.role)
        else {
            throw Abort(.unauthorized)
        }
        return try await next.respond(to: request)
    }
}
