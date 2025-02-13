import Vapor

struct IconPackVersionAuthenticator: AsyncBearerAuthenticator {
    typealias User = IconPackVersion

    func authenticate(
        bearer: BearerAuthorization,
        for request: Request
    ) async throws {
        let iconPackVersionToken = try await request.jwt.verify(as: IconPackVersion.Token.self)
        guard let iconPackVersion = try await IconPackVersion.find(iconPackVersionToken.id, on: request.db) else {
            throw Abort(.unauthorized)
        }
        request.auth.login(iconPackVersion)
   }
}

extension IconPackVersion: Authenticatable {}