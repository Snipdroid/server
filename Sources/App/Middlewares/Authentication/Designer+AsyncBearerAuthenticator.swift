import Vapor

struct DesignerAuthenticator: AsyncBearerAuthenticator {
    typealias User = Designer

    func authenticate(
        bearer: BearerAuthorization,
        for request: Request
    ) async throws {
        let designerToken = try await request.jwt.verify(as: Designer.Token.self)
        guard let designer = try await Designer.find(designerToken.id, on: request.db) else {
            throw Abort(.unauthorized)
        }
        request.auth.login(designer)
   }
}